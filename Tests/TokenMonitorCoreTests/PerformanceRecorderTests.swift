import Foundation
import Testing
@testable import TokenMonitorCore

struct PerformanceRecorderTests {
    @Test func captureRequiresSustainedCPUAndHonorsCooldown() {
        var policy = PerformanceCapturePolicy()
        let results = [0.0, 2, 4, 6, 602, 604].map { policy.observe(cpuPercent: 200, uptime: $0) }
        #expect(results == [false, false, true, false, false, true])
    }

    @Test func lowOrInvalidMeasurementBreaksConsecutiveRun() {
        var policy = PerformanceCapturePolicy(consecutiveSamples: 2, cooldown: 0)
        let measurements: [(Double, Double)] = [(90, 0), (.nan, 2), (90, 4), (1, 6), (90, 8), (90, 10)]
        let results = measurements.map { policy.observe(cpuPercent: $0.0, uptime: $0.1) }
        #expect(results == [false, false, false, false, false, true])
    }

    @Test func profileRetainsOnlyBoundedRedactedCallGraph() {
        let raw = "Process: secret@example.com /Users/secret/private-file\nCall graph:\n" +
            "12 syntheticCPUWork (in Test) (/Users/alice/private-project/main.swift:2) user@example.com\n" +
            String(repeating: "frame\n", count: 20_000) + "\nBinary Images:\n/private/sensitive/environment"
        let graph = PerformanceProfileRedaction.callGraph(from: raw)
        #expect(graph.contains("syntheticCPUWork"))
        #expect(!graph.contains("alice"))
        #expect(!graph.contains("@"))
        #expect(!graph.contains("Process:"))
        #expect(!graph.contains("Binary Images:"))
        #expect(!graph.contains("environment"))
        #expect(graph.count <= 48_000)
        #expect(PerformanceProfileRedaction.callGraph(from: "arbitrary input") == "No call graph was available.")
    }

    @Test func disabledRecorderDoesNotCreateFilesOrRecordActivities() async {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("tm-performance-off-\(UUID())")
        let recorder = PerformanceRecorder(directory: directory, version: "test", interval: 0.1)
        let token = recorder.begin(.analysisScan)
        recorder.end(token)
        await recorder.captureNow()
        #expect(!FileManager.default.fileExists(atPath: directory.path))
        #expect(!recorder.reportText.contains("analysisScan"))
        #expect(recorder.summaryText.contains("recording: off"))
    }

    @Test func savedTraceIsBoundedPrivateAnonymousAndReadableAfterRestart() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("tm-performance-on-\(UUID())")
        let recorder = PerformanceRecorder(directory: directory, version: "test", stackSamplingAllowed: false, interval: 0.1)
        recorder.setEnabled(true)
        let accountA = UUID(), accountB = UUID()
        for i in 0..<250 {
            let token = recorder.begin(.pageExtraction, provider: .claude, reader: i.isMultiple(of: 2) ? accountA : accountB)
            recorder.end(token)
        }
        try await Task.sleep(for: .milliseconds(350))
        await recorder.captureNow()
        let report = recorder.reportText
        #expect(report.contains("reader-1"))
        #expect(report.contains("reader-2"))
        #expect(!report.contains(accountA.uuidString))
        #expect(!report.contains(accountB.uuidString))
        #expect(report.components(separatedBy: "| pageExtraction |").count == 201)
        #expect(report.contains("unavailable in this build"))
        let file = directory.appendingPathComponent("performance-latest.json")
        let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
        #expect((attributes[.size] as? NSNumber)?.intValue ?? Int.max <= 512_000)
        #expect((attributes[.posixPermissions] as? NSNumber)?.intValue == 0o600)
        #expect((try FileManager.default.attributesOfItem(atPath: directory.path)[.posixPermissions] as? NSNumber)?.intValue == 0o700)
        recorder.setEnabled(false)
        _ = recorder.summaryText // Flush the serialized stop before checking persistence.
        let saved = try Data(contentsOf: file)
        try await Task.sleep(for: .milliseconds(250))
        #expect(try Data(contentsOf: file) == saved)
        let restored = PerformanceRecorder(directory: directory, version: "new session")
        #expect(restored.reportText.contains("reader-1"))
        #expect(restored.reportText.contains("Last saved trace version: test"))
    }
}
