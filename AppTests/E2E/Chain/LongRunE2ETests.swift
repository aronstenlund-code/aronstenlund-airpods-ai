import Darwin
import Foundation
import Testing
@testable import Lumen

/// T2 (Toby): Provläge for a long time on looped speech, in the Simulator. Every minute: the app's memory, answers
/// and their first-text times so far, Scribe reconnects, whether the session and the mode are still on.
/// T5 (after Angela's A11): every played file, whether it was heard, and whether the screen said "Lyssnar" meanwhile.
/// A deaf period runs from the first unheard file to the next heard one; none may be longer than 30 s, and the
/// recogniser may not be down for longer than 30 s while listening.
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
        // T5
        var plays: [Play] = []
        var heardSeconds: [Double] = []
        /// [from, to] in seconds: listening, but the recogniser not running (`isHearing` false: the screen does not say "Lyssnar").
        var notHearingSpans: [[Double]] = []
        /// [from, to] in seconds: from the first unheard file to the next heard one.
        var deafPeriods: [[Double]] = []
        var missedFiles = 0
        var missedWhileShowingListening = 0
        var longestDeafSeconds = 0.0
        var longestNotHearingSeconds = 0.0
        var hearingLines: [String] = []
    }

    /// One played speech file (the lead silence not counted).
    struct Play: Codable {
        let second: Double
        let file: Int
        var heard = false
        /// The screen said "Lyssnar" all through the file and the 8 s after it.
        var showedListening = true
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
        var heardSeconds: [Double] = []
        model.sessionObserver = { event, date in
            switch event {
            case .heard:
                heard += 1
                heardSeconds.append(date.timeIntervalSince(start))
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
            if lower.contains("not hearing") || lower.contains("recognition is back") || lower.contains("iphone's speech") {
                report.hearingLines.append(line)
            }
        }

        let today = Calendar.current.startOfDay(for: Date())
        let plan = ExamPlan(grade: .y9, area: .no, subject: "Biologi",
                            date: Calendar.current.date(byAdding: .day, value: 5, to: today) ?? today,
                            topics: "fotosyntes, klorofyll, cellandning, mitokondrier")
        model.examPlans?.save(plan)
        await model.startProv(for: plan)

        let capture = try #require(container.capture as? FileCaptureService)
        let durations = try ([lead] + files).map { Double(try FileCaptureService.decode(URL(fileURLWithPath: $0)).count) / LumenAudioFormat.sampleRate }
        var lastFile = -1
        var ticks: [(second: Double, showsListening: Bool)] = []
        var notHearingFrom: Double?

        let end = start.addingTimeInterval(minutes * 60)
        var nextSample = start
        while Date() < end {
            let now = Date().timeIntervalSince(start)
            let file = capture.currentFile
            if file != lastFile {
                lastFile = file
                if file > 0 { report.plays.append(Play(second: now, file: file)) }
            }
            // What the Listening screen shows (A11): "Lyssnar" only while the recogniser runs. Answers are not spoken.
            let showsListening = model.isListening && model.isHearing
            ticks.append((now, showsListening))
            if model.isListening, !model.isHearing {
                notHearingFrom = notHearingFrom ?? now
            } else if let from = notHearingFrom {
                report.notHearingSpans.append([from, now])
                notHearingFrom = nil
            }
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
            try await Task.sleep(for: .milliseconds(500))
        }
        if let from = notHearingFrom { report.notHearingSpans.append([from, Date().timeIntervalSince(start)]) }
        report.samples.append(Sample(minute: minute(), memoryMB: Self.footprintMB(), heard: heard,
                                     answered: report.answers.count, scribeReconnects: report.reconnectLines.count,
                                     active: model.isActiveSession, mode: model.mode.rawValue))
        await model.endSession()
        Self.judgeHearing(&report, heardSeconds: heardSeconds, ticks: ticks, durations: durations)
        try write(report)

        #expect(report.longestDeafSeconds <= 30,
                "deaf for \(Int(report.longestDeafSeconds)) s (\(report.missedFiles) of \(report.plays.count) files unheard)")
        #expect(report.longestNotHearingSeconds <= 30,
                "the recogniser was down for \(Int(report.longestNotHearingSeconds)) s while listening")
        let lying = report.deafPeriods.filter { period in
            period[1] - period[0] > 30 && report.plays.filter { $0.second >= period[0] && $0.second < period[1] }.allSatisfy(\.showedListening)
        }
        #expect(lying.isEmpty, "\(lying.count) deaf periods over 30 s while the screen said Lyssnar")
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

    /// T5: which files were heard, the deaf periods, and whether the screen said "Lyssnar" during them.
    private static func judgeHearing(_ report: inout Report, heardSeconds: [Double],
                                     ticks: [(second: Double, showsListening: Bool)], durations: [Double]) {
        report.heardSeconds = heardSeconds
        for index in report.plays.indices {
            let play = report.plays[index]
            let until = play.second + (durations.indices.contains(play.file) ? durations[play.file] : 5) + 8
            report.plays[index].heard = heardSeconds.contains { $0 >= play.second && $0 <= until }
            report.plays[index].showedListening = ticks.filter { $0.second >= play.second && $0.second <= until }
                .allSatisfy(\.showsListening)
        }
        report.missedFiles = report.plays.filter { !$0.heard }.count
        report.missedWhileShowingListening = report.plays.filter { !$0.heard && $0.showedListening }.count
        var from: Double?
        for play in report.plays {
            if !play.heard {
                from = from ?? play.second
            } else if let start = from {
                report.deafPeriods.append([start, play.second])
                from = nil
            }
        }
        if let start = from { report.deafPeriods.append([start, ticks.last?.second ?? start]) }
        report.longestDeafSeconds = report.deafPeriods.map { $0[1] - $0[0] }.max() ?? 0
        report.longestNotHearingSeconds = report.notHearingSpans.map { $0[1] - $0[0] }.max() ?? 0
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
