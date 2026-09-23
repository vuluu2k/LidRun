import Foundation

public struct CommandResult: Equatable, Sendable {
    public let exitCode: Int32
    public let duration: TimeInterval
    public let safetyStop: StopReason?

    public init(exitCode: Int32, duration: TimeInterval, safetyStop: StopReason?) {
        self.exitCode = exitCode
        self.duration = duration
        self.safetyStop = safetyStop
    }
}

public final class CommandRunner: @unchecked Sendable {
    private let assertion: SleepAssertion
    private let log: EventLog
    private let guardrails: GuardrailReading

    public init(
        assertion: SleepAssertion = SystemPowerAssertion(),
        log: EventLog = EventLog(),
        guardrails: GuardrailReading = SystemGuardrailReader()
    ) {
        self.assertion = assertion
        self.log = log
        self.guardrails = guardrails
    }

    public func run(executable: String, arguments: [String], policy: GuardrailPolicy = GuardrailPolicy()) throws -> CommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardInput = FileHandle.standardInput
        process.standardOutput = FileHandle.standardOutput
        process.standardError = FileHandle.standardError

        let command = ([executable] + arguments).joined(separator: " ")
        let startedAt = Date()
        try assertion.acquire(reason: "Run Command: \(command)")
        try log.append(RunEvent(type: .started, reason: "command: \(command)"))

        do {
            try process.run()
        } catch {
            assertion.release()
            try? log.append(RunEvent(type: .stopped, reason: "command launch failed: \(error)"))
            throw error
        }

        var safetyStop: StopReason?
        while process.isRunning {
            if safetyStop == nil,
               case .stop(let reason) = SafetyGovernor.evaluate(guardrails.snapshot(), policy: policy) {
                safetyStop = reason
                assertion.release()
                try? log.append(RunEvent(type: .stopped, reason: reason.rawValue))
            }
            Thread.sleep(forTimeInterval: 1)
        }
        process.waitUntilExit()
        assertion.release()

        let duration = Date().timeIntervalSince(startedAt)
        try? log.append(RunEvent(type: .stopped, reason: "command exit \(process.terminationStatus) after \(Int(duration))s"))
        return CommandResult(exitCode: process.terminationStatus, duration: duration, safetyStop: safetyStop)
    }
}
