import Foundation
import Testing
@testable import Lumen

/// T5 (Toby): the retest after Angela's A8 (Frågor answers, continuations, several questions in one breath, Scribe
/// keyterms up to 20 characters) through the app's real chain in the Simulator: `FileCaptureService` → VAD → Scribe
/// live → QuestionGate / Provläge → `/answer` → the speaker.
///
/// 1. **Frågor:** 10 ordinary questions, 3 of them with a continuation after a pause of 1.5, 2.5 and 3.5 s (one file:
///    first half, silence, second half). Every question gets an answer that is read aloud (Apple's voice, no
///    ElevenLabs cost); a continuation is asked whole. Counted: asked, answered, spoken.
/// 2. **Provläge, one breath:** three questions and a standing wish in one file, with sentence pauses (b1) and run
///    together (b2). Each should be its own turn: 4 asked.
/// 3. **Provläge, long keyterm:** an exam whose topics are longer than 20 characters. Scribe must hold (no
///    `invalid_request`, no fallback to the iPhone's recogniser), the longest term sent ≤ 20 characters, and the
///    questions answered.
///
/// The long run (part 4 of T5) is `LongRunE2ETests`. Output: `<LUMEN_E2E_OUT>/retest-<set>.json`.
/// Live and paid (Scribe, /answer): only when `scripts/apptest/retest.sh` sets `LUMEN_E2E_RETEST_DIR`.
/// Simulator only: never a verification on a device. Runs: T5 2026-11-09, T5b 2026-11-11 (after A21).
enum RetestEnvironment {
    static var audioDir: URL? {
        ProcessInfo.processInfo.environment["LUMEN_E2E_RETEST_DIR"].map { URL(fileURLWithPath: $0) }
    }

    /// D120 (no wasted ElevenLabs credits): `LUMEN_E2E_RETEST_SETS` ("fragor,block") runs only those sets, since
    /// Scribe is open for the whole set. Empty or unset: all three.
    static func includes(_ set: String) -> Bool {
        let sets = (ProcessInfo.processInfo.environment["LUMEN_E2E_RETEST_SETS"] ?? "")
            .split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        return sets.isEmpty || sets.contains(set)
    }
}

@MainActor
@Suite(.serialized, .enabled(if: RetestEnvironment.audioDir != nil, "set LUMEN_E2E_RETEST_DIR (scripts/apptest/retest.sh)"))
struct RetestE2ETests {
    struct Case: Codable {
        let set: String
        let id: String
        let kind: String
        let pause: Double
        let key: String
        let text: String
    }

    struct Event: Codable {
        let t: Double
        let kind: String
        let text: String
    }

    struct CaseResult: Codable {
        let id: String
        let kind: String
        let text: String
        let key: String
        var heard: [String] = []
        var asked: [String] = []
        var answered: [String] = []
        var spoken = 0
        var verdict = ""
    }

    struct SetResult: Codable {
        let set: String
        let mode: String
        let topics: String?
        var cases: [CaseResult] = []
        var log: [String] = []
        var keytermLines: [String] = []
        var refusedOrFellBack: [String] = []
        var longestKeyterm: Int?
        var stoppedEarly: String?
        /// When the session ended: still answering or speaking means the end was the deadline, not a quiet room.
        var endState = ""
        var seconds = 0.0
    }

    static let ordinaryTopics = "fotosyntes, klorofyll, cellandning, mitokondrier"
    static let longTopics = "fotosyntesens ljusberoende reaktioner, Calvincykeln i kloroplasterna, "
        + "mitokondriernas elektrontransportkedja"

    @Test(.enabled(if: RetestEnvironment.includes("fragor"))) func frågorAnswersAndSpeaksEveryQuestion() async throws {
        let result = try await run(set: "fragor", mode: .standard, speak: true, topics: nil, gap: 14)
        let answered = result.cases.filter { !$0.answered.isEmpty }.count
        let spoken = result.cases.filter { $0.spoken > 0 }.count
        #expect(result.stoppedEarly == nil, "stopped early: \(result.stoppedEarly ?? "")")
        #expect(answered == result.cases.count, "answered \(answered) of \(result.cases.count) questions")
        #expect(spoken == result.cases.count, "spoke \(spoken) of \(result.cases.count) answers")
        for item in result.cases where !item.verdict.hasPrefix("ok") {
            Issue.record("\(item.id) '\(item.text)': \(item.verdict) (heard \(item.heard), asked \(item.asked))")
        }
    }

    @Test(.enabled(if: RetestEnvironment.includes("block"))) func provlägeMakesFourTurnsOfOneBreath() async throws {
        // 4 turns one at a time take a while: a long gap keeps them in the block's own window.
        let result = try await run(set: "block", mode: .prov, speak: false, topics: Self.ordinaryTopics, gap: 35)
        #expect(result.stoppedEarly == nil, "stopped early: \(result.stoppedEarly ?? "")")
        for item in result.cases {
            #expect(Self.turns(item) == 4, "\(item.id): \(Self.turns(item)) turns, expected 4: asked \(item.asked), answered \(item.answered)")
        }
    }

    @Test(.enabled(if: RetestEnvironment.includes("keyterm"))) func scribeHoldsAnExamWithLongTopics() async throws {
        let result = try await run(set: "keyterm", mode: .prov, speak: false, topics: Self.longTopics, gap: 14)
        #expect(result.stoppedEarly == nil, "stopped early: \(result.stoppedEarly ?? "")")
        #expect(result.refusedOrFellBack.isEmpty, "Scribe: \(result.refusedOrFellBack)")
        #expect((result.longestKeyterm ?? 0) <= 20, "longest keyterm sent: \(result.longestKeyterm ?? -1) characters")
        #expect(result.longestKeyterm != nil, "no 'Scribe keyterms' line: were the exam's terms sent?")
        let answered = result.cases.filter { !$0.answered.isEmpty }.count
        #expect(answered >= result.cases.count - 1, "answered \(answered) of \(result.cases.count)")
    }

    // MARK: One set in one session

    /// A turn shows as `asked`, or only as `answered` on a path that does not report `asked`.
    static func turns(_ item: CaseResult) -> Int { max(item.asked.count, item.answered.count) }

    private func run(set: String, mode: ConversationMode, speak: Bool, topics: String?, gap: Double) async throws -> SetResult {
        let dir = try #require(RetestEnvironment.audioDir)
        let cases = try Self.cases(in: dir).filter { $0.set == set }
        // The gap after each file is long enough for a spoken answer: a real user waits for it.
        let lead = dir.appendingPathComponent("lead-silence.wav")
        let files = [lead] + cases.map { dir.appendingPathComponent("\($0.set)-\($0.id).wav") }
        for file in files { #expect(FileManager.default.fileExists(atPath: file.path), "missing \(file.path)") }
        let audioSeconds = try files.reduce(0.0) { $0 + Double(try FileCaptureService.decode($1).count) / LumenAudioFormat.sampleRate + gap }

        setenv("LUMEN_AUDIO_FILES", files.map(\.path).joined(separator: ":"), 1)
        setenv("LUMEN_AUDIO_GAP", String(gap), 1)
        unsetenv("LUMEN_AUDIO_LOOP")
        let defaults = UserDefaults.standard
        defaults.set(speak, forKey: VoiceSettings.speakKey)
        // Apple's voice: no /tts cost. A stored choice is kept by `reconcile` (D32).
        defaults.set(try JSONEncoder().encode(VoiceChoice.appleDefault), forKey: VoiceSettings.voiceKey)

        let container = AppContainer()
        let capture = try #require(container.capture as? FileCaptureService, "the container did not take the files")
        let model = container.listening
        container.consent.grant()

        let start = Date()
        var events: [Event] = []
        var log: [Event] = []
        model.sessionObserver = { event, date in
            let t = date.timeIntervalSince(start)
            switch event {
            case .heard(let text): events.append(Event(t: t, kind: "heard", text: text))
            case .asked(let query, _): events.append(Event(t: t, kind: "asked", text: query))
            case .answered(let question, _, _, _): events.append(Event(t: t, kind: "answered", text: question))
            case .spoke(let text): events.append(Event(t: t, kind: "spoke", text: text))
            }
        }
        container.sessionController.logObserver = { entry in
            log.append(Event(t: entry.time.timeIntervalSince(start), kind: "log", text: entry.text))
        }
        var finished = false
        capture.onFinishedFiles = { finished = true }

        var result = SetResult(set: set, mode: mode.rawValue, topics: topics)
        if let topics {
            let today = Calendar.current.startOfDay(for: Date())
            let plan = ExamPlan(grade: .y9, area: .no, subject: "Biologi",
                                date: Calendar.current.date(byAdding: .day, value: 5, to: today) ?? today, topics: topics)
            model.examPlans?.save(plan)
            await model.startProv(for: plan)
        } else {
            await model.startMode(mode)
        }

        var fileStart: [Int: Double] = [:]
        let deadline = start.addingTimeInterval(audioSeconds * 1.3 + 60)
        var quietSince: Date?
        while Date() < deadline {
            try await Task.sleep(for: .milliseconds(100))
            let current = capture.currentFile
            if fileStart[current] == nil, current >= (fileStart.keys.max() ?? -1) {
                fileStart[current] = Date().timeIntervalSince(start)
            }
            if !model.isActiveSession {
                result.stoppedEarly = "at file \(current) of \(files.count - 1), t=\(Int(Date().timeIntervalSince(start))) s"
                break
            }
            guard finished else { continue }
            if model.isAnswering || model.speaker.isSpeaking { quietSince = nil; continue }
            quietSince = quietSince ?? Date()
            if let quiet = quietSince, Date().timeIntervalSince(quiet) > 15 { break }
        }
        let end = Date().timeIntervalSince(start)
        result.seconds = end
        result.endState = "answering=\(model.isAnswering) speaking=\(model.speaker.isSpeaking) listening=\(model.isListening)"
        if model.isActiveSession { await model.endSession() }
        model.sessionObserver = nil
        container.sessionController.logObserver = nil

        for (number, item) in cases.enumerated() {
            let from = fileStart[number + 1] ?? .infinity
            let to = fileStart[number + 2] ?? end + 1
            let inside = events.filter { $0.t >= from && $0.t < to }
            var one = CaseResult(id: item.id, kind: item.kind, text: item.text, key: item.key)
            one.heard = inside.filter { $0.kind == "heard" }.map(\.text)
            one.asked = inside.filter { $0.kind == "asked" }.map(\.text)
            one.answered = inside.filter { $0.kind == "answered" }.map(\.text)
            one.spoken = inside.filter { $0.kind == "spoke" }.count
            one.verdict = Self.judge(one, speak: speak)
            result.cases.append(one)
        }
        result.log = (log + events).sorted { $0.t < $1.t }.map { String(format: "%7.2f ", $0.t) + "\($0.kind) " + $0.text }
        result.keytermLines = log.map(\.text).filter { $0.hasPrefix("Scribe keyterms") }
        result.refusedOrFellBack = log.map(\.text).filter {
            $0.contains("Scribe refused the session") || $0.contains("using the iPhone's speech recognition")
        }
        result.longestKeyterm = result.keytermLines.compactMap(Self.longest).max()
        try write(result)
        return result
    }

    /// "Scribe keyterms: 9, longest 20 characters (…)" → 20.
    static func longest(in line: String) -> Int? {
        guard let range = line.range(of: "longest ") else { return nil }
        return Int(line[range.upperBound...].prefix { $0.isNumber })
    }

    private static func judge(_ item: CaseResult, speak: Bool) -> String {
        let asked = item.asked.map { $0.lowercased() }
        switch item.kind {
        case "block":
            return turns(item) == 4 ? "ok (4 turns)" : "\(turns(item)) turns"
        case "continuation":
            if item.answered.isEmpty { return item.asked.isEmpty ? "not asked" : "asked, no answer" }
            guard let last = asked.last, last.contains(item.key) else { return "asked without the continuation" }
            // A first half the backend calls "not a question" gets no answer; the whole question is asked after it.
            if item.answered.count > 1 { return "split: \(item.answered.count) answers" }
            return speak && item.spoken == 0 ? "answered, not spoken" : "ok (asked whole)"
        default:
            if item.answered.isEmpty { return item.asked.isEmpty ? (item.heard.isEmpty ? "not heard" : "not asked") : "asked, no answer" }
            return speak && item.spoken == 0 ? "answered, not spoken" : "ok"
        }
    }

    private func write(_ result: SetResult) throws {
        let out = URL(fileURLWithPath: ProcessInfo.processInfo.environment["LUMEN_E2E_OUT"] ?? NSTemporaryDirectory())
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let url = out.appendingPathComponent("retest-\(result.set).json")
        try encoder.encode(result).write(to: url)
        let ok = result.cases.filter { $0.verdict.hasPrefix("ok") }.count
        print("T5 result: \(url.path) \(ok)/\(result.cases.count) ok")
    }

    private static func cases(in dir: URL) throws -> [Case] {
        // retest.tsv is copied next to the generated audio by scripts/apptest/retest.sh.
        let text = try String(contentsOf: dir.appendingPathComponent("retest.tsv"), encoding: .utf8)
        return text.split(whereSeparator: \.isNewline).dropFirst().compactMap { line in
            let parts = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard parts.count >= 6 else { return nil }
            return Case(set: parts[0], id: parts[1], kind: parts[2], pause: Double(parts[3]) ?? 0, key: parts[4].lowercased(),
                        text: parts[5])
        }
    }
}
