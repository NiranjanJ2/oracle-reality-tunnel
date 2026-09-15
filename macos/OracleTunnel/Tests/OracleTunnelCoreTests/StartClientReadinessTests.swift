import Foundation
import Testing

@Suite("Tunnel startup readiness")
struct StartClientReadinessTests {
    @Test func startWaitsForRoutingAndDNSNotOnlyTUN() throws {
        let testFile = URL(fileURLWithPath: #filePath)
        let package = testFile.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let script = try String(contentsOf: package.appending(path: "Resources/start-client.sh"), encoding: .utf8)
        #expect(script.contains("route -n get 1.1.1.1"))
        #expect(script.contains("interface: utun233"))
        #expect(script.contains("networksetup -getdnsservers Wi-Fi"))
        #expect(script.contains("dig @127.0.0.1"))
        #expect(script.contains("rm -f \"$STATE_DIR/tun-enabled\""))
    }
}
