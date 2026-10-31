import Foundation
import TokenMonitorCore

@inline(never)
func syntheticCPUWork() -> UInt64 {
    let end = ProcessInfo.processInfo.systemUptime + 7
    var value: UInt64 = 17
    while ProcessInfo.processInfo.systemUptime < end {
        for _ in 0..<100_000 { value = value &* 6364136223846793005 &+ 1 }
    }
    return value
}

@main
struct PerformanceProof {
    static func main() async throws {
        let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        let recorder = PerformanceRecorder(directory: directory, version: "synthetic runtime proof", interval: 0.25)
        recorder.setEnabled(true)
        let activity = recorder.begin(.analysisScan)
        let result = await Task.detached(priority: .utility) { syntheticCPUWork() }.value
        recorder.end(activity)
        try await Task.sleep(for: .seconds(3))
        let automaticReport = recorder.reportText
        guard automaticReport.contains("Sustained high app CPU; 3 seconds") else {
            print("FAIL: automatic high-CPU capture missing")
            recorder.setEnabled(false)
            exit(1)
        }
        await recorder.captureNow()
        let report = recorder.reportText
        try report.write(to: directory.appendingPathComponent("proof-report.txt"), atomically: true, encoding: .utf8)
        guard report.contains("Manual capture; 3 seconds"), report.contains("syntheticCPUWork"),
              report.contains("Last sustained high-CPU profile (preserved across manual captures)"),
              report.contains("analysisScan"), report.contains("main-thread delay"),
              !report.contains("/Users/"), !report.contains("Binary Images:") else {
            print("FAIL: native CPU/profile/activity proof; inspect local proof-report.txt")
            recorder.setEnabled(false)
            exit(1)
        }
        print("PASS: real sustained CPU detected; native stack identifies syntheticCPUWork (\(result)); activity correlated")
        print("PASS: manual capture retains the earlier high-CPU call graph")
        print(recorder.summaryText)
        let cancelledCapture = Task { await recorder.captureNow() }
        try await Task.sleep(for: .milliseconds(250))
        recorder.setEnabled(false)
        await cancelledCapture.value
        _ = recorder.summaryText
        let raw = directory.appendingPathComponent("performance-work.sample")
        guard (try? Data(contentsOf: raw).isEmpty) == true else { print("FAIL: raw profile was not cleared"); exit(1) }
        print("PASS: raw profile cleared; debug disabled and timer stopped")
    }
}
