import Testing
@testable import LidRunCore

@Test func detectsKnownDevWorkloads() {
    let workloads = WorkloadDetector.detect(in: [
        RunningProcess(name: "claude", command: "claude --dangerously-skip-permissions"),
        RunningProcess(name: "Cursor", command: "/Applications/Cursor.app/Contents/MacOS/Cursor"),
        RunningProcess(name: "docker", command: "docker build ."),
        RunningProcess(name: "ollama", command: "ollama serve"),
        RunningProcess(name: "Safari", command: "Safari"),
    ])

    #expect(workloads.map(\.label) == ["Claude Code", "Cursor", "Docker", "Ollama"])
}

@Test func detectorIgnoresUnrelatedProcesses() {
    let workloads = WorkloadDetector.detect(in: [
        RunningProcess(name: "Safari", command: "Safari"),
        RunningProcess(name: "Notes", command: "Notes"),
    ])

    #expect(workloads.isEmpty)
}

@Test func customProcessRulesDetectAdditionalWorkloads() {
    let workloads = WorkloadDetector.detect(
        in: [RunningProcess(name: "my-renderer", command: "my-renderer --long-job")],
        customNeedles: ["my-renderer"]
    )
    #expect(workloads.map(\.label) == ["my-renderer"])
}

@Test func systemProcessListCompletesAndReturnsProcesses() {
    #expect(!SystemProcessList().processes().isEmpty)
}
