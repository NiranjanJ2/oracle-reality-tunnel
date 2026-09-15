import AppKit
import OracleTunnelCore
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var model: TunnelModel
    @ObservedObject var loginItems: LoginItemController
    @State private var diagnosticsOpen = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Circle().fill(healthColor).frame(width: 10, height: 10)
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.statusMessage).font(.headline)
                    Text(model.healthState.label).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if model.isBusy { ProgressView().controlSize(.small) }
            }

            Toggle("Route through Oracle", isOn: Binding(
                get: { model.isTunnelOn },
                set: { value in Task { await model.setRoute(value ? .oracle : .off) } }
            )).toggleStyle(.switch)
            .disabled(model.isBusy || model.controlState == .unavailable)

            if let error = model.errorMessage ?? loginItems.errorMessage {
                Text(error).font(.caption).foregroundStyle(.red).textSelection(.enabled)
            }

            DisclosureGroup("Diagnostics", isExpanded: $diagnosticsOpen) {
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 7) {
                    row("Routing", model.isTunnelOn ? "utun233" : "Direct")
                    row("DNS", model.isTunnelOn ? "DNS over TLS" : "Automatic")
                    row("Oracle", model.isTunnelOn ? "Pinned to Wi-Fi gateway" : "Idle")
                    row("Egress", model.isTunnelOn ? "Oracle · \(healthDetail)" : "Off")
                    if let duration = model.connectionDuration { row("Connected", duration) }
                }
                .font(.caption)
                .padding(.top, 8)
                Button("Copy Diagnostics") { copyDiagnostics() }
                    .buttonStyle(.link).padding(.top, 5)
            }

            Divider()
            Toggle("Launch at Login", isOn: Binding(
                get: { loginItems.isEnabled },
                set: { loginItems.setEnabled($0) }
            ))
            HStack {
                Button("Refresh") {
                    Task { await model.refresh(); await model.probe(); loginItems.refresh() }
                }.disabled(model.isBusy)
                Spacer()
                Button("Quit") { model.stop(); NSApplication.shared.terminate(nil) }
            }
        }
        .padding(16)
        .frame(width: 330)
    }

    @ViewBuilder private func row(_ name: String, _ value: String) -> some View {
        GridRow { Text(name).foregroundStyle(.secondary); Text(value).textSelection(.enabled) }
    }

    private var healthDetail: String {
        switch model.healthState {
        case .healthy(let ms, _): "Healthy · \(Int(ms.rounded())) ms"
        case .degraded(let ms, _): "Slow · \(Int(ms.rounded())) ms"
        case .unreachable: "Unreachable"
        case .checking: "Checking…"
        case .disconnected: "Off"
        }
    }

    private var healthColor: Color {
        switch model.healthState {
        case .healthy: .green
        case .degraded: .orange
        case .unreachable: .red
        case .checking: .yellow
        case .disconnected: .secondary
        }
    }

    private func copyDiagnostics() {
        let text = "Oracle Tunnel\nState: \(model.statusMessage)\nHealth: \(model.healthState.label)\nRouting: \(model.isTunnelOn ? "utun233" : "Direct")\nDNS: \(model.isTunnelOn ? "DNS over TLS" : "Automatic")"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

struct MenuBarLabel: View {
    @ObservedObject var model: TunnelModel
    var body: some View { Label("Oracle Tunnel", systemImage: model.controlState.menuBarSymbol) }
}
