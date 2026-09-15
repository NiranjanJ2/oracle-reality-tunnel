import Foundation

public enum PingParser {
    public static func parse(stdout: String, stderr: String, exitCode: Int32) -> HealthState {
        guard exitCode == 0 else {
            return .unreachable(TunnelError.sanitized(stderr.isEmpty ? stdout : stderr))
        }
        guard stdout.localizedCaseInsensitiveContains("pong"),
              let latencyText = capture(#"in\s+([0-9]+(?:\.[0-9]+)?)ms"#, in: stdout),
              let latency = Double(latencyText)
        else {
            return .unreachable("No ping reply")
        }

        if let region = capture(#"DERP\(([^)]+)\)"#, in: stdout) {
            return .degraded(latencyMS: latency, path: "DERP \(region)")
        }
        guard capture(#"via\s+([^\s]+)"#, in: stdout) != nil else {
            return .unreachable("No ping path")
        }
        return latency < 150
            ? .healthy(latencyMS: latency, path: "direct")
            : .degraded(latencyMS: latency, path: "direct")
    }

    private static func capture(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(
                in: text,
                range: NSRange(text.startIndex..., in: text)
              ),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: text)
        else {
            return nil
        }
        return String(text[range])
    }
}
