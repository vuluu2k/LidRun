import Foundation

/// When the battery will hit the low-battery guardrail, from macOS's time-to-empty estimate.
public enum BatteryForecast {
    /// Scales time-to-empty down to the guardrail threshold (the drain is roughly linear in percent).
    public static func guardrailTime(now: Date, snapshot: GuardrailSnapshot, threshold: Int?) -> Date? {
        guard !snapshot.isCharging, let seconds = snapshot.secondsToEmpty,
              let percent = snapshot.batteryPercent, percent > 0 else { return nil }
        let usable = Double(percent - (threshold ?? 0)) / Double(percent)
        return now.addingTimeInterval(max(0, seconds * usable))
    }

    /// Warn when the battery runs out before a timer ends, or within 30 minutes for open-ended sessions.
    public static func runsOutEarly(guardrailAt: Date?, releaseAt: Date?, now: Date) -> Bool {
        guard let guardrailAt else { return false }
        return guardrailAt < (releaseAt ?? now.addingTimeInterval(30 * 60))
    }
}

/// Spots an AI agent that is still running but doing nothing, usually waiting for a permission or an answer.
public struct IdleAgentMonitor: Sendable {
    public static let agentLabels: Set<String> = ["Claude Code", "Codex"]
    public var idleAfter: TimeInterval
    public var cpuThreshold: Double
    private var idleSince: Date?
    private var alerted = false

    public init(idleAfter: TimeInterval = 15 * 60, cpuThreshold: Double = 1) {
        self.idleAfter = idleAfter
        self.cpuThreshold = cpuThreshold
    }

    /// Feed the agents' summed CPU (nil when none run). Returns true once per idle stretch.
    public mutating func update(agentCPU: Double?, now: Date) -> Bool {
        guard let agentCPU, agentCPU < cpuThreshold else {
            idleSince = nil
            alerted = false
            return false
        }
        let since = idleSince ?? now
        idleSince = since
        guard !alerted, now.timeIntervalSince(since) >= idleAfter else { return false }
        alerted = true
        return true
    }
}
