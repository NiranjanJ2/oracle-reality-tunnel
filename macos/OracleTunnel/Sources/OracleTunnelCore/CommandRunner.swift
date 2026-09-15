import Foundation

public struct CommandResult: Sendable, Equatable {
    public let stdout: String
    public let stderr: String
    public let exitCode: Int32

    public init(stdout: String, stderr: String, exitCode: Int32) {
        self.stdout = stdout
        self.stderr = stderr
        self.exitCode = exitCode
    }
}

public protocol CommandExecuting: Sendable {
    func run(
        executable: String,
        arguments: [String],
        timeout: Duration
    ) async throws -> CommandResult
}

public actor ProcessCommandRunner: CommandExecuting {
    public init() {}

    public func run(
        executable: String,
        arguments: [String],
        timeout: Duration
    ) async throws -> CommandResult {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()

        return try await withTaskCancellationHandler {
            try await withThrowingTaskGroup(of: CommandResult.self) { group in
                group.addTask {
                    async let outputData = outputPipe.fileHandleForReading.readToEnd()
                    async let errorData = errorPipe.fileHandleForReading.readToEnd()
                    process.waitUntilExit()
                    return CommandResult(
                        stdout: String(decoding: try await outputData ?? Data(), as: UTF8.self),
                        stderr: String(decoding: try await errorData ?? Data(), as: UTF8.self),
                        exitCode: process.terminationStatus
                    )
                }
                group.addTask {
                    try await Task.sleep(for: timeout)
                    if process.isRunning { process.terminate() }
                    throw TunnelError.timeout
                }

                guard let result = try await group.next() else {
                    throw TunnelError.commandFailed(message: "Command produced no result")
                }
                group.cancelAll()
                return result
            }
        } onCancel: {
            if process.isRunning { process.terminate() }
        }
    }
}
