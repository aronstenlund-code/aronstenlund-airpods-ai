import Foundation
import Testing
@testable import Lumen

/// T6 (Toby): every voice command in `docs/COMMANDS.md`, three wordings each, plus ten ordinary sentences that
/// contain command words, spoken through the app's real chain (Angela's `FileCaptureService` → VAD → Scribe live →
/// the app's command handling) in all five modes. Requirement: the right action, and 0 false hits.
///
/// Each utterance is judged two ways:
/// - **What the app did:** the session log in the utterance's time window ("Voice: command whisper", "Voice: switch
///   to prov", "Spoken pause: …"). That is the result that counts.
/// - **What the matcher makes of the words Scribe heard:** the app's own pure functions (`VoiceChannel.parse`, the
///   command table) run on the heard text. It tells a misheard phrase (STT) from a phrase the app heard right but
///   handled wrongly (app). Unnamed music commands ("nästa låt") have no log line in the app; for them this is the
///   only evidence, and the verdict says so.
///
/// Per mode one long session with every command that keeps listening, then one short session per command that ends
/// or leaves the session (pause, stop, next/previous song, switch mode). Output: `<LUMEN_E2E_OUT>/commands-<mode>.json`.
///
/// Live and paid (Scribe, /answer for level-2 instructions): runs only when `scripts/apptest/commands.sh` sets
/// `LUMEN_E2E_COMMANDS_DIR`. Answers are not spoken. Simulator only: never a verification on a device.
enum CommandsEnvironment {
    static var audioDir: URL? {
        ProcessInfo.processInfo.environment["LUMEN_E2E_COMMANDS_DIR"].map { URL(fileURLWithPath: $0) }
    }

    /// `LUMEN_E2E_MODES=standard,prov`: the modes to run (CI runs one per job). Empty: all five.
    static var modes: [ConversationMode] {
        let raw = ProcessInfo.processInfo.environment["LUMEN_E2E_MODES"] ?? ""
        let picked = raw.split(separator: ",").compactMap { ConversationMode(rawValue: $0.trimmingCharacters(in: .whitespaces)) }
        return picked.isEmpty ? ConversationMode.allCases : picked
    }
}

@MainActor
@Suite(.serialized, .enabled(if: CommandsEnvironment.audioDir != nil, "set LUMEN_E2E_COMMANDS_DIR (scripts/apptest/commands.sh)"))
struct CommandsE2ETests {
    struct Case: Codable {
        let id: String
        let expect: String
        let run: String
        let flags: String
        let text: String
        var isTerminal: Bool { flags.split(separator: ",").contains("term") }
        var isUniversal: Bool { flags.split(separator: ",").contains("uni") }
        func runs(in mode: ConversationMode) -> Bool {
            run == "all" || run.split(separator: ",").contains(Substring(mode.rawValue))
        }
        /// Universal words count without "Lumen" only in Provläge and Frågor; elsewhere they must do nothing.
        func expected(in mode: ConversationMode) -> String {
            isUniversal && mode != .prov && mode != .standard ? "none" : expect
        }
    }

    struct Line: Codable {
        let t: Double
        let text: String
    }

    struct CaseResult: Codable {
        let id: String
        let text: String
        let expect: String
        let session: String
        var heard: [String] = []
        var log: [String] = []
        /// What the app did, from the log.
        var actions: [String] = []
        /// What the app's matcher makes of the heard words.
        var classified: [String] = []
        var verdict = ""
        /// STT (misheard), app (heard right, wrong action) or "" when it passed.
        var cause = ""
        var after: String?
    }

    struct ModeResult: Codable {
        let mode: String
        var cases: [CaseResult] = []
        var sessions: [String: [String]] = [:]
        var stoppedEarly: [String] = []
        var seconds = 0.0
    }

    @Test func everyCommandInEveryMode() async throws {
        let dir = try #require(CommandsEnvironment.audioDir)
        let cases = try Self.cases(in: dir)
        var problems: [String] = []
        for mode in CommandsEnvironment.modes {
            // Each mode gets other switch wordings, also when CI runs one mode per job.
            let index = ConversationMode.allCases.firstIndex(of: mode) ?? 0
            let started = Date()
            var result = ModeResult(mode: mode.rawValue)
            let eligible = cases.filter { $0.runs(in: mode) }

            // 1. Everything that keeps the session listening, in one session, in the file's order.
            let long = eligible.filter { !$0.isTerminal }
            let (longResults, longLog, stopped) = try await session(name: "long", mode: mode, cases: long, dir: dir)
            result.cases += longResults
            result.sessions["long"] = longLog
            if let stopped { result.stoppedEarly.append("long: \(stopped)") }

            // 2. One short session per command that ends or leaves the session. Mode switches: three to other modes.
            var terminal = eligible.filter { $0.isTerminal && !$0.expect.hasPrefix("switch:") }
            let switches = eligible.filter { $0.expect.hasPrefix("switch:") && $0.expect != "switch:\(mode.rawValue)" }
            terminal += (0..<min(3, switches.count)).map { switches[(index * 2 + $0) % switches.count] }
            for item in terminal {
                let (results, log, _) = try await session(name: item.id, mode: mode, cases: [item], dir: dir)
                result.cases += results
                result.sessions[item.id] = log
            }
            result.seconds = Date().timeIntervalSince(started)
            try write(result)

            for item in result.cases where !item.verdict.hasPrefix("ok") {
                problems.append("\(mode.rawValue)/\(item.id) '\(item.text)': \(item.verdict) (expected \(item.expect), "
                                + "did \(item.actions), heard \(item.heard))")
            }
            for stop in result.stoppedEarly { problems.append("\(mode.rawValue): session stopped early: \(stop)") }
        }
        let falseHits = problems.filter { $0.contains("false-hit") }
        #expect(falseHits.isEmpty, "false hits:\n\(falseHits.joined(separator: "\n"))")
        let misses = problems.filter { !$0.contains("false-hit") }
        #expect(misses.isEmpty, "commands not done:\n\(misses.joined(separator: "\n"))")
    }

    // MARK: One session

    private func session(name: String, mode: ConversationMode, cases: [Case], dir: URL) async throws
        -> ([CaseResult], [String], String?) {
        let gap = 5.0
        let lead = dir.appendingPathComponent("lead-silence.wav")
        let files = [lead] + cases.map { dir.appendingPathComponent("cmd-\($0.id).wav") }
        for file in files { #expect(FileManager.default.fileExists(atPath: file.path), "missing \(file.path)") }
        let audioSeconds = try files.reduce(0.0) { $0 + Double(try FileCaptureService.decode($1).count) / LumenAudioFormat.sampleRate + gap }

        setenv("LUMEN_AUDIO_FILES", files.map(\.path).joined(separator: ":"), 1)
        setenv("LUMEN_AUDIO_GAP", String(gap), 1)
        unsetenv("LUMEN_AUDIO_LOOP")
        Self.prepareSettings()

        let container = AppContainer()
        let capture = try #require(container.capture as? FileCaptureService, "the container did not take the files")
        let model = container.listening
        container.consent.grant()

        let start = Date()
        var heard: [Line] = []
        var log: [Line] = []
        model.sessionObserver = { event, date in
            if case .heard(let text) = event { heard.append(Line(t: date.timeIntervalSince(start), text: text)) }
        }
        container.sessionController.logObserver = { entry in
            log.append(Line(t: entry.time.timeIntervalSince(start), text: entry.text))
        }
        var finished = false
        capture.onFinishedFiles = { finished = true }

        let today = Calendar.current.startOfDay(for: Date())
        let date = Calendar.current.date(byAdding: .day, value: 5, to: today) ?? today
        let plan = ExamPlan(grade: .y9, area: .no, subject: "Biologi", date: date,
                            topics: "fotosyntes, klorofyll, cellandning, mitokondrier")
        model.examPlans?.save(plan)
        switch mode {
        case .prov: await model.startProv(for: plan)
        case .standard: await model.startMode(.standard)
        // Intervju, Socialt and Rizz open a sheet first (role, live start); its Start button calls this.
        default: await model.startHandsFree(mode)
        }

        // When each file starts (file 0 is the lead silence). A restart after a mode switch begins at 0 again: ignored.
        var fileStart: [Int: Double] = [:]
        var stoppedEarly: String?
        // The files play a little slower than real time (a sleep per 40 ms chunk), so the end is when they are done.
        let deadline = start.addingTimeInterval(audioSeconds * 1.3 + 60)
        let terminal = cases.count == 1 && cases[0].isTerminal
        var metAt: Date?
        var quietSince: Date?
        while Date() < deadline {
            try await Task.sleep(for: .milliseconds(100))
            let current = capture.currentFile
            if fileStart[current] == nil, current >= (fileStart.keys.max() ?? -1) {
                fileStart[current] = Date().timeIntervalSince(start)
            }
            if terminal {
                // Stop 3 s after the expected action shows in the log (or the session ended, for "sluta").
                let expected = cases[0].expect
                let done = log.contains { line in
                    guard let action = Self.action(in: line.text) else { return false }
                    return Self.matches(action, expected)
                }
                if done, metAt == nil { metAt = Date() }
                if let metAt, Date().timeIntervalSince(metAt) > 3 { break }
                if finished, Date().timeIntervalSince(start) > audioSeconds + 12 { break }
                continue
            }
            if !model.isActiveSession {
                stoppedEarly = "at file \(current) of \(files.count - 1), t=\(Int(Date().timeIntervalSince(start))) s"
                break
            }
            guard finished else { continue }
            if model.isAnswering { quietSince = nil; continue }
            quietSince = quietSince ?? Date()
            if let quiet = quietSince, Date().timeIntervalSince(quiet) > 12 { break }
        }
        let after = "mode=\(model.mode.rawValue) listening=\(model.isListening) active=\(model.isActiveSession) state=\(model.state)"
        let end = Date().timeIntervalSince(start)
        if model.isActiveSession { await model.endSession() }
        model.sessionObserver = nil
        container.sessionController.logObserver = nil

        // Each utterance owns the time from its file's start to the next file's start.
        var results: [CaseResult] = []
        for (number, item) in cases.enumerated() {
            let from = fileStart[number + 1] ?? .infinity
            let to = fileStart[number + 2] ?? end + 1
            var result = CaseResult(id: item.id, text: item.text, expect: item.expected(in: mode), session: name)
            result.heard = heard.filter { $0.t >= from && $0.t < to }.map(\.text)
            let lines = log.filter { $0.t >= from && $0.t < to }
            result.log = lines.map { String(format: "%6.2f ", $0.t - from) + $0.text }
            result.actions = lines.compactMap { Self.action(in: $0.text) }
            // Scribe may commit "Lumen." on its own; the app's turn can join it with the words after it again.
            result.classified = ([result.heard.joined(separator: " ")] + result.heard).filter { !$0.isEmpty }
                .map { Self.classify($0, in: mode) }
            if terminal { result.after = after }
            Self.judge(&result)
            results.append(result)
        }
        let full = log.map { String(format: "%7.2f ", $0.t) + $0.text } + heard.map { String(format: "%7.2f heard: ", $0.t) + $0.text }
        return (results, full.sorted(), stoppedEarly)
    }

    private static func judge(_ result: inout CaseResult) {
        let expect = result.expect
        let classified = result.classified.first { $0 != "none" } ?? "none"
        let did = result.actions
        if expect == "none" {
            if !did.isEmpty {
                result.verdict = "false-hit"
                result.cause = classified == "none" ? "app" : "matcher"
            } else if classified.hasPrefix("music:") {
                // Unnamed music commands leave no log line: the heard words would have skipped or paused the music.
                result.verdict = "false-hit (from the heard words)"
                result.cause = "matcher"
            } else {
                result.verdict = "ok"
            }
            return
        }
        if did.contains(where: { matches($0, expect) }) {
            // An instruction's log has only its length: the heard words must name the same action.
            if expect.hasPrefix("instr:"), classified != expect {
                result.verdict = "wrong (an instruction, but \(classified))"
                result.cause = "STT"
            } else {
                result.verdict = "ok"
            }
            return
        }
        if expect.hasPrefix("music:"), did.isEmpty, classified == expect {
            result.verdict = "ok (from the heard words: unnamed music commands have no log line)"
            return
        }
        if result.heard.isEmpty, did.isEmpty {
            result.verdict = "not heard"
            result.cause = "STT"
            return
        }
        result.verdict = did.isEmpty ? "missed" : "wrong (\(did.joined(separator: ", ")))"
        result.cause = classified == expect ? "app" : "STT"
    }

    // MARK: Reading the app

    /// The action a session log line reports, in the TSV's words. Nil: not a command line.
    static func action(in line: String) -> String? {
        let rules: [(String, (String) -> String)] = [
            ("Voice: switch to ", { "switch:" + $0 }),
            ("Voice: music ", { "music:" + $0 }),
            ("Voice: command ", { "cmd:" + $0 }),
            ("Voice: instruction (", { "instr(" + $0 }),
        ]
        for (prefix, make) in rules {
            if let range = line.range(of: prefix) { return make(String(line[range.upperBound...])) }
        }
        if line.contains("Voice: pause") || line.contains("Spoken pause: handing the audio back") { return "pause" }
        if line.contains("Voice: stop listening") { return "stop" }
        if line.contains("Voice feedback") { return "feedback" }
        if line.contains("Voice: remembered") { return "remember" }
        if line.contains("Voice: forgot") { return "forget" }
        if line.contains("Voice: rule saved") { return "rule" }
        return nil
    }

    /// A log action against the expected one. An instruction's log carries only its length.
    static func matches(_ action: String, _ expect: String) -> Bool {
        if expect.hasPrefix("instr:") {
            guard action.hasPrefix("instr("), let id = CommandAction(rawValue: String(expect.dropFirst(6))) else { return false }
            if id == .quizMe { return true } // "förhör mig på …": the length depends on the topic
            return action.hasPrefix("instr(\(id.instruction.count) ")
        }
        return action == expect
    }

    /// The app's own order in `receiveFinalTranscript`: "pausa"/"spela musik", unnamed music, "Lumen, …" or a
    /// universal word (Provläge and Frågor only). Complaints without the name are left out (they need an answer
    /// in the last 30 s).
    static func classify(_ text: String, in mode: ConversationMode) -> String {
        if VoiceCommand.isMusicHandOff(text) { return "pause" }
        if let action = VoiceCommand.musicAction(text) { return "music:\(action.rawValue)" }
        var intent = VoiceChannel.parse(text).intent
        if intent == nil, mode == .prov || mode == .standard, let action = CommandBook.shared.table.universal(text) {
            intent = action.level == 1 ? .command(action) : .instruction(action.instruction)
        }
        guard let intent else { return "none" }
        switch intent {
        case .switchTo(let target): return "switch:\(target.rawValue)"
        case .pause: return "pause"
        case .stopListening: return "stop"
        case .music(let action): return "music:\(action.rawValue)"
        case .complaint: return "feedback"
        case .command(let action): return "cmd:\(action.rawValue)"
        case .remember: return "remember"
        case .forget: return "forget"
        case .rule: return "rule"
        case .instruction(let words):
            if let action = CommandAction.allCases.first(where: { $0.level == 2 && $0.instruction == words }) {
                return "instr:\(action.rawValue)"
            }
            if words.hasPrefix("förhör mig") { return "instr:quizMe" }
            return "instr:other(\(words))"
        }
    }

    /// Answers silent (no TTS); every mode allowed to start without its first-time sheet; universal words on.
    private static func prepareSettings() {
        let defaults = UserDefaults.standard
        defaults.set(false, forKey: VoiceSettings.speakKey)
        defaults.set(true, forKey: VoiceSettings.universalKey)
        defaults.set(true, forKey: ModeSettings.adultKey)
        defaults.set(["interview", "rizz", "social"], forKey: ModeSettings.liveStartKey)
        defaults.set("Säljare i en elektronikbutik: kundservice, kassa och lager.", forKey: ModeSettings.interviewKey)
    }

    private func write(_ result: ModeResult) throws {
        let env = ProcessInfo.processInfo.environment
        let out = URL(fileURLWithPath: env["LUMEN_E2E_OUT"] ?? NSTemporaryDirectory())
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let url = out.appendingPathComponent("commands-\(result.mode).json")
        try encoder.encode(result).write(to: url)
        let ok = result.cases.filter { $0.verdict.hasPrefix("ok") }.count
        print("T6 result: \(url.path) \(ok)/\(result.cases.count) ok")
    }

    private static func cases(in dir: URL) throws -> [Case] {
        // commands.tsv is copied next to the generated audio by scripts/apptest/commands.sh.
        let text = try String(contentsOf: dir.appendingPathComponent("commands.tsv"), encoding: .utf8)
        return text.split(whereSeparator: \.isNewline).dropFirst().compactMap { line in
            let parts = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard parts.count >= 5 else { return nil }
            return Case(id: parts[0], expect: parts[1], run: parts[2], flags: parts[3], text: parts[4])
        }
    }
}
