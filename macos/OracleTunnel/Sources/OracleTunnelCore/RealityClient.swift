import Foundation

public actor RealityClient: TunnelRunning {
    private let runner: any CommandExecuting

    public init(runner: any CommandExecuting = ProcessCommandRunner()) {
        self.runner = runner
    }

    public func status() async throws -> TailnetSnapshot {
        let result = try await runScript("status-client.sh", timeout: .seconds(5))
        let oracle = result.exitCode == 0 && result.stdout.contains("ORACLE")
        let enabled = result.exitCode == 0 && (oracle || result.stdout.contains("HOME"))
        return TailnetSnapshot(
            backendState: enabled ? "Running" : "Stopped",
            tailnetName: nil,
            selfOnline: enabled,
            healthMessages: [],
            targetPeer: nil,
            controlState: oracle ? .oracle : (enabled ? .tunneled : .disconnected)
        )
    }

    public func ping() async -> HealthState {
        let started = ContinuousClock.now
        var failure = "HTTPS probes failed"
        // IPv4 is the routed transport; IPv6 could bypass the tunnel on dual-stack Wi-Fi.
        for endpoint in ["https://www.cloudflare.com/cdn-cgi/trace", "https://www.google.com/generate_204"] {
            do {
                let result = try await runner.run(
                    executable: "/usr/bin/curl",
                    arguments: ["-4", "--connect-timeout", "3", "--max-time", "5", "-fsS", "-o", "/dev/null", endpoint],
                    timeout: .seconds(7)
                )
                guard result.exitCode == 0 else {
                    failure = TunnelError.sanitized(result.stderr)
                    continue
                }
                let elapsed = started.duration(to: .now).components
                let latency = Double(elapsed.seconds) * 1000 + Double(elapsed.attoseconds) / 1e15
                return .healthy(latencyMS: latency, path: "HTTPS")
            } catch {
                failure = TunnelError.sanitizedMessage(for: error)
            }
        }
        return .unreachable(failure)
    }

    public func connect() async throws {}

    public func disconnect() async throws {
        _ = try await runScript("stop-client.sh", timeout: .seconds(10))
    }

    public func setTunnel(enabled: Bool) async throws {
        let result = try await runScript(enabled ? "start-client.sh" : "stop-client.sh", timeout: .seconds(18))
        guard result.exitCode == 0 else {
            throw TunnelError.commandFailed(message: TunnelError.sanitized(result.stderr))
        }
    }

    public func setRoute(_ route: TunnelRoute) async throws {
        if route == .off { try await setTunnel(enabled: false); return }
        let result = try await runScript("start-client.sh", arguments: [route == .oracle ? "oracle" : "home"], timeout: .seconds(18))
        guard result.exitCode == 0 else { throw TunnelError.commandFailed(message: TunnelError.sanitized(result.stderr)) }
    }

    private func runScript(_ name: String, timeout: Duration) async throws -> CommandResult {
        try await runScript(name, arguments: [], timeout: timeout)
    }

    private func runScript(_ name: String, arguments: [String], timeout: Duration) async throws -> CommandResult {
        let base = name.replacingOccurrences(of: ".sh", with: "")
        guard let path = Bundle.main.path(forResource: base, ofType: "sh") else {
            throw TunnelError.executableMissing(name)
        }
        return try await runner.run(executable: path, arguments: arguments, timeout: timeout)
    }
}
