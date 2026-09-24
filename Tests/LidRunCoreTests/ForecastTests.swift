import Foundation
import Testing
@testable import LidRunCore

@Test func batteryForecastScalesToTheGuardrail() {
    let now = Date(timeIntervalSince1970: 0)
    let onBattery = GuardrailSnapshot(isCharging: false, batteryPercent: 50, thermalPressure: .nominal, secondsToEmpty: 10_000)
    // 50% → 10% threshold uses 40/50 of the time left.
    #expect(BatteryForecast.guardrailTime(now: now, snapshot: onBattery, threshold: 10) == now.addingTimeInterval(8_000))
    var charging = onBattery
    charging.isCharging = true
    #expect(BatteryForecast.guardrailTime(now: now, snapshot: charging, threshold: 10) == nil)

    let stop = now.addingTimeInterval(3_600)
    #expect(BatteryForecast.runsOutEarly(guardrailAt: stop, releaseAt: now.addingTimeInterval(7_200), now: now))
    #expect(!BatteryForecast.runsOutEarly(guardrailAt: stop, releaseAt: now.addingTimeInterval(1_800), now: now))
    #expect(!BatteryForecast.runsOutEarly(guardrailAt: stop, releaseAt: nil, now: now))  // open-ended: only within 30 min
    #expect(BatteryForecast.runsOutEarly(guardrailAt: now.addingTimeInterval(600), releaseAt: nil, now: now))
}

@Test func idleAgentAlertsOncePerIdleStretch() {
    var monitor = IdleAgentMonitor(idleAfter: 60, cpuThreshold: 1)
    let t0 = Date(timeIntervalSince1970: 0)
    func step(_ cpu: Double?, _ seconds: TimeInterval) -> Bool { monitor.update(agentCPU: cpu, now: t0.addingTimeInterval(seconds)) }
    #expect(!step(0.2, 0))
    #expect(!step(0.1, 30))
    #expect(step(0.1, 61))
    #expect(!step(0.1, 200))  // already told
    #expect(!step(25, 210))   // busy again resets
    #expect(!step(0, 220))
    #expect(step(0, 281))
    #expect(!step(nil, 290))  // no agent: nothing to say
}
