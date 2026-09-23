import Foundation

/// User settings shared by the menu bar app and `apprun` (same UserDefaults domain).
public struct AppSettings: Equatable, Sendable {
    public static let domain = "io.opensource.lidrun"

    public var autoMode = false
    public var extendedDetection = false
    public var chargingOnly = false
    public var thermalSafety = true
    public var alerts = false
    public var lowBatteryPercent: Int? = 5
    public var watchdogMinutes: Int? = 480
    public var webhookURL = ""
    public var webhookToken = ""
    public var customProcessRules = ""
    public var language = "en"
    public var closedLidChecklistAccepted = false

    public init() {}

    /// Optional numbers are stored as 0 for "Off": a nil write would delete the key and bring the default back.
    public init(defaults: UserDefaults) {
        let fallback = AppSettings()
        autoMode = defaults.bool(forKey: "autoMode")
        extendedDetection = defaults.bool(forKey: "extendedDetection")
        chargingOnly = defaults.bool(forKey: "chargingOnly")
        thermalSafety = defaults.object(forKey: "thermalSafety") as? Bool ?? fallback.thermalSafety
        alerts = defaults.bool(forKey: "alerts")
        lowBatteryPercent = Self.optional(defaults.object(forKey: "lowBatteryPercent") as? Int ?? fallback.lowBatteryPercent ?? 0)
        watchdogMinutes = Self.optional(defaults.object(forKey: "watchdogMinutes") as? Int ?? fallback.watchdogMinutes ?? 0)
        webhookURL = defaults.string(forKey: "webhookURL") ?? ""
        webhookToken = defaults.string(forKey: "webhookToken") ?? ""
        customProcessRules = defaults.string(forKey: "customProcessRules") ?? ""
        language = defaults.string(forKey: "language") ?? fallback.language
        closedLidChecklistAccepted = defaults.bool(forKey: "closedLidChecklistAccepted")
    }

    public func save(to defaults: UserDefaults) {
        defaults.set(autoMode, forKey: "autoMode")
        defaults.set(extendedDetection, forKey: "extendedDetection")
        defaults.set(chargingOnly, forKey: "chargingOnly")
        defaults.set(thermalSafety, forKey: "thermalSafety")
        defaults.set(alerts, forKey: "alerts")
        defaults.set(lowBatteryPercent ?? 0, forKey: "lowBatteryPercent")
        defaults.set(watchdogMinutes ?? 0, forKey: "watchdogMinutes")
        defaults.set(webhookURL, forKey: "webhookURL")
        defaults.set(webhookToken, forKey: "webhookToken")
        defaults.set(customProcessRules, forKey: "customProcessRules")
        defaults.set(language, forKey: "language")
        defaults.set(closedLidChecklistAccepted, forKey: "closedLidChecklistAccepted")
    }

    public var guardrailPolicy: GuardrailPolicy {
        GuardrailPolicy(chargingOnly: chargingOnly, lowBatteryPercent: lowBatteryPercent, stopOnThermalPressure: thermalSafety)
    }

    private static func optional(_ value: Int) -> Int? { value == 0 ? nil : value }
}

public enum AutoModeAction: Equatable, Sendable {
    case none
    case start([String])
    case stop
}

public enum AutoMode {
    /// `paused`: the user stopped an Auto session and the same workloads are still running.
    /// `blocked`: a guardrail would stop a new session immediately — starting it caused a start/stop loop.
    public static func decide(
        enabled: Bool, sessionActive: Bool, isAutoSession: Bool,
        workloads: [String], paused: Bool, blocked: Bool
    ) -> AutoModeAction {
        guard enabled else { return .none }
        if isAutoSession, workloads.isEmpty { return .stop }
        if !sessionActive, !workloads.isEmpty, !paused, !blocked { return .start(Array(Set(workloads)).sorted()) }
        return .none
    }
}
