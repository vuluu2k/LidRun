import Testing
@testable import LidRunCore

@Test func chargingOnlyStopsWhenUnplugged() {
    let snapshot = GuardrailSnapshot(isCharging: false, batteryPercent: 80, thermalPressure: .nominal)
    #expect(SafetyGovernor.evaluate(snapshot, policy: GuardrailPolicy(chargingOnly: true)) == .stop(.chargerDisconnected))
}

@Test func lowBatteryStopsAtThreshold() {
    let snapshot = GuardrailSnapshot(isCharging: true, batteryPercent: 5, thermalPressure: .nominal)
    #expect(SafetyGovernor.evaluate(snapshot, policy: GuardrailPolicy(lowBatteryPercent: 5)) == .stop(.lowBattery))
}

@Test func thermalPressureStopsOnSeriousOrCritical() {
    let serious = GuardrailSnapshot(isCharging: true, batteryPercent: 90, thermalPressure: .serious)
    let critical = GuardrailSnapshot(isCharging: true, batteryPercent: 90, thermalPressure: .critical)
    #expect(SafetyGovernor.evaluate(serious, policy: GuardrailPolicy()) == .stop(.thermalPressure))
    #expect(SafetyGovernor.evaluate(critical, policy: GuardrailPolicy()) == .stop(.thermalPressure))
}

@Test func nominalSafeStateKeepsAwake() {
    let snapshot = GuardrailSnapshot(isCharging: true, batteryPercent: 90, thermalPressure: .nominal)
    #expect(SafetyGovernor.evaluate(snapshot, policy: GuardrailPolicy(chargingOnly: true, lowBatteryPercent: 5)) == .keepAwake)
}
