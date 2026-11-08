import Foundation
import Testing
@testable import Lumen

/// T1 (Toby): known speech through the app's real chain in the Simulator. The files take the microphone's place
/// (Angela's `FileCaptureService`, A1); everything after it is the app as built: gate and Silero VAD, Scribe live
/// through `/stt-token` with the mode's parameters and keyterms, utterance joining, QuestionGate or Provläge, `/answer`.
///
/// Checks: no crash, one utterance per spoken sentence (none split, none merged), the right questions asked and
/// answered, subject words heard right in Provläge. Everything that happened goes to `<LUMEN_E2E_OUT>/<set>.json`.
///
/// Live and paid (Scribe + `/answer`): runs only when `scripts/apptest/chain.sh` sets `LUMEN_E2E_DIR` (manual and
/// nightly, never on push). Answers are not spoken (no TTS cost; the recogniser gate while Lumen speaks is not tested).
/// Simulator only: never a verification on a device.
/// Outside the suite: a trait that names its own type is a circular reference for the macro.
enum ChainEnvironment {
    static var audioDir: URL? {
        ProcessInfo.processInfo.environment["LUMEN_E2E_DIR"].map { URL(fileURLWithPath: $0) }
    }
}

@MainActor
@Suite(.serialized, .enabled(if: ChainEnvironment.audioDir != nil, "set LUMEN_E2E_DIR (scripts/apptest/chain.sh)"))
struct AudioChainE2ETests {
    static var audioDir: URL? { ChainEnvironment.audioDir }

    struct Case: Codable {
        let set: String
        let id: String
        let kind: String
        let text: String
    }

    struct Event: Codable {
        let t: Double
        let kind: String
        let text: String
        var question: String?
        var trigger: String?
        var firstTextMs: Double?
    }

    struct Result: Codable {
        let set: String
        let mode: String
        let files: [String]
        let spoken: [String]
        var events: [Event] = []
        var heard = 0
        var asked = 0
        var answered = 0
        var keytermsHeard: [String: Bool] = [:]
        var englishAnswers = 0
        var log: [String] = []
        var crashedOrStopped = false
        var seconds = 0.0
    }

    @Test func frågorAnswersTheQuestionsOnly() async throws {
        let result = try await run(set: "fragor", mode: .standard, leadSilence: true)
        let cases = try Self.cases(for: "fragor")
        let questions = cases.filter { $0.kind == "question" }.count
        #expect(!result.crashedOrStopped, "the session stopped by itself")
        #expect(abs(result.heard - cases.count) <= 1, "utterances: heard \(result.heard), spoken \(cases.count)")
        // `asked` is not reported on the answer-ahead path (D80), so the answers are what counts.
        #expect(result.answered >= questions - 1 && result.answered <= questions,
                "answered \(result.answered), questions \(questions) (statements must not be answered)")
    }

    @Test func provlägeAnswersEveryTurnWithSubjectWordsRight() async throws {
        let result = try await run(set: "prov", mode: .prov, leadSilence: true)
        let cases = try Self.cases(for: "prov")
        #expect(!result.crashedOrStopped, "the session stopped by itself")
        #expect(abs(result.heard - cases.count) <= 1, "utterances: heard \(result.heard), spoken \(cases.count)")
        #expect(result.answered >= cases.count - 1, "answered \(result.answered) of \(cases.count) turns")
        for (term, heard) in result.keytermsHeard {
            #expect(heard, "subject word '\(term)' not heard right")
        }
        #expect(result.englishAnswers == 0, "\(result.englishAnswers) of \(result.answered) Provläge answers in English")
    }

    /// A question said the moment listening starts (no silence first): is it heard? (Run 42502966284: the first
    /// sentence was lost in both sets.)
    @Test func theFirstWordsRightAfterStartAreHeard() async throws {
        let result = try await run(set: "start", mode: .standard, leadSilence: false)
        #expect(result.heard == 1, "a question said at once after the start: heard \(result.heard)")
        #expect(result.answered == 1, "answered \(result.answered)")
    }

    // MARK: Running a set

    private func run(set: String, mode: ConversationMode, leadSilence: Bool) async throws -> Result {
        let dir = try #require(Self.audioDir)
        let cases = try Self.cases(for: set)
        // 4 s of silence first (chain.sh writes it): the recogniser connects before anyone speaks.
        let lead = leadSilence ? [dir.appendingPathComponent("lead-silence.wav").path] : []
        let files = lead + cases.map { dir.appendingPathComponent("\($0.set)-\($0.id).wav").path }
        for file in files { #expect(FileManager.default.fileExists(atPath: file), "missing \(file)") }

        // The container reads these when it builds its capture service (A1).
        setenv("LUMEN_AUDIO_FILES", files.joined(separator: ":"), 1)
        setenv("LUMEN_AUDIO_GAP", "5", 1) // > QuestionGate's 5 s minimum interval between questions
        unsetenv("LUMEN_AUDIO_LOOP")
        UserDefaults.standard.set(false, forKey: VoiceSettings.speakKey)

        let container = AppContainer()
        let capture = try #require(container.capture as? FileCaptureService, "the container did not take the files")
        let model = container.listening
        container.consent.grant()

        var result = Result(set: set, mode: mode.rawValue, files: files.map { ($0 as NSString).lastPathComponent },
                            spoken: cases.map(\.text))
        let start = Date()
        var events: [Event] = []
        model.sessionObserver = { event, date in
            let t = date.timeIntervalSince(start)
            switch event {
            case .heard(let text): events.append(Event(t: t, kind: "heard", text: text))
            case .asked(let query, let trigger): events.append(Event(t: t, kind: "asked", text: query, trigger: trigger))
            case .answered(let question, let answer, let ms, _):
                events.append(Event(t: t, kind: "answered", text: answer, question: question, firstTextMs: ms))
            case .spoke(let text): events.append(Event(t: t, kind: "spoke", text: text))
            }
        }
        var finished = false
        capture.onFinishedFiles = { finished = true }
        var logLines: [String] = []
        container.sessionController.logObserver = { entry in
            logLines.append(String(format: "%7.2f ", entry.time.timeIntervalSince(start)) + entry.text)
        }

        switch mode {
        case .prov:
            let today = Calendar.current.startOfDay(for: Date())
            let date = Calendar.current.date(byAdding: .day, value: 5, to: today) ?? today
            let plan = ExamPlan(grade: .y9, area: .no, subject: "Biologi", date: date,
                                topics: "fotosyntes, klorofyll, cellandning, mitokondrier")
            model.examPlans?.save(plan)
            await model.startProv(for: plan)
        default:
            await model.startMode(mode)
        }

        // Real time: wait for the files, then up to 25 s for the last answers.
        let deadline = Date().addingTimeInterval(Double(files.count) * 12 + 60)
        var quietSince: Date?
        while Date() < deadline {
            try await Task.sleep(for: .milliseconds(500))
            if !model.isActiveSession { result.crashedOrStopped = true; break }
            guard finished else { continue }
            if model.isAnswering { quietSince = nil; continue }
            quietSince = quietSince ?? Date()
            if let quiet = quietSince, Date().timeIntervalSince(quiet) > 25 { break }
        }
        result.seconds = Date().timeIntervalSince(start)
        await model.endSession()

        result.events = events
        result.heard = events.filter { $0.kind == "heard" }.count
        result.asked = events.filter { $0.kind == "asked" }.count
        result.answered = events.filter { $0.kind == "answered" }.count
        result.englishAnswers = events.filter { $0.kind == "answered" && Self.looksEnglish($0.text) }.count
        if mode == .prov {
            let heardText = events.filter { $0.kind == "heard" }.map(\.text).joined(separator: " ").lowercased()
            for term in ["klorofyll", "fotosyntes", "cellandning", "mitokondrierna"] {
                result.keytermsHeard[term] = heardText.contains(term)
            }
        }
        result.log = logLines
        try write(result)
        return result
    }

    private func write(_ result: Result) throws {
        let env = ProcessInfo.processInfo.environment
        let out = URL(fileURLWithPath: env["LUMEN_E2E_OUT"] ?? NSTemporaryDirectory())
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let url = out.appendingPathComponent("\(result.set).json")
        try encoder.encode(result).write(to: url)
        print("T1 result: \(url.path) heard \(result.heard) asked \(result.asked) answered \(result.answered)")
    }

    /// Common English words, none of them Swedish words: two or more = an English answer.
    static func looksEnglish(_ text: String) -> Bool {
        let words = Set(text.lowercased().split(whereSeparator: { !$0.isLetter }).map(String.init))
        return words.intersection(["the", "is", "and", "are", "which", "this", "of", "to", "when", "with"]).count >= 2
    }

    private static func cases(for set: String) throws -> [Case] {
        let dir = try #require(audioDir)
        // cases.tsv is copied next to the generated audio by scripts/apptest/chain.sh.
        let text = try String(contentsOf: dir.appendingPathComponent("cases.tsv"), encoding: .utf8)
        return text.split(whereSeparator: \.isNewline).dropFirst().compactMap { line in
            let parts = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard parts.count >= 4 else { return nil }
            return Case(set: parts[0], id: parts[1], kind: parts[2], text: parts[3])
        }.filter { $0.set == set }
    }
}
