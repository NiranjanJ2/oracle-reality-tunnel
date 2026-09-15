import Testing
@testable import OracleTunnelCore

@Suite("Menu presentation")
struct PresentationTests {
    @Test func healthLabelsIncludeRoundedLatencyAndPath() {
        #expect(HealthState.healthy(latencyMS: 24.4, path: "direct").label == "Healthy · 24 ms · direct")
        #expect(HealthState.degraded(latencyMS: 182.6, path: "DERP lax").label == "Degraded · 183 ms · DERP lax")
    }

    @Test func nonLatencyHealthLabelsAreConcise() {
        #expect(HealthState.checking.label == "Checking connection…")
        #expect(HealthState.unreachable("timeout").label == "Unreachable · timeout")
        #expect(HealthState.disconnected.label == "Tunnel off")
    }

    @Test func healthSymbolsMapToLightSemantics() {
        #expect(HealthState.healthy(latencyMS: 1, path: "direct").symbolName == "circle.fill")
        #expect(HealthState.degraded(latencyMS: 1, path: "DERP lax").symbolName == "exclamationmark.circle.fill")
        #expect(HealthState.unreachable("timeout").symbolName == "xmark.circle.fill")
        #expect(HealthState.checking.symbolName == "circle.dotted")
    }

    @Test func menuBarSymbolReflectsControlState() {
        #expect(ControlState.tunneled.menuBarSymbol == "house.and.flag.fill")
        #expect(ControlState.privateOnly.menuBarSymbol == "house.fill")
        #expect(ControlState.disconnected.menuBarSymbol == "house.slash")
        #expect(ControlState.unavailable.menuBarSymbol == "exclamationmark.triangle")
    }

    @Test func switchLabelReflectsTunnelState() {
        #expect(ControlState.tunneled.switchLabel == "On")
        #expect(ControlState.disconnected.switchLabel == "Off")
        #expect(ControlState.unavailable.switchLabel == "Off")
        #expect(ControlState.disconnected.displayLabel(isBusy: true) == "Starting…")
        #expect(ControlState.tunneled.displayLabel(isBusy: true) == "Stopping…")
    }
}
