import Foundation
import LidRunCore

let arguments = Array(CommandLine.arguments.dropFirst())
let command = arguments.first == "--" ? Array(arguments.dropFirst()) : arguments

guard let executable = command.first else {
    FileHandle.standardError.write(Data("Usage: apprun -- <command> [arguments]\n".utf8))
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
        .trimmingCharacters(in: .whitespacesAndNewlines) ?? executable
}

do {
    let result = try CommandRunner().run(executable: resolvedExecutable, arguments: Array(command.dropFirst()))
    exit(result.exitCode)
} catch {
    FileHandle.standardError.write(Data("apprun: \(error)\n".utf8))
    exit(1)
}
