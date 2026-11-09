import Darwin
import Foundation
import Testing
@testable import Lumen

/// T2 (Toby): Provläge for a long time on looped speech, in the Simulator. Every minute: the app's memory, answers
/// and their first-text times so far, Scribe reconnects, whether the session and the mode are still on.
/// Goes to `<LUMEN_E2E_OUT>/long.json`; `scripts/apptest/long_curves.py` draws the curves.
///
/// Runs only when `scripts/apptest/long.sh` sets `LUMEN_E2E_LONG_MINUTES` (manual). Live and paid: Scribe for the
/// whole run and one `/answer` about every 25 s. Answers are not spoken. Simulator only: never a device verification.
enum LongRunEnvironment {
    static var minutes: Double? {
        ProcessInfo.processInfo.environment["LUMEN_E2E_LONG_MINUTES"].flatMap(Double.init)
    }
}

@MainActor
@Suite(.serialized, .enabled(if: LongRunEnvironment.minutes != nil && ChainEnvironment.audioDir != nil,
                             "set LUMEN_E2E_LONG_MINUTES and LUMEN_E2E_DIR (scripts/apptest/long.sh)"))
struct LongRunE2ETests {
    struct Sample: Codable {
        let minute: Double
        let memoryMB: Double
        let heard: Int
        let answered: Int
        let scribeReconnects: Int
        let active: Bool
        let mode: String
    }

    struct Answer: Codable {
        let minute: Double
        let firstTextMs: Double?
        let question: String
    }

    struct Report: Codable {
        let minutes: Double
        var samples: [Sample] = []
        var answers: [Answer] = []
        var stoppedAtMinute: Double?
        var reconnectLines: [String] = []
        var errorLines: [String] = []
    }

    @Test func provlägeRunsForAnHourWithoutGrowing() async throws {
        let minutes = try #require(LongRunEnvironment.minutes)
        let dir = try #require(ChainEnvironment.audioDir)
        let files = ["p1", "p2", "p3", "p4"].map { dir.appendingPathComponent("prov-\($0).wav").path }
        let lead = dir.appendingPathComponent("lead-silence.wav").path
        setenv("LUMEN_AUDIO_FILES", ([lead] + files).joined(separator: ":"), 1)
        setenv("LUMEN_AUDIO_LOOP", "1", 1)
        setenv("LUMEN_AUDIO_GAP", "20", 1) // one question about every 25 s: inside the backend's per-user limits
        UserDefaults.standard.set(false, forKey: VoiceSettings.speakKey)

        let container = AppContainer()
        _ = try #require(container.capture as? FileCaptureService, "the container did not take the files")
        let model = container.listening
        container.consent.grant()

        let start = Date()
        func minute(_ date: Date = Date()) -> Double { date.timeIntervalSince(start) / 60 }
        var report = Report(minutes: minutes)
        var heard = 0
        model.sessionObserver = { event, date in
            switch event {
            case .heard: heard += 1
            case .answered(let question, _, let ms, _):
                report.answers.append(Answer(minute: minute(date), firstTextMs: ms, question: question))
            default: break
            }
        }
        container.sessionController.logObserver = { entry in
            let line = String(format: "%6.2f ", minute(entry.time)) + entry.text
            let lower = entry.text.lowercased()
            if lower.contains("scribe"), lower.contains("reconnect") || lower.contains("ended") || lower.contains("renew") {
                report.reconnectLines.append(line)
            }
            if lower.contains("error") || lower.contains("failed") || lower.contains("429") {
                report.errorLines.append(line)
            }
        }

        let today = Calendar.current.startOfDay(for: Date())
        let plan = ExamPlan(grade: .y9, area: .no, subject: "Biologi",
                            date: Calendar.current.date(byAdding: .day, value: 5, to: today) ?? today,
                            topics: "fotosyntes, klorofyll, cellandning, mitokondrier")
        model.examPlans?.save(plan)
        await model.startProv(for: plan)

        let end = start.addingTimeInterval(minutes * 60)
        var nextSample = start
        while Date() < end {
            if Date() >= nextSample {
                report.samples.append(Sample(minute: minute(), memoryMB: Self.footprintMB(), heard: heard,
                                             answered: report.answers.count, scribeReconnects: report.reconnectLines.count,
                                             active: model.isActiveSession, mode: model.mode.rawValue))
                try write(report)
                nextSample = nextSample.addingTimeInterval(60)
            }
            if !model.isActiveSession || model.mode != .prov {
                report.stoppedAtMinute = minute()
                break
            }
            try await Task.sleep(for: .seconds(1))
        }
        report.samples.append(Sample(minute: minute(), memoryMB: Self.footprintMB(), heard: heard,
                                     answered: report.answers.count, scribeReconnects: report.reconnectLines.count,
                                     active: model.isActiveSession, mode: model.mode.rawValue))
        await model.endSession()
        try write(report)

        #expect(report.stoppedAtMinute == nil, "Provläge stopped or changed mode at minute \(report.stoppedAtMinute ?? -1)")
        // Expected: about 2.4 answers a minute. Fewer than half of that means the chain stalled somewhere.
        #expect(Double(report.answers.count) >= minutes * 1.2, "only \(report.answers.count) answers in \(minutes) min")
        let firstTen = report.samples.filter { $0.minute >= 1 && $0.minute <= 10 }.map(\.memoryMB)
        let lastTen = report.samples.filter { $0.minute >= minutes - 10 }.map(\.memoryMB)
        if let a = firstTen.max(), let b = lastTen.max(), minutes >= 30 {
            #expect(b - a < 150, "memory grew \(Int(b - a)) MB between the first and the last 10 minutes")
        }
        let early = report.answers.filter { $0.minute < 10 }.compactMap(\.firstTextMs)
        let late = report.answers.filter { $0.minute >= minutes - 10 }.compactMap(\.firstTextMs)
        if !early.isEmpty, !late.isEmpty, minutes >= 30 {
            let median: ([Double]) -> Double = { values in values.sorted()[values.count / 2] }
            #expect(median(late) < median(early) * 1.5 + 300,
                    "first-text median grew from \(Int(median(early))) ms to \(Int(median(late))) ms")
        }
    }

    private func write(_ report: Report) throws {
        let out = URL(fileURLWithPath: ProcessInfo.processInfo.environment["LUMEN_E2E_OUT"] ?? NSTemporaryDirectory())
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(report).write(to: out.appendingPathComponent("long.json"))
    }

    /// The app's physical footprint (what iOS counts against the process), in MB.
    static func footprintMB() -> Double {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? Double(info.phys_footprint) / 1_048_576 : -1
    }
}
