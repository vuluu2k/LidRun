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

        // Forward termination signals so killing apprun never orphans the child.
        let pid = process.processIdentifier
        let forwarders = [SIGINT, SIGTERM, SIGHUP].map { sig in
            signal(sig, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: sig, queue: .global())
            source.setEventHandler { kill(pid, sig) }
            source.resume()
            return source
        }
        defer { forwarders.forEach { $0.cancel() } }

        let exited = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in exited.signal() }
        var safetyStop: StopReason?
        while process.isRunning {
            if safetyStop == nil,
               case .stop(let reason) = SafetyGovernor.evaluate(guardrails.snapshot(), policy: policy) {
                safetyStop = reason
                assertion.release()
                try? log.append(RunEvent(type: .stopped, reason: reason.rawValue))
            }
            _ = exited.wait(timeout: .now() + 1)
        }
        process.waitUntilExit()
        assertion.release()

        // Shell convention: a child killed by signal N exits 128 + N.
        let exitCode = process.terminationReason == .uncaughtSignal ? 128 + process.terminationStatus : process.terminationStatus
        let duration = Date().timeIntervalSince(startedAt)
        try? log.append(RunEvent(type: .stopped, reason: "command exit \(exitCode) after \(Int(duration))s"))
        return CommandResult(exitCode: exitCode, duration: duration, safetyStop: safetyStop)
    }
}
