import AppKit
import OracleTunnelCore
import SwiftUI

@MainActor
final class OracleTunnelAppDelegate: NSObject, NSApplicationDelegate {
    let model = TunnelModel(client: RealityClient())
    let loginItems = LoginItemController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        loginItems.ensureRegistered()
        Task { await model.start() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.stop()
    }
}

@main
struct OracleTunnelApp: App {
    @NSApplicationDelegateAdaptor(OracleTunnelAppDelegate.self) private var delegate

    init() {
        if CommandLine.arguments.contains("--login-item-status") {
            print(LoginItemController.statusText)
            Foundation.exit(EXIT_SUCCESS)
        }
        if CommandLine.arguments.contains("--unregister-login-item") {
            do {
                try LoginItemController.unregisterForUninstall()
                print("Oracle Tunnel launch-at-login registration removed")
                Foundation.exit(EXIT_SUCCESS)
            } catch {
                fputs("Could not remove launch-at-login registration: \(error)\n", stderr)
                Foundation.exit(EXIT_FAILURE)
            }
        }

    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(model: delegate.model, loginItems: delegate.loginItems)
        } label: {
            MenuBarLabel(model: delegate.model)
        }
        .menuBarExtraStyle(.window)
    }
}
