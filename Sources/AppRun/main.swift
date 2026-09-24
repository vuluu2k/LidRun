import Foundation
import LidRunCore

// Same guardrails and webhook as the menu bar app (its UserDefaults domain).
// Inside the app bundle apprun shares the app's bundle id, where .standard already is that domain
// (and a suite with your own id is ignored).
let settingsDefaults = Bundle.main.bundleIdentifier == AppSettings.domain ? .standard : UserDefaults(suiteName: AppSettings.domain) ?? .standard
let settings = AppSettings(defaults: settingsDefaults)

/// Webhook plus ntfy phone push, both from the app's settings. Blocks until sent (10 s cap each).
func notify(title: String, body: String, event: String) {
    var requests = [Ntfy.request(topic: settings.ntfyTopic, title: title, message: body)].compactMap { $0 }
    if let url = URL(string: settings.webhookURL), !settings.webhookURL.isEmpty {
        var request = URLRequest(url: url, timeoutInterval: 10)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !settings.webhookToken.isEmpty { request.setValue("Bearer \(settings.webhookToken)", forHTTPHeaderField: "Authorization") }
        request.httpBody = try? WebhookPlatform.detect(url: url).body(event: event, reason: body)
        requests.append(request)
    }
    let done = DispatchGroup()
    for request in requests {
        done.enter()
        URLSession.shared.dataTask(with: request) { _, _, _ in done.leave() }.resume()
    }
    _ = done.wait(timeout: .now() + 10)
}

func fail(_ message: String, _ code: Int32) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(code)
}

let usage = """
Usage: apprun [--sleep] -- <command> [arguments]
       apprun notify [title]              push stdin hook JSON (or a default line) to phone/webhook
       apprun queue add -- <command>      append a job
       apprun queue [list|clear]          show or empty the queue
       apprun queue pause|resume          hold the queue after the current job
       apprun [--sleep] queue run         run jobs one by one, awake until the queue is empty
"""

signal(SIGPIPE, SIG_IGN)  // `apprun queue run | head` must not kill the runner mid-job
var arguments = Array(CommandLine.arguments.dropFirst())
let sleepWhenDone = arguments.first == "--sleep"
if sleepWhenDone { arguments.removeFirst() }

/// Resolves a bare command name through PATH like a shell would.
func resolve(_ executable: String) -> String {
    let resolvedExecutable: String
    if executable.contains("/") {
        resolvedExecutable = executable
    } else {
        let shell = Process()
        let pipe = Pipe()
        shell.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        shell.arguments = [executable]
        shell.standardOutput = pipe
        try? shell.run()
        shell.waitUntilExit()
        resolvedExecutable = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
    guard FileManager.default.isExecutableFile(atPath: resolvedExecutable) else { fail("apprun: command not found: \(executable)", 127) }
    return resolvedExecutable
}

switch (arguments.first, arguments.dropFirst().first) {
case ("notify", _):
    // Hooks pipe JSON on stdin; a terminal means a manual call.
    let input = isatty(STDIN_FILENO) == 0 ? FileHandle.standardInput.readDataToEndOfFile() : Data()
    notify(title: arguments.dropFirst().first ?? "Agent needs you", body: HookMessage.body(from: input, fallback: "Waiting for input"), event: "agent_notification")
    exit(0)

case ("queue", "add"?):
    let job = Array(arguments.dropFirst(2).drop { $0 == "--" })
    guard !job.isEmpty else { fail(usage, 64) }
    do { try JobQueue().add(job) } catch { fail("apprun: \(error)", 1) }
    exit(0)

case ("queue", "clear"?):
    do { try JobQueue().clear() } catch { fail("apprun: \(error)", 1) }
    exit(0)

case ("queue", "pause"?), ("queue", "resume"?):
    JobQueue().setPaused(arguments[1] == "pause")
    exit(0)

case ("queue", "list"?), ("queue", nil):
    let queue = JobQueue()
    if let job = queue.running() { print("running: \(job)") }
    queue.list().enumerated().forEach { print("\($0.offset + 1). \($0.element)") }
    print("(\(queue.list().count) queued\(queue.isPaused ? ", paused" : "") in \(queue.url.path))")
    exit(0)

case ("queue", "run"?):
    let queue = JobQueue()
    var ok = 0, failed: [String] = []
    var saidPaused = false
    while !queue.list().isEmpty {
        // Paused from the menu bar: hold nothing awake, check again shortly.
        if queue.isPaused {
            if !saidPaused { print("apprun queue: paused — run `apprun queue resume` to continue"); saidPaused = true }
            queue.setRunning(nil)
            Thread.sleep(forTimeInterval: 5)
            continue
        }
        // Safety beats convenience: never start a job while a guardrail says stop; remaining jobs stay in the file.
        if case .stop(let reason) = SafetyGovernor.evaluate(SystemGuardrailReader().snapshot(), policy: settings.guardrailPolicy) {
            queue.setRunning(nil)
            notify(title: "Queue paused", body: "Guardrail: \(reason.rawValue). \(queue.list().count) job(s) left.", event: "stopped")
            exit(1)
        }
        saidPaused = false
        guard let job = try? queue.pop() else { break }
        print("apprun queue: \(job)")
        queue.setRunning(job)
        let log = queue.newLog(for: job)
        do {
            let result = try CommandRunner().run(executable: "/bin/sh", arguments: ["-c", job], policy: settings.guardrailPolicy, outputLog: log)
            let tail = JobQueue.tail(of: log)
            let line = "\(job) exited \(result.exitCode) after \(Int(result.duration))s" + (tail.isEmpty ? "" : "\n\(tail)") + "\nLog: \(log.path)"
            // Ctrl-C / kill reaches the job (the runner forwards it); treat it as "stop the queue".
            if [SIGINT, SIGTERM, SIGHUP].contains(result.exitCode - 128) {
                queue.setRunning(nil)
                fail("apprun queue: interrupted during \(job); \(queue.list().count) job(s) left", result.exitCode)
            }
            if result.exitCode == 0 { ok += 1 } else { failed.append(job) }
            notify(title: result.exitCode == 0 ? "Job done" : "Job failed", body: line, event: "command_finished")
            if let stop = result.safetyStop {
                queue.setRunning(nil)
                notify(title: "Queue paused", body: "Guardrail: \(stop.rawValue). \(queue.list().count) job(s) left.", event: "stopped")
                exit(1)
            }
        } catch {
            failed.append(job)
            notify(title: "Job failed", body: "\(job): \(error)", event: "command_finished")
        }
    }
    queue.setRunning(nil)
    notify(title: "Queue finished", body: "\(ok) ok, \(failed.count) failed" + (failed.isEmpty ? "" : ": " + failed.joined(separator: "; ")), event: "queue_finished")
    // Nothing ran (e.g. the queue was cleared while paused): don't surprise anyone with a sleep.
    if sleepWhenDone, ok + failed.count > 0 { SystemSleep.sleepNow() }
    exit(failed.isEmpty ? 0 : 1)

default:
    let command = arguments.first == "--" ? Array(arguments.dropFirst()) : arguments
    guard let executable = command.first else { fail(usage, 64) }
    do {
        let result = try CommandRunner().run(executable: resolve(executable), arguments: Array(command.dropFirst()), policy: settings.guardrailPolicy)
        let summary = "\(command.joined(separator: " ")) exited \(result.exitCode) after \(Int(result.duration))s"
            + (result.safetyStop.map { " (stopped keeping awake: \($0.rawValue))" } ?? "")
        notify(title: "Command finished", body: summary, event: "command_finished")
        if sleepWhenDone { SystemSleep.sleepNow() }
        exit(result.exitCode)
    } catch {
        fail("apprun: \(error)", 1)
    }
}
