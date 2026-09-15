import Testing
@testable import OracleTunnelCore

@MainActor
@Suite("Tunnel model sequencing")
struct TunnelModelTests {
    @Test func startupPreservesDisconnectedState() async {
        let client = FakeTunnelRunner(statuses: [snapshot(.disconnected)])
        let model = TunnelModel(client: client)

        await model.start()
        model.stop()

        #expect(await client.operations == [.status])
        #expect(model.controlState == .disconnected)
    }

    @Test func startupPreservesRunningTunnel() async {
        let client = FakeTunnelRunner(statuses: [snapshot(.tunneled)])
        let model = TunnelModel(client: client)

        await model.start()
        model.stop()

        #expect(await client.operations == [.status, .ping])
        #expect(model.isTunnelOn)
    }

    @Test func tunnelOnReconnectsWhenStopped() async {
        let client = FakeTunnelRunner(statuses: [snapshot(.disconnected), snapshot(.tunneled)])
        let model = TunnelModel(client: client)
        await model.refresh()
        await client.resetOperations()

        await model.setTunnel(true)

        #expect(await client.operations == [
            .connect, .setTunnel(true), .status, .ping,
        ])
        #expect(model.controlState == .tunneled)
    }

    @Test func tunnelOffRetainsPrivateConnectivity() async {
        let client = FakeTunnelRunner(statuses: [snapshot(.tunneled), snapshot(.privateOnly)])
        let model = TunnelModel(client: client)
        await model.refresh()
        await client.resetOperations()

        await model.setTunnel(false)

        #expect(await client.operations == [.setTunnel(false), .status, .ping])
        #expect(model.controlState == .privateOnly)
    }

    @Test func fullDisconnectAndReconnectAreDistinct() async {
        let client = FakeTunnelRunner(statuses: [
            snapshot(.privateOnly), snapshot(.disconnected), snapshot(.privateOnly),
        ])
        let model = TunnelModel(client: client)
        await model.refresh()
        await client.resetOperations()

        await model.disconnect()
        #expect(await client.operations == [.disconnect, .status])
        #expect(model.healthState == .disconnected)

        await client.resetOperations()
        await model.reconnect()
        #expect(await client.operations == [.connect, .setTunnel(false), .status, .ping])
        #expect(model.controlState == .privateOnly)
    }

    @Test func failureKeepsLastVerifiedStateAndAllowsRetry() async {
        let client = FakeTunnelRunner(
            statuses: [snapshot(.privateOnly)],
            failTunnelChanges: true
        )
        let model = TunnelModel(client: client)
        await model.refresh()

        await model.setTunnel(true)

        #expect(model.controlState == .privateOnly)
        #expect(model.errorMessage == "denied")
        #expect(model.isBusy == false)
    }

    @Test func overlappingUserActionIsIgnored() async {
        let client = FakeTunnelRunner(
            statuses: [snapshot(.privateOnly), snapshot(.tunneled)],
            delayTunnelChanges: true
        )
        let model = TunnelModel(client: client)
        await model.refresh()
        await client.resetOperations()

        async let first: Void = model.setTunnel(true)
        while !model.isBusy { await Task.yield() }
        await model.disconnect()
        await first

        #expect(await client.operations == [.setTunnel(true), .status, .ping])
    }
}

private enum FakeOperation: Equatable, Sendable {
    case status
    case ping
    case connect
    case disconnect
    case setTunnel(Bool)
}

private actor FakeTunnelRunner: TunnelRunning {
    private var statuses: [TailnetSnapshot]
    private let pingResult: HealthState
    private let failTunnelChanges: Bool
    private let delayTunnelChanges: Bool
    private(set) var operations: [FakeOperation] = []

    init(
        statuses: [TailnetSnapshot],
        pingResult: HealthState = .healthy(latencyMS: 24, path: "direct"),
        failTunnelChanges: Bool = false,
        delayTunnelChanges: Bool = false
    ) {
        self.statuses = statuses
        self.pingResult = pingResult
        self.failTunnelChanges = failTunnelChanges
        self.delayTunnelChanges = delayTunnelChanges
    }

    func status() throws -> TailnetSnapshot {
        operations.append(.status)
        return statuses.removeFirst()
    }

    func ping() -> HealthState {
        operations.append(.ping)
        return pingResult
    }

    func connect() {
        operations.append(.connect)
    }

    func disconnect() {
        operations.append(.disconnect)
    }

    func setTunnel(enabled: Bool) async throws {
        operations.append(.setTunnel(enabled))
        if delayTunnelChanges {
            try await Task.sleep(for: .milliseconds(50))
        }
        if failTunnelChanges {
            throw TunnelError.commandFailed(message: "denied")
        }
    }

    func resetOperations() {
        operations = []
    }
}

private func snapshot(_ state: ControlState) -> TailnetSnapshot {
    let connected = state != .disconnected
    return TailnetSnapshot(
        backendState: connected ? "Running" : "Stopped",
        tailnetName: connected ? "example.invalid" : nil,
        selfOnline: connected,
        healthMessages: [],
        targetPeer: connected ? PeerSnapshot(
            hostName: "oracle-vps",
            tailscaleIP: nil,
            online: true,
            selectedAsExitNode: state == .tunneled,
            offersExitNode: true,
            active: state == .tunneled,
            relay: "lax",
            currentAddress: nil
        ) : nil,
        controlState: state
    )
}
