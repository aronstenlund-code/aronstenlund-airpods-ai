import Foundation
import Testing
@testable import Lumen

/// T17 (Toby): the wake word "Lumen" (A75) through the app's real chain in the Simulator: `FileCaptureService` → VAD →
/// Scribe live → `ListeningModel` → `/answer`.
///
/// `AppTests/E2E/Audio/wake.tsv`: 50 "Lumen, <request>" and 50 ordinary sentences without the name (16 with real
/// words close to it: lumpen, luren, limmet …), three `say` voices, five speeds, three rooms (quiet, about 1 m,
/// babble at 5 dB SNR; `scripts/apptest/wake_audio.py`). Frågor, answers not spoken (no voice cost, shorter gaps).
///
/// Per file:
/// - **woke:** the app's own `VoiceChannel.parse` finds an addressed name in what Scribe heard (the same call
///   `ListeningModel.handleVoice` makes), or the A75 line "Name alone" is logged.
/// - **answered:** an `answered` event while the file plays or in its gap.
/// Krav after A75: wake 48/50 answered, nowake at most 1/50 woke or answered. The baseline runs the same test on the
/// app code before A75 (`WAKE_APP_REF`, see `scripts/apptest/wake.sh`).
///
/// Live and paid (Scribe, /answer): only when `scripts/apptest/wake.sh` sets `LUMEN_E2E_WAKE_DIR`. Simulator only:
/// synthetic rooms, never a verification on a device.
enum WakeEnvironment {
    static var audioDir: URL? {
        ProcessInfo.processInfo.environment["LUMEN_E2E_WAKE_DIR"].map { URL(fileURLWithPath: $0) }
    }

    static func includes(_ set: String) -> Bool {
        let sets = (ProcessInfo.processInfo.environment["LUMEN_E2E_WAKE_SETS"] ?? "")
            .split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        return sets.isEmpty || sets.contains(set)
    }
}

@MainActor
@Suite(.serialized, .enabled(if: WakeEnvironment.audioDir != nil, "set LUMEN_E2E_WAKE_DIR (scripts/apptest/wake.sh)"))
struct WakeE2ETests {
    struct Case {
        let id: String
        let expect: String
        let voice: String
        let rate: String
        let cond: String
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
        let expect: String
        let cond: String
        let rate: String
        let voice: String
        let text: String
        var heard: [String] = []
        var asked: [String] = []
        var answered: [String] = []
        var woke = false
        var verdict = ""
    }

    struct SetResult: Codable {
        let set: String
        var cases: [CaseResult] = []
        var log: [String] = []
        var stoppedEarly: String?
        var seconds = 0.0
    }

    @Test(.enabled(if: WakeEnvironment.includes("wake"))) func theNameAlwaysGetsAnAnswer() async throws {
        let result = try await run(set: "wake")
        let answered = result.cases.filter { !$0.answered.isEmpty }.count
        #expect(result.stoppedEarly == nil, "stopped early: \(result.stoppedEarly ?? "")")
        #expect(answered >= 48, "answered \(answered) of \(result.cases.count) (krav 48/50)")
        for item in result.cases where !item.verdict.hasPrefix("ok") {
            Issue.record("\(item.id) [\(item.cond), \(item.rate)] '\(item.text)': \(item.verdict) (heard \(item.heard))")
        }
    }

    @Test(.enabled(if: WakeEnvironment.includes("nowake"))) func noNameNeverWakes() async throws {
        let result = try await run(set: "nowake")
        let falseWakes = result.cases.filter { !$0.verdict.hasPrefix("ok") }.count
        #expect(result.stoppedEarly == nil, "stopped early: \(result.stoppedEarly ?? "")")
        #expect(falseWakes <= 1, "false wakes \(falseWakes) of \(result.cases.count) (krav högst 1/50)")
        for item in result.cases where !item.verdict.hasPrefix("ok") {
            Issue.record("\(item.id) [\(item.cond), \(item.rate)] '\(item.text)': \(item.verdict) (heard \(item.heard))")
        }
    }

    // MARK: One set, one session per room

    /// Each room is its own session (2026-11-13, first run 43489814229): A10's `WearerFocus` learns the wearer's level
    /// from the session's own speech and mutes speech 9 dB below it. In one shared session the 1 m files (-14 dB) came
    /// right after 20 quiet-room files and were muted as "someone else" (9 of 15 not heard, before and after A75).
    /// The 1 m room means the user talking from 1 m, so it starts its own session, like a real user would.
    private func run(set: String) async throws -> SetResult {
        let dir = try #require(WakeEnvironment.audioDir)
        let all = try Self.cases(in: dir).filter { $0.expect == set }
        var rooms: [String] = []
        for item in all where !rooms.contains(item.cond) { rooms.append(item.cond) }
        var result = SetResult(set: set)
        for room in rooms {
            let part = try await runSession(set: set, cases: all.filter { $0.cond == room })
            result.cases += part.cases
            result.log += ["--- room \(room): \(part.cases.count) files, \(Int(part.seconds)) s"] + part.log
            result.seconds += part.seconds
            if let stopped = part.stoppedEarly {
                result.stoppedEarly = (result.stoppedEarly.map { $0 + "; " } ?? "") + "\(room): \(stopped)"
            }
        }
        try write(result)
        return result
    }

    private func runSession(set: String, cases: [Case]) async throws -> SetResult {
        let dir = try #require(WakeEnvironment.audioDir)
        let gap = 12.0
        let lead = dir.appendingPathComponent("lead-silence.wav")
        let files = [lead] + cases.map { dir.appendingPathComponent("\($0.id).wav") }
        for file in files { #expect(FileManager.default.fileExists(atPath: file.path), "missing \(file.path)") }
        let audioSeconds = try files.reduce(0.0) { $0 + Double(try FileCaptureService.decode($1).count) / LumenAudioFormat.sampleRate + gap }

        setenv("LUMEN_AUDIO_FILES", files.map(\.path).joined(separator: ":"), 1)
        setenv("LUMEN_AUDIO_GAP", String(gap), 1)
        unsetenv("LUMEN_AUDIO_LOOP")
        let defaults = UserDefaults.standard
        defaults.set(false, forKey: VoiceSettings.speakKey)
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

        var result = SetResult(set: set)
        await model.startMode(.standard)

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
            if model.isAnswering { quietSince = nil; continue }
            quietSince = quietSince ?? Date()
            if let quiet = quietSince, Date().timeIntervalSince(quiet) > 10 { break }
        }
        let end = Date().timeIntervalSince(start)
        result.seconds = end
        if model.isActiveSession { await model.endSession() }
        model.sessionObserver = nil
        container.sessionController.logObserver = nil

        for (number, item) in cases.enumerated() {
            let from = fileStart[number + 1] ?? .infinity
            let to = fileStart[number + 2] ?? end + 1
            let inside = events.filter { $0.t >= from && $0.t < to }
            let logInside = log.filter { $0.t >= from && $0.t < to }
            var one = CaseResult(id: item.id, expect: item.expect, cond: item.cond, rate: item.rate, voice: item.voice, text: item.text)
            one.heard = inside.filter { $0.kind == "heard" }.map(\.text)
            one.asked = inside.filter { $0.kind == "asked" }.map(\.text)
            one.answered = inside.filter { $0.kind == "answered" }.map(\.text)
            one.woke = one.heard.contains { VoiceChannel.parse($0).intent != nil }
                || logInside.contains { $0.text.hasPrefix("Name alone") }
            one.verdict = Self.judge(one)
            result.cases.append(one)
        }
        result.log = (log + events).sorted { $0.t < $1.t }.map { String(format: "%7.2f ", $0.t) + "\($0.kind) " + $0.text }
        return result
    }

    private static func judge(_ item: CaseResult) -> String {
        if item.expect == "wake" {
            if !item.answered.isEmpty { return item.woke ? "ok (woke, answered)" : "ok (answered, name not parsed)" }
            if item.heard.isEmpty { return "not heard" }
            return item.woke ? "woke, no answer" : "name not heard"
        }
        if item.woke { return "false wake" }
        if !item.answered.isEmpty { return "answered without the name" }
        return "ok"
    }

    private func write(_ result: SetResult) throws {
        let out = URL(fileURLWithPath: ProcessInfo.processInfo.environment["LUMEN_E2E_OUT"] ?? NSTemporaryDirectory())
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let url = out.appendingPathComponent("wake-\(result.set).json")
        try encoder.encode(result).write(to: url)
        let ok = result.cases.filter { $0.verdict.hasPrefix("ok") }.count
        print("T17 result: \(url.path) \(ok)/\(result.cases.count) ok")
    }

    private static func cases(in dir: URL) throws -> [Case] {
        // wake.tsv is copied next to the generated audio by scripts/apptest/wake.sh.
        let text = try String(contentsOf: dir.appendingPathComponent("wake.tsv"), encoding: .utf8)
        return text.split(whereSeparator: \.isNewline).dropFirst().compactMap { line in
            let p = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard p.count >= 7 else { return nil }
            return Case(id: p[0], expect: p[1], voice: p[2], rate: p[3], cond: p[4], key: p[5], text: p[6])
        }
    }
}
