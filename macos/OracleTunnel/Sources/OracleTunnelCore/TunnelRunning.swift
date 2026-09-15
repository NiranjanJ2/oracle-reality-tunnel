import Foundation

public protocol TunnelRunning: Sendable {
    func status() async throws -> TailnetSnapshot
    func ping() async -> HealthState
    func connect() async throws
    func disconnect() async throws
    func setTunnel(enabled: Bool) async throws
    func setRoute(_ route: TunnelRoute) async throws
}

public extension TunnelRunning {
    func setRoute(_ route: TunnelRoute) async throws { try await setTunnel(enabled: route != .off) }
}
