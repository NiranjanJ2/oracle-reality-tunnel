import Combine
import Foundation

@MainActor
public final class TunnelModel: ObservableObject {
    @Published public private(set) var controlState: ControlState = .unavailable
    @Published public private(set) var healthState: HealthState = .checking
    @Published public private(set) var isBusy = false
    @Published public private(set) var statusMessage = "Starting…"
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var connectedSince: Date?

    public var isTunnelOn: Bool { controlState == .tunneled || controlState == .oracle }
    public var route: TunnelRoute { controlState.route }
    public var isConnected: Bool {
        controlState == .privateOnly || controlState == .tunneled || controlState == .oracle
    }
    public var connectionDuration: String? {
        guard let connectedSince, isTunnelOn else { return nil }
        let seconds = max(0, Int(Date().timeIntervalSince(connectedSince)))
        if seconds < 60 { return "\(seconds)s" }
        if seconds < 3600 { return "\(seconds / 60)m" }
        return "\(seconds / 3600)h \((seconds % 3600) / 60)m"
    }

    private let client: any TunnelRunning
    private var pollingTask: Task<Void, Never>?

    public init(client: any TunnelRunning) {
        self.client = client
    }

    public func start() async {
        guard !isBusy else { return }
        isBusy = true
        errorMessage = nil

        do {
            try await loadStatus()
            if isTunnelOn { await loadHealth() }
        } catch {
            errorMessage = displayMessage(for: error)
        }

        isBusy = false
        beginPolling()
    }

    public func stop() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    public func refresh() async {
        guard !isBusy else { return }
        do {
            try await loadStatus()
            errorMessage = nil
        } catch {
            errorMessage = displayMessage(for: error)
        }
    }

    public func probe() async {
        guard !isBusy else { return }
        await loadHealth()
    }

    public func setTunnel(_ enabled: Bool) async {
        guard enabled != isTunnelOn else { return }
        await performAction {
            self.statusMessage = enabled ? "Starting…" : "Stopping…"
            if self.controlState == .disconnected {
                try await self.client.connect()
            }
            try await self.client.setTunnel(enabled: enabled)
            try await self.loadStatus()
            await self.loadHealth()
        }
    }

    public func setRoute(_ route: TunnelRoute) async {
        guard route != self.route else { return }
        await performAction {
            self.statusMessage = route == .off ? "Stopping…" : "Starting \(route.rawValue)…"
            try await self.client.setRoute(route)
            try await self.loadStatus()
            await self.loadHealth()
        }
    }

    public func disconnect() async {
        await performAction {
            try await self.client.disconnect()
            try await self.loadStatus()
            self.healthState = .disconnected
        }
    }

    public func reconnect() async {
        await performAction {
            try await self.client.connect()
            try await self.client.setTunnel(enabled: false)
            try await self.loadStatus()
            await self.loadHealth()
        }
    }

    private func performAction(_ action: () async throws -> Void) async {
        guard !isBusy else { return }
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        do {
            try await action()
        } catch {
            errorMessage = displayMessage(for: error)
        }
    }

    private func loadStatus() async throws {
        let snapshot = try await client.status()
        controlState = snapshot.controlState
        switch snapshot.controlState {
        case .disconnected:
            statusMessage = "Disconnected"
            healthState = .disconnected
        case .privateOnly:
            statusMessage = "Connected · Tunnel off"
        case .tunneled:
            statusMessage = "Tunnel through home"
            if connectedSince == nil { connectedSince = Date() }
        case .oracle:
            statusMessage = "Tunnel through Oracle"
            if connectedSince == nil { connectedSince = Date() }
        case .unavailable:
            statusMessage = snapshot.tailnetName.map { "Wrong tailnet · \($0)" } ?? "Unavailable"
        }
        if snapshot.controlState.route == .off { connectedSince = nil }
    }

    private func loadHealth() async {
        guard isConnected else {
            healthState = controlState == .disconnected ? .disconnected : .checking
            return
        }
        healthState = .checking
        healthState = await client.ping()
    }

    private func beginPolling() {
        pollingTask?.cancel()
        pollingTask = Task { [weak self] in
            var statusCycles = 0
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled, let self else { return }
                guard !self.isBusy else { continue }
                await self.refresh()
                statusCycles += 1
                if statusCycles.isMultiple(of: 2) {
                    await self.probe()
                }
            }
        }
    }

    private func displayMessage(for error: any Error) -> String {
        switch error as? TunnelError {
        case .commandFailed(let message): message
        case .executableMissing: "Tailscale CLI not found"
        case .timeout: "Command timed out"
        case nil: TunnelError.sanitizedMessage(for: error)
        }
    }
}
