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
let settings = UserDefaults(suiteName: "io.opensource.lidrun") ?? .standard
let lowBattery = settings.object(forKey: "lowBatteryPercent") as? Int ?? 5
let policy = GuardrailPolicy(
    chargingOnly: settings.bool(forKey: "chargingOnly"),
    lowBatteryPercent: lowBattery == 0 ? nil : lowBattery,
    stopOnThermalPressure: settings.object(forKey: "thermalSafety") as? Bool ?? true
)

@MainActor func postWebhook(event: String, reason: String) {
    guard let value = settings.string(forKey: "webhookURL"), let url = URL(string: value), !value.isEmpty else { return }
    var request = URLRequest(url: url, timeoutInterval: 10)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    if let token = settings.string(forKey: "webhookToken"), !token.isEmpty {
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }
    request.httpBody = try? WebhookPlatform.detect(url: url).body(event: event, reason: reason)
    let done = DispatchSemaphore(value: 0)
    URLSession.shared.dataTask(with: request) { _, _, _ in done.signal() }.resume()
    _ = done.wait(timeout: .now() + 10)
}

do {
    let result = try CommandRunner().run(executable: resolvedExecutable, arguments: Array(command.dropFirst()), policy: policy)
    let summary = "\(command.joined(separator: " ")) exited \(result.exitCode) after \(Int(result.duration))s"
        + (result.safetyStop.map { " (stopped keeping awake: \($0.rawValue))" } ?? "")
    postWebhook(event: "command_finished", reason: summary)
    if sleepWhenDone { SystemSleep.sleepNow() }
    exit(result.exitCode)
} catch {
    FileHandle.standardError.write(Data("apprun: \(error)\n".utf8))
    exit(1)
}
