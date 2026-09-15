import Combine
import Foundation
import ServiceManagement

@MainActor
final class LoginItemController: ObservableObject {
    @Published private(set) var isEnabled = false
    @Published private(set) var errorMessage: String?

    init() {
        refresh()
    }

    func ensureRegistered() {
        switch SMAppService.mainApp.status {
        case .notRegistered, .notFound:
            setEnabled(true)
        case .enabled, .requiresApproval:
            refresh()
        @unknown default:
            refresh()
        }
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            errorMessage = nil
        } catch {
            errorMessage = String(String(describing: error).prefix(160))
        }
        refresh()
    }

    func refresh() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    static func unregisterForUninstall() throws {
        guard SMAppService.mainApp.status != .notRegistered else { return }
        try SMAppService.mainApp.unregister()
    }

    static var statusText: String {
        switch SMAppService.mainApp.status {
        case .notRegistered: "notRegistered"
        case .enabled: "enabled"
        case .requiresApproval: "requiresApproval"
        case .notFound: "notFound"
        @unknown default: "unknown"
        }
    }
}
