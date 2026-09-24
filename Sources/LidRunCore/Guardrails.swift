import Foundation
import IOKit.ps

public enum ThermalPressure: String, Codable, Sendable {
    case nominal
    case fair
    case serious
    case critical
}

public struct GuardrailPolicy: Equatable, Sendable {
    public var chargingOnly: Bool
    public var lowBatteryPercent: Int?
    public var stopOnThermalPressure: Bool

    public init(chargingOnly: Bool = false, lowBatteryPercent: Int? = 5, stopOnThermalPressure: Bool = true) {
        self.chargingOnly = chargingOnly
        self.lowBatteryPercent = lowBatteryPercent
        self.stopOnThermalPressure = stopOnThermalPressure
    }
}

public struct GuardrailSnapshot: Equatable, Sendable {
    public var isCharging: Bool
    public var batteryPercent: Int?
    public var thermalPressure: ThermalPressure
    /// macOS's own battery time-to-empty estimate; nil on AC power or while it is still calculating.
    public var secondsToEmpty: TimeInterval?

    public init(isCharging: Bool, batteryPercent: Int?, thermalPressure: ThermalPressure, secondsToEmpty: TimeInterval? = nil) {
        self.isCharging = isCharging
        self.batteryPercent = batteryPercent
        self.thermalPressure = thermalPressure
        self.secondsToEmpty = secondsToEmpty
    }
}

public enum GuardrailDecision: Equatable, Sendable {
    case keepAwake
    case stop(StopReason)
}

public enum SafetyGovernor {
    public static func evaluate(_ snapshot: GuardrailSnapshot, policy: GuardrailPolicy) -> GuardrailDecision {
        if policy.chargingOnly, !snapshot.isCharging {
            return .stop(.chargerDisconnected)
        }
        if let threshold = policy.lowBatteryPercent,
           let battery = snapshot.batteryPercent,
           battery <= threshold {
            return .stop(.lowBattery)
        }
        if policy.stopOnThermalPressure,
           snapshot.thermalPressure == .serious || snapshot.thermalPressure == .critical {
            return .stop(.thermalPressure)
        }
        return .keepAwake
    }
}

public protocol GuardrailReading: Sendable {
    func snapshot() -> GuardrailSnapshot
}

public struct SystemGuardrailReader: GuardrailReading {
    public init() {}

    public func snapshot() -> GuardrailSnapshot {
        let info = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let powerSource = IOPSGetProvidingPowerSourceType(info).takeUnretainedValue() as String
        return GuardrailSnapshot(
            isCharging: powerSource == kIOPSACPowerValue,
            batteryPercent: Self.batteryPercent(info),
            thermalPressure: ProcessInfo.processInfo.thermalState.guardrailPressure,
            secondsToEmpty: Self.secondsToEmpty()
        )
    }

    private static func secondsToEmpty() -> TimeInterval? {
        let estimate = IOPSGetTimeRemainingEstimate()
        return estimate > 0 ? estimate : nil  // -1 unknown, -2 unlimited (on AC)
    }

    private static func batteryPercent(_ info: CFTypeRef) -> Int? {
        let sources = IOPSCopyPowerSourcesList(info).takeRetainedValue() as [CFTypeRef]
        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(info, source).takeUnretainedValue() as? [String: Any],
                  let current = description[kIOPSCurrentCapacityKey] as? Int,
                  let max = description[kIOPSMaxCapacityKey] as? Int,
                  max > 0 else { continue }
            return Int((Double(current) / Double(max) * 100).rounded())
        }
        return nil
    }
}

private extension ProcessInfo.ThermalState {
    var guardrailPressure: ThermalPressure {
        switch self {
        case .nominal: .nominal
        case .fair: .fair
        case .serious: .serious
        case .critical: .critical
        @unknown default: .critical
        }
    }
}
