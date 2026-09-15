import Foundation

public enum ControlState: Equatable, Sendable {
    case disconnected
    case privateOnly
    case tunneled
    case oracle
    case unavailable
}

public enum TunnelRoute: String, CaseIterable, Sendable {
    case off = "Off"
    case oracle = "Oracle"
    case home = "Home"
}

public enum HealthState: Equatable, Sendable {
    case checking
    case healthy(latencyMS: Double, path: String)
    case degraded(latencyMS: Double, path: String)
    case unreachable(String)
    case disconnected

    public var label: String {
        switch self {
        case .checking:
            "Checking connection…"
        case .healthy(let latency, let path):
            "Healthy · \(Int(latency.rounded())) ms · \(path)"
        case .degraded(let latency, let path):
            "Degraded · \(Int(latency.rounded())) ms · \(path)"
        case .unreachable(let reason):
            "Unreachable · \(reason)"
        case .disconnected:
            "Tunnel off"
        }
    }

    public var symbolName: String {
        switch self {
        case .healthy: "circle.fill"
        case .degraded: "exclamationmark.circle.fill"
        case .unreachable: "xmark.circle.fill"
        case .checking: "circle.dotted"
        case .disconnected: "circle"
        }
    }
}

public extension ControlState {
    var route: TunnelRoute {
        switch self {
        case .tunneled: .home
        case .oracle: .oracle
        default: .off
        }
    }

    var switchLabel: String {
        route == .off ? "Off" : "On"
    }

    func displayLabel(isBusy: Bool) -> String {
        guard isBusy else { return switchLabel }
        return route == .off ? "Starting…" : "Stopping…"
    }

    var menuBarSymbol: String {
        switch self {
        case .tunneled: "house.and.flag.fill"
        case .oracle: "cloud.fill"
        case .privateOnly: "house.fill"
        case .disconnected: "house.slash"
        case .unavailable: "exclamationmark.triangle"
        }
    }
}

public struct PeerSnapshot: Equatable, Sendable {
    public let hostName: String
    public let tailscaleIP: String?
    public let online: Bool
    public let selectedAsExitNode: Bool
    public let offersExitNode: Bool
    public let active: Bool
    public let relay: String?
    public let currentAddress: String?

    public init(
        hostName: String,
        tailscaleIP: String?,
        online: Bool,
        selectedAsExitNode: Bool,
        offersExitNode: Bool,
        active: Bool,
        relay: String?,
        currentAddress: String?
    ) {
        self.hostName = hostName
        self.tailscaleIP = tailscaleIP
        self.online = online
        self.selectedAsExitNode = selectedAsExitNode
        self.offersExitNode = offersExitNode
        self.active = active
        self.relay = relay
        self.currentAddress = currentAddress
    }
}

public struct TailnetSnapshot: Equatable, Sendable {
    public let backendState: String
    public let tailnetName: String?
    public let selfOnline: Bool
    public let healthMessages: [String]
    public let targetPeer: PeerSnapshot?
    public let controlState: ControlState

    public init(
        backendState: String,
        tailnetName: String?,
        selfOnline: Bool,
        healthMessages: [String],
        targetPeer: PeerSnapshot?,
        controlState: ControlState
    ) {
        self.backendState = backendState
        self.tailnetName = tailnetName
        self.selfOnline = selfOnline
        self.healthMessages = healthMessages
        self.targetPeer = targetPeer
        self.controlState = controlState
    }
}

public enum TunnelError: Error, Equatable, Sendable {
    case executableMissing(String)
    case commandFailed(message: String)
    case timeout

    public static func sanitized(_ text: String) -> String {
        let line = text.components(separatedBy: .newlines).first ?? "Command failed"
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        return String((trimmed.isEmpty ? "Command failed" : trimmed).prefix(160))
    }

    public static func sanitizedMessage(for error: any Error) -> String {
        sanitized(String(describing: error))
    }
}
