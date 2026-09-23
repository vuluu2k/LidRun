import Foundation

public enum StopReason: String, Equatable, Sendable {
    case manual
    case timerExpired = "timer expired"
    case appQuit = "app quit"
    case chargerDisconnected = "charger disconnected"
    case lowBattery = "low battery"
    case thermalPressure = "thermal pressure"
    case workloadFinished = "workload finished"
    case watchdog = "watchdog limit"
    case replaced = "replaced by new session"
    case processFinished = "process finished"
}

public struct SessionState: Equatable, Sendable {
    public var isActive: Bool
    public var whyAwake: String
    public var nextRelease: String
    public var startedAt: Date?
    /// When a timed session ends on its own; nil for open-ended sessions.
    public var releaseAt: Date?

    public init(isActive: Bool, whyAwake: String, nextRelease: String, startedAt: Date? = nil, releaseAt: Date? = nil) {
        self.isActive = isActive
        self.whyAwake = whyAwake
        self.nextRelease = nextRelease
        self.startedAt = startedAt
        self.releaseAt = releaseAt
    }
}

public final class SessionController: @unchecked Sendable {
    private let assertion: SleepAssertion
    private let log: EventLog
    private var timer: DispatchSourceTimer?

    public private(set) var state = SessionState(
        isActive: false,
        whyAwake: "Inactive",
        nextRelease: "None",
        startedAt: nil
    )

    public var onChange: ((SessionState) -> Void)?

    public init(assertion: SleepAssertion = SystemPowerAssertion(), log: EventLog = EventLog()) {
        self.assertion = assertion
        self.log = log
    }

    public func startManual(now: Date = Date()) throws {
        try start(reason: "Manual keep-awake", duration: nil, now: now)
    }

    public func startTimed(seconds: TimeInterval, now: Date = Date()) throws {
        try start(reason: "Timer keep-awake", duration: seconds, now: now)
    }

    public func startWatching(_ label: String, now: Date = Date()) throws {
        try start(reason: "Watching: \(label)", duration: nil, now: now)
    }

    public func startScheduled(until end: Date, now: Date = Date()) throws {
        try start(reason: "Schedule", duration: end.timeIntervalSince(now), now: now)
    }

    public func startAuto(workloads: [String], now: Date = Date()) throws {
        let labels = workloads.isEmpty ? "dev workload" : workloads.joined(separator: ", ")
        try start(reason: "Auto Mode: \(labels)", duration: nil, now: now)
    }

    public func stop(reason: StopReason = .manual, now: Date = Date()) {
        let wasActive = state.isActive
        timer?.cancel()
        timer = nil
        assertion.release()
        state = SessionState(isActive: false, whyAwake: "Inactive", nextRelease: "None", startedAt: nil)
        if wasActive {
            try? log.append(RunEvent(time: now, type: .stopped, reason: reason.rawValue))
            onChange?(state)
        }
    }

    private func start(reason: String, duration: TimeInterval?, now: Date) throws {
        // Switching sessions keeps the report accurate but must not fire onChange(inactive):
        // that would disarm Closed-Lid and send a spurious "stopped" alert.
        timer?.cancel()
        timer = nil
        if state.isActive { try? log.append(RunEvent(time: now, type: .stopped, reason: StopReason.replaced.rawValue)) }
        try assertion.acquire(reason: reason)
        state = SessionState(
            isActive: true,
            whyAwake: reason,
            nextRelease: duration.map { "Timer: \(Self.format(duration: $0))" } ?? "Manual stop",
            startedAt: now,
            releaseAt: duration.map { now.addingTimeInterval($0) }
        )
        try log.append(RunEvent(time: now, type: .started, reason: reason))
        scheduleTimer(duration)
        onChange?(state)
    }

    private func scheduleTimer(_ duration: TimeInterval?) {
        guard let duration else { return }
        let source = DispatchSource.makeTimerSource(queue: .main)
        source.schedule(wallDeadline: .now() + duration)  // wall clock: an uptime deadline pauses while the Mac sleeps
        source.setEventHandler { [weak self] in self?.stop(reason: .timerExpired) }
        source.resume()
        timer = source
    }

    private static func format(duration: TimeInterval) -> String {
        let minutes = Int(duration / 60)
        return minutes < 60 ? "\(minutes)m" : "\(minutes / 60)h \(minutes % 60)m"
    }

    deinit {
        stop(reason: .appQuit)
    }
}
