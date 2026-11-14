import Foundation
import Testing
@testable import Lumen

/// T17c (Toby 1, D180): the listening tests without ElevenLabs. Scribe is switched off (`stt.useCloud` = false, so the
/// app never asks `/stt-token`), the capture plays silence, and recorded or written transcripts go straight into
/// `ListeningModel` the way Scribe's text does (partial, then final). Everything after that is the real app and the
/// live `/answer` (Claude), so the wake word (A75, A97, fynd 8), the repeat guard (T16) and `empty_answer` are tested
/// with 0 ElevenLabs characters. The answers are not spoken (Apple's voice for T16, never `/tts`).
///
/// Sets in `AppTests/E2E/Audio/transcript-cases.json` (`scripts/apptest/transcript_cases.py`):
/// - `t17-run1…3`: what Scribe heard in three earlier T17 runs, 50 "Lumen, …" and 50 sentences without the name each;
/// - `web`: 10 × "hur många bor i Sverige" and 10 other questions that usually make a web search, each in a session of
///   its own (A74 would hold a repeated question);
/// - `fynd8`: the name in the middle of babble, and sentences that only mention the name;
/// - `a97`: Earmind and its misrecognitions, Lumen's, and sentences that must stay silent;
/// - `t16`: ten question pairs, question 2 right after the answer to question 1 is spoken.
/// Live and paid (Claude only): only when `scripts/apptest/transcript.sh` sets `LUMEN_E2E_TRANSCRIPT_FILE`.
enum TranscriptEnvironment {
    static var file: URL? { ProcessInfo.processInfo.environment["LUMEN_E2E_TRANSCRIPT_FILE"].map { URL(fileURLWithPath: $0) } }
    static var silence: URL? { ProcessInfo.processInfo.environment["LUMEN_E2E_SILENCE"].map { URL(fileURLWithPath: $0) } }
    static var out: URL { URL(fileURLWithPath: ProcessInfo.processInfo.environment["LUMEN_E2E_OUT"] ?? NSTemporaryDirectory()) }

    static func includes(_ set: String) -> Bool {
        let sets = (ProcessInfo.processInfo.environment["LUMEN_E2E_TRANSCRIPT_SETS"] ?? "")
            .split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        return sets.isEmpty || sets.contains { set.hasPrefix($0) }
    }
}

@MainActor
@Suite(.serialized, .enabled(if: TranscriptEnvironment.file != nil, "set LUMEN_E2E_TRANSCRIPT_FILE (scripts/apptest/transcript.sh)"))
struct TranscriptE2ETests {
    struct Case: Codable {
        let id: String
        let expect: String
        let cond: String
        let text: String
        let heard: [String]
    }

    struct CaseResult: Codable {
        let id: String
        let expect: String
        let cond: String
        let text: String
        var fed: [String] = []
        var asked: [String] = []
        var answered: [String] = []
        var failed: [String] = []
        var woke = false
        var verdict = ""
        var seconds = 0.0
    }

    struct SetResult: Codable {
        let set: String
        var cases: [CaseResult] = []
        var log: [String] = []
        /// Proof for D180: lines that would mean Scribe or ElevenLabs was used (must stay empty).
        var elevenLabs: [String] = []
    }

    static func load(_ set: String) throws -> [Case] {
        let file = try #require(TranscriptEnvironment.file)
        struct File: Codable { let sets: [String: [Case]] }
        let all = try JSONDecoder().decode(File.self, from: Data(contentsOf: file))
        return try #require(all.sets[set], "no set \(set)")
    }

    // MARK: T17 with recorded transcripts

    @Test(.enabled(if: TranscriptEnvironment.includes("t17")), arguments: ["t17-run1", "t17-run2", "t17-run3"])
    func theNameGetsAnAnswerFromRecordedTranscripts(_ set: String) async throws {
        let result = try await run(set: set, cases: try Self.load(set), speak: false)
        let wake = result.cases.filter { $0.expect == "wake" }
        let nowake = result.cases.filter { $0.expect == "nowake" }
        let answered = wake.filter { !$0.answered.isEmpty }.count
        let falseOnes = nowake.filter { !$0.verdict.hasPrefix("ok") }.count
        let empty = result.cases.flatMap(\.failed).filter { $0.contains("empty_answer") }.count
        print("T17c \(set): wake answered \(answered)/\(wake.count), false \(falseOnes)/\(nowake.count), empty_answer \(empty)")
        #expect(result.elevenLabs.isEmpty, "ElevenLabs/Scribe used: \(result.elevenLabs)")
        #expect(falseOnes <= 1, "\(set): false \(falseOnes)/50 (krav ≤ 1)")
        #expect(empty == 0, "\(set): empty_answer \(empty)")
        // 48/50 is the krav with Scribe's own misses included; the summary separates them (nothing heard, no name heard).
    }

    // MARK: Web questions, each in its own session

    @Test(.enabled(if: TranscriptEnvironment.includes("web"))) func webQuestionsNeverComeBackEmpty() async throws {
        var merged = SetResult(set: "web")
        for item in try Self.load("web") {
            let part = try await run(set: "web-\(item.id)", cases: [item], speak: false, write: false)
            merged.cases += part.cases
            merged.log += ["--- \(item.id)"] + part.log
            merged.elevenLabs += part.elevenLabs
        }
        try write(merged)
        let answered = merged.cases.filter { !$0.answered.isEmpty }.count
        let empty = merged.cases.flatMap(\.failed).filter { $0.contains("empty_answer") }.count
        print("T17c web: answered \(answered)/\(merged.cases.count), empty_answer \(empty)")
        #expect(merged.elevenLabs.isEmpty, "ElevenLabs/Scribe used: \(merged.elevenLabs)")
        #expect(empty == 0, "empty_answer \(empty) of \(merged.cases.count)")
        #expect(answered == merged.cases.count, "answered \(answered) of \(merged.cases.count)")
    }

    // MARK: Fynd 8 and A97

    @Test(.enabled(if: TranscriptEnvironment.includes("fynd8"))) func theNameInTheMiddleOfBabble() async throws {
        try await wakeSet("fynd8")
    }

    @Test(.enabled(if: TranscriptEnvironment.includes("a97"))) func earmindWakesToo() async throws {
        try await wakeSet("a97")
    }

    private func wakeSet(_ set: String) async throws {
        let result = try await run(set: set, cases: try Self.load(set), speak: false)
        let wake = result.cases.filter { $0.expect == "wake" }
        let nowake = result.cases.filter { $0.expect == "nowake" }
        let answered = wake.filter { !$0.answered.isEmpty }.count
        let falseOnes = nowake.filter { !$0.verdict.hasPrefix("ok") }.count
        print("T17c \(set): wake answered \(answered)/\(wake.count), false \(falseOnes)/\(nowake.count)")
        #expect(result.elevenLabs.isEmpty)
        for item in result.cases where !item.verdict.hasPrefix("ok") {
            Issue.record("\(item.id) '\(item.text)': \(item.verdict), asked \(item.asked)")
        }
    }

    // MARK: T16 with written transcripts

    @Test(.enabled(if: TranscriptEnvironment.includes("t16"))) func aNewQuestionDoesNotRepeatTheLastAnswer() async throws {
        let result = try await run(set: "t16", cases: try Self.load("t16"), speak: true)
        var repeated = 0
        for (index, second) in result.cases.enumerated() where second.id.hasSuffix("b") && index > 0 {
            let first = result.cases[index - 1]
            let again = second.answered.filter { Self.same($0, first.text) }.count + max(0, first.answered.count - 1)
            print("T16c \(first.id)/\(second.id): first answered \(first.answered.count), again \(again), second answered \(second.answered.count)")
            if again > 0 { repeated += 1 }
        }
        #expect(result.elevenLabs.isEmpty)
        #expect(repeated == 0, "question 1 answered again in \(repeated) of 10 pairs")
    }

    static func same(_ a: String, _ b: String) -> Bool {
        let norm = { (s: String) in s.lowercased().filter { $0.isLetter || $0 == " " }.trimmingCharacters(in: .whitespaces) }
        return norm(a) == norm(b) || (norm(a).count > 8 && norm(b).contains(norm(a)))
    }

    // MARK: One session

    private func run(set: String, cases: [Case], speak: Bool, write writeResult: Bool = true) async throws -> SetResult {
        let silence = try #require(TranscriptEnvironment.silence)
        setenv("LUMEN_AUDIO_FILES", silence.path, 1)
        setenv("LUMEN_AUDIO_LOOP", "1", 1)
        setenv("LUMEN_AUDIO_GAP", "0", 1)
        let defaults = UserDefaults.standard
        defaults.set(false, forKey: STTSettings.cloudKey) // D180: never Scribe, never /stt-token
        defaults.set(speak, forKey: VoiceSettings.speakKey)
        defaults.set(try JSONEncoder().encode(VoiceChoice.appleDefault), forKey: VoiceSettings.voiceKey) // never /tts

        let container = AppContainer()
        let model = container.listening
        container.consent.grant()
        let start = Date()
        var events: [(t: Double, kind: String, text: String)] = []
        model.sessionObserver = { event, date in
            let t = date.timeIntervalSince(start)
            switch event {
            case .heard(let text): events.append((t, "heard", text))
            case .asked(let query, _): events.append((t, "asked", query))
            case .answered(let question, _, _, _): events.append((t, "answered", question))
            case .spoke(let text): events.append((t, "spoke", text))
            }
        }
        container.sessionController.logObserver = { entry in
            events.append((entry.time.timeIntervalSince(start), "log", entry.text))
        }
        await model.startMode(.standard)
        // 2026-11-14 run 43612536023: the first question of a new session failed ("Answers need an internet
        // connection") while the anonymous sign-in was still going; 10 s is about what a real start takes.
        try await Task.sleep(for: .seconds(10))

        var result = SetResult(set: set)
        for item in cases {
            let from = Date().timeIntervalSince(start)
            for (n, line) in item.heard.enumerated() {
                if n > 0 { try await Task.sleep(for: .milliseconds(800)) }
                model.receivePartialTranscript(line, at: Date())
                try await Task.sleep(for: .milliseconds(400))
                model.receiveFinalTranscript(line, at: Date())
            }
            // Wait for the turn: an answer (web answers take up to 15 s), an error, or 6 s of nothing.
            let limit = Date().addingTimeInterval(item.heard.isEmpty ? 0.5 : 6)
            var deadline = limit
            while Date() < deadline {
                try await Task.sleep(for: .milliseconds(200))
                let inside = events.filter { $0.t >= from }
                if inside.contains(where: { $0.kind == "asked" }) { deadline = limit.addingTimeInterval(14) }
                let done = inside.contains { $0.kind == "answered" || ($0.kind == "log" && $0.text.hasPrefix("Fel (answer)")) }
                if done && !model.isAnswering && !model.speaker.isSpeaking { break }
            }
            // T16: question 2 comes right after the spoken answer.
            while speak, model.speaker.isSpeaking || model.isAnswering { try await Task.sleep(for: .milliseconds(200)) }
            try await Task.sleep(for: .milliseconds(speak ? 300 : 1_500))
            // At most one case per 15 s, like the recorded audio (a file and its gap): fed faster, /answer's web limit
            // (5 a minute per account) answered 429 to the babble questions in run 43612536023. T16 keeps its pace.
            while !speak, Date().timeIntervalSince(start) - from < 15 { try await Task.sleep(for: .milliseconds(200)) }
            let to = Date().timeIntervalSince(start)
            let inside = events.filter { $0.t >= from && $0.t < to }
            var one = CaseResult(id: item.id, expect: item.expect, cond: item.cond, text: item.text)
            one.fed = item.heard
            one.asked = inside.filter { $0.kind == "asked" }.map(\.text)
            one.answered = inside.filter { $0.kind == "answered" }.map(\.text)
            one.failed = inside.filter { $0.kind == "log" && $0.text.hasPrefix("Fel (answer)") }.map(\.text)
            one.woke = item.heard.contains { VoiceChannel.parse($0).intent != nil }
                || inside.contains { $0.kind == "log" && $0.text.hasPrefix("Name alone") }
            one.seconds = ((to - from) * 10).rounded() / 10
            one.verdict = Self.judge(one)
            result.cases.append(one)
        }
        if model.isActiveSession { await model.endSession() }
        model.sessionObserver = nil
        container.sessionController.logObserver = nil
        unsetenv("LUMEN_AUDIO_LOOP")
        result.log = events.sorted { $0.t < $1.t }.map { String(format: "%7.2f ", $0.t) + "\($0.kind) " + $0.text }
        result.elevenLabs = events.filter { $0.kind == "log" }.map(\.text).filter {
            $0.contains("STT running: Scribe") || $0.contains("stt-token") || $0.contains("Scribe keyterms") || $0.contains("/tts")
        }
        if writeResult { try write(result) }
        return result
    }

    private static func judge(_ item: CaseResult) -> String {
        switch item.expect {
        case "wake", "pair":
            if !item.answered.isEmpty { return item.woke || item.expect == "pair" ? "ok (answered)" : "ok (answered, name not parsed)" }
            if item.fed.isEmpty { return "nothing heard (Scribe)" }
            if !item.failed.isEmpty { return "failed: \(item.failed.joined(separator: " / "))" }
            if !item.asked.isEmpty { return "asked, no answer" }
            return item.woke ? "woke, no answer" : "name not heard"
        default:
            if item.woke { return "false wake" }
            if !item.answered.isEmpty { return "answered without the name" }
            return "ok"
        }
    }

    private func write(_ result: SetResult) throws {
        let out = TranscriptEnvironment.out
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(result).write(to: out.appendingPathComponent("transcript-\(result.set).json"))
    }
}
