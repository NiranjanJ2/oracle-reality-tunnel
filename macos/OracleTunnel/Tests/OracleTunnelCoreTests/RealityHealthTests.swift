import Foundation
import Testing
@testable import OracleTunnelCore

@Suite("REALITY HTTPS health")
struct RealityHealthTests {
    @Test func endpointOutageDoesNotMarkWorkingTunnelUnreachable() async {
        let runner = HealthProbeRunner(results: [
            CommandResult(stdout: "", stderr: "curl: (22) HTTP 520", exitCode: 22),
            CommandResult(stdout: "", stderr: "", exitCode: 0)
        ])
        let health = await RealityClient(runner: runner).ping()
        guard case .healthy(_, let path) = health else {
            Issue.record("Working fallback must be healthy: \(health)"); return
        }
        #expect(path == "HTTPS")
        let calls = await runner.calls
        #expect(calls.count == 2)
        #expect(calls.allSatisfy { $0.contains("-4") })
        #expect(!calls.flatMap { $0 }.contains("https://api.ipify.org"))
    }

    @Test func allFailedProbesRemainUnreachable() async {
        let runner = HealthProbeRunner(results: [
            CommandResult(stdout: "", stderr: "curl: (6) DNS failed", exitCode: 6),
            CommandResult(stdout: "", stderr: "curl: (28) Timeout", exitCode: 28)
        ])
        let health = await RealityClient(runner: runner).ping()
        guard case .unreachable = health else { Issue.record("Failed HTTPS probes must not be healthy"); return }
    }
}

private actor HealthProbeRunner: CommandExecuting {
    var calls: [[String]] = []
    var results: [CommandResult]
    init(results: [CommandResult]) { self.results = results }
    func run(executable: String, arguments: [String], timeout: Duration) async throws -> CommandResult {
        calls.append(arguments)
        guard !results.isEmpty else { throw TunnelError.timeout }
        return results.removeFirst()
    }
}
