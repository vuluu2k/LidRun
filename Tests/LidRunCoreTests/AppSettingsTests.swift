import Foundation
import Testing
@testable import LidRunCore

private func freshDefaults() -> UserDefaults {
    let name = "lidrun-tests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defaults.removePersistentDomain(forName: name)
    return defaults
}

@Test func settingsRoundTripIncludingOffValues() {
    let defaults = freshDefaults()
    var settings = AppSettings()
    settings.chargingOnly = true
    settings.lowBatteryPercent = nil
    settings.watchdogMinutes = nil
    settings.webhookToken = "secret"
    settings.extendedDetection = true
    settings.save(to: defaults)

    #expect(AppSettings(defaults: defaults) == settings)
}

@Test func missingSettingsUseSafeDefaults() {
    let settings = AppSettings(defaults: freshDefaults())
    #expect(settings.thermalSafety)
    #expect(settings.lowBatteryPercent == 5)
    #expect(settings.watchdogMinutes == 480)
}

@Test func autoModeStartsOnlyWhenAllowed() {
    func decide(active: Bool = false, auto: Bool = false, workloads: [String] = ["Docker"], paused: Bool = false, blocked: Bool = false) -> AutoModeAction {
        AutoMode.decide(enabled: true, sessionActive: active, isAutoSession: auto, workloads: workloads, paused: paused, blocked: blocked)
    }
    #expect(decide(workloads: ["Node", "Docker", "Node"]) == .start(["Docker", "Node"]))
    #expect(decide(blocked: true) == .none)          // guardrail: no start/stop loop
    #expect(decide(paused: true) == .none)           // user stopped it: stay stopped
    #expect(decide(active: true) == .none)           // never replaces a manual session
    #expect(decide(active: true, auto: true, workloads: []) == .stop)
    #expect(decide(active: true, auto: false, workloads: []) == .none)
    #expect(AutoMode.decide(enabled: false, sessionActive: false, isAutoSession: false, workloads: ["Docker"], paused: false, blocked: false) == .none)
}
