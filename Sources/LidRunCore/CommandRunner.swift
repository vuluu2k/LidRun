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

    /// With `outputLog`, stdout and stderr are also copied to that file (the command then sees a pipe, not a terminal).
    public func run(executable: String, arguments: [String], policy: GuardrailPolicy = GuardrailPolicy(), outputLog: URL? = nil) throws -> CommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardInput = FileHandle.standardInput
        process.standardOutput = FileHandle.standardOutput
        process.standardError = FileHandle.standardError
        let copied = DispatchGroup()
        var pipe: Pipe?
        if let outputLog, FileManager.default.createFile(atPath: outputLog.path, contents: nil),
           let file = try? FileHandle(forWritingTo: outputLog) {
            let output = Pipe()
            process.standardOutput = output
            process.standardError = output
            pipe = output
            copied.enter()
            DispatchQueue.global().async {
                while let data = try? output.fileHandleForReading.read(upToCount: 65_536), !data.isEmpty {
                    // Throwing writes: a closed terminal or full disk must not crash apprun mid-job.
                    try? FileHandle.standardOutput.write(contentsOf: data)
                    try? file.write(contentsOf: data)
                }
                try? file.close()
                copied.leave()
            }
        }

        let command = ([executable] + arguments).joined(separator: " ")
        let startedAt = Date()
        try assertion.acquire(reason: "Run Command: \(command)")
        try log.append(RunEvent(type: .started, reason: "command: \(command)"))

        do {
            try process.run()
            // Only the child may hold the write end, or the copy loop never sees end-of-file.
            try? pipe?.fileHandleForWriting.close()
        } catch {
            try? pipe?.fileHandleForWriting.close()
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
        defer {
            forwarders.forEach { $0.cancel() }
            // Let Ctrl-C reach the caller again (apprun queue waits between jobs).
            [SIGINT, SIGTERM, SIGHUP].forEach { signal($0, SIG_DFL) }
        }

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
        // Background children that inherited the pipe can keep it open forever; don't wait on them.
        // ponytail: after the cap the copy thread lingers and may mix into the next job's output; fine for `&` daemons.
        _ = copied.wait(timeout: .now() + 2)
        assertion.release()

        // Shell convention: a child killed by signal N exits 128 + N.
        let exitCode = process.terminationReason == .uncaughtSignal ? 128 + process.terminationStatus : process.terminationStatus
        let duration = Date().timeIntervalSince(startedAt)
        try? log.append(RunEvent(type: .stopped, reason: "command exit \(exitCode) after \(Int(duration))s"))
        return CommandResult(exitCode: exitCode, duration: duration, safetyStop: safetyStop)
    }
}
