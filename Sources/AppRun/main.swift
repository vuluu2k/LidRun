import Foundation
import LidRunCore

var arguments = Array(CommandLine.arguments.dropFirst())
let sleepWhenDone = arguments.first == "--sleep"
if sleepWhenDone { arguments.removeFirst() }
let command = arguments.first == "--" ? Array(arguments.dropFirst()) : arguments

guard let executable = command.first else {
    FileHandle.standardError.write(Data("Usage: apprun [--sleep] -- <command> [arguments]\n".utf8))
    exit(64)
}

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
guard FileManager.default.isExecutableFile(atPath: resolvedExecutable) else {
    FileHandle.standardError.write(Data("apprun: command not found: \(executable)\n".utf8))
    exit(127)
}

// Same guardrails and webhook as the menu bar app (its UserDefaults domain).
// Inside the app bundle apprun shares the app's bundle id, where .standard already is that domain
// (and a suite with your own id is ignored).
let settingsDefaults = Bundle.main.bundleIdentifier == AppSettings.domain ? .standard : UserDefaults(suiteName: AppSettings.domain) ?? .standard
let settings = AppSettings(defaults: settingsDefaults)

@MainActor func postWebhook(event: String, reason: String) {
    guard let url = URL(string: settings.webhookURL), !settings.webhookURL.isEmpty else { return }
    var request = URLRequest(url: url, timeoutInterval: 10)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    if !settings.webhookToken.isEmpty { request.setValue("Bearer \(settings.webhookToken)", forHTTPHeaderField: "Authorization") }
    request.httpBody = try? WebhookPlatform.detect(url: url).body(event: event, reason: reason)
    let done = DispatchSemaphore(value: 0)
    URLSession.shared.dataTask(with: request) { _, _, _ in done.signal() }.resume()
    _ = done.wait(timeout: .now() + 10)
}

do {
    let result = try CommandRunner().run(executable: resolvedExecutable, arguments: Array(command.dropFirst()), policy: settings.guardrailPolicy)
    let summary = "\(command.joined(separator: " ")) exited \(result.exitCode) after \(Int(result.duration))s"
        + (result.safetyStop.map { " (stopped keeping awake: \($0.rawValue))" } ?? "")
    postWebhook(event: "command_finished", reason: summary)
    if sleepWhenDone { SystemSleep.sleepNow() }
    exit(result.exitCode)
} catch {
    FileHandle.standardError.write(Data("apprun: \(error)\n".utf8))
    exit(1)
}
