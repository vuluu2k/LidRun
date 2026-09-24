import Foundation
import Testing
@testable import LidRunCore

@Test func jobQueueKeepsOrderAndQuotesForTheShell() throws {
    let queue = JobQueue(url: FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString).appendingPathComponent("queue.txt"))
    try queue.add(["echo", "it's a test", "$HOME"])
    try queue.add(["true"])
    #expect(queue.list().count == 2)

    let first = try #require(try queue.pop())
    let shell = Process()
    let pipe = Pipe()
    shell.executableURL = URL(fileURLWithPath: "/bin/sh")
    shell.arguments = ["-c", first]
    shell.standardOutput = pipe
    try shell.run()
    shell.waitUntilExit()
    #expect(String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) == "it's a test $HOME\n")

    #expect(try queue.pop() == "true")
    #expect(try queue.pop() == nil)
}

@Test func hookMessagePrefixesProject() {
    let json = Data(#"{"message":"Claude needs your permission to use Bash","cwd":"/Users/me/app"}"#.utf8)
    #expect(HookMessage.body(from: json, fallback: "x") == "app: Claude needs your permission to use Bash")
    #expect(HookMessage.body(from: Data(), fallback: "Waiting") == "Waiting")
}
