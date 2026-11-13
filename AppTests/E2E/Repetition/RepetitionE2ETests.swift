import AVFAudio
import Foundation
import Testing
@testable import Lumen

/// T18 (Toby 2): Angela's A78 (A82) in the Simulator with mock sound: quiet tones of known length made by
/// `scripts/apptest/repetition.sh` (question 2.0 s, long answer 6.0 s with the short answer ending at 2.5 s, short
/// answer file 2.5 s). The real `RepetitionSession`, `FileRepetitionAudioSource` (AVAudioPlayer) and
/// `TaskRepetitionTimer(keepsPlaying: true)`, presses through `RemoteCommandHub.route` as AirPods send them.
///
/// Measured: thinking time, the order over three laps (R5d), each press (R6 logic), pause → go on from the same
/// position (R7 proxy), iOS pauses and route loss (R8 proxy), `.playback` and never the microphone (R9 proxy), a
/// question without sound yet (K46 in play order). Free: no network, 0 ElevenLabs. **Simulator only: no AirPods, no
/// locked screen, never a verification on a device.**
enum RepetitionE2EEnvironment {
    static var audioDir: URL? {
        ProcessInfo.processInfo.environment["LUMEN_E2E_REPETITION_DIR"].map { URL(fileURLWithPath: $0) }
    }
}

@MainActor
@Suite(.serialized, .enabled(if: RepetitionE2EEnvironment.audioDir != nil, "set LUMEN_E2E_REPETITION_DIR (scripts/apptest/repetition.sh)"))
struct RepetitionE2ETests {
    // MARK: Recording around the real players

    /// What happened to each file: when it played, where it paused and went on, when it ended.
    @MainActor final class Recorder {
        struct Event: Codable { let t: Double; let file: String; let what: String; let position: Double }
        let start = Date()
        var events: [Event] = []
        func add(_ file: URL, _ what: String, _ position: Double) {
            events.append(Event(t: Date().timeIntervalSince(start), file: file.deletingPathExtension().lastPathComponent,
                                what: what, position: position))
        }
    }

    @MainActor final class RecordingPlayer: RepetitionAudioPlayer {
        let inner: any RepetitionAudioPlayer
        let url: URL
        let recorder: Recorder
        init(inner: any RepetitionAudioPlayer, url: URL, recorder: Recorder) {
            self.inner = inner; self.url = url; self.recorder = recorder
        }
        var onFinish: (@MainActor () -> Void)? {
            get { inner.onFinish }
            set {
                guard let newValue else { inner.onFinish = nil; return }
                inner.onFinish = { [weak self] in
                    if let self { self.recorder.add(self.url, "end", self.inner.currentTime) }
                    newValue()
                }
            }
        }
        var currentTime: TimeInterval { inner.currentTime }
        func play(until: TimeInterval?) { recorder.add(url, until.map { "play until \($0)" } ?? "play", inner.currentTime); inner.play(until: until) }
        func pause() { inner.pause(); recorder.add(url, "pause", inner.currentTime) }
        func stop() { recorder.add(url, "stop", inner.currentTime); inner.stop() }
    }

    @MainActor final class RecordingSource: RepetitionAudioSource {
        let recorder: Recorder
        var last: RecordingPlayer?
        init(recorder: Recorder) { self.recorder = recorder }
        func player(for url: URL) throws -> any RepetitionAudioPlayer {
            let player = RecordingPlayer(inner: try FileRepetitionAudioSource().player(for: url), url: url, recorder: recorder)
            last = player
            return player
        }
    }

    // MARK: Set-up

    @MainActor final class ReadySet { var items: Set<Int> = [0] }

    @MainActor struct Run {
        let session: RepetitionSession
        let hub: RemoteCommandHub
        let source: RecordingSource
        let recorder: Recorder
        var player: RepetitionPlayer? { session.player }
    }

    static func url(_ name: String) -> URL {
        (RepetitionE2EEnvironment.audioDir ?? URL(fileURLWithPath: "/tmp")).appendingPathComponent("\(name).wav")
    }

    /// Items 0–2: the short answer is the long file up to 2.5 s (K46, D145); item 3: a file of its own.
    static func track(_ i: Int) -> RepetitionTrack {
        RepetitionTrack(question: url("q\(i)"), long: url("l\(i)"),
                        short: i == 3 ? .file(url("s\(i)")) : .prefix(ofLongUntil: 2.5))
    }

    static let drill = Drill(title: "T18", summary: DrillSummary(subject: "Test", grade: "", covers: ""),
                             items: (0..<4).map { DrillItem(question: "F\($0)", short: "K\($0).", long: "K\($0). L\($0).") })

    func begin(count: Int = 4, track: @escaping @MainActor (Int) -> RepetitionTrack? = { RepetitionE2ETests.track($0) }) throws -> Run {
        let defaults = try #require(UserDefaults(suiteName: "T18-\(UUID().uuidString)"))
        let hub = RemoteCommandHub()
        let recorder = Recorder()
        let source = RecordingSource(recorder: recorder)
        let session = RepetitionSession(inputs: [AirPodsRepetitionInput(hub: hub)], makeSource: { source },
                                        makeTimer: { TaskRepetitionTimer(keepsPlaying: true) },
                                        defaults: defaults, activatesAudioSession: true)
        session.start(Self.drill, count: count, track: track)
        return Run(session: session, hub: hub, source: source, recorder: recorder)
    }

    /// Waits until `condition` holds; the seconds it took, or nil at the deadline.
    @discardableResult
    func wait(_ seconds: Double, _ condition: () -> Bool) async -> Double? {
        let start = Date()
        while Date().timeIntervalSince(start) < seconds {
            if condition() { return Date().timeIntervalSince(start) }
            try? await Task.sleep(for: .milliseconds(25))
        }
        return condition() ? Date().timeIntervalSince(start) : nil
    }

    func phase(_ run: Run) -> RepetitionPlayer.Phase { run.player?.phase ?? .idle }

    static var lines: [String] = []
    static func note(_ line: String) {
        lines.append(line)
        print("T18: \(line)")
        let out = URL(fileURLWithPath: ProcessInfo.processInfo.environment["LUMEN_E2E_OUT"] ?? NSTemporaryDirectory())
        try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        let text = "# T18: repetitionsläget i simulatorn (mockljud, inte enhet)\n\n" + lines.map { "- \($0)" }.joined(separator: "\n") + "\n"
        try? text.write(to: out.appendingPathComponent("summary.md"), atomically: true, encoding: .utf8)
    }

    func save(_ run: Run, _ name: String) {
        let out = URL(fileURLWithPath: ProcessInfo.processInfo.environment["LUMEN_E2E_OUT"] ?? NSTemporaryDirectory())
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try? encoder.encode(run.recorder.events).write(to: out.appendingPathComponent("repetition-\(name).json"))
        try? run.session.steps.joined(separator: "\n").write(to: out.appendingPathComponent("repetition-\(name)-steps.txt"),
                                                            atomically: true, encoding: .utf8)
    }

    // MARK: R5d, thinking time, never ends, no microphone

    @Test func threeLapsInTheSameOrderWithThinkingTime() async throws {
        let run = try begin()
        defer { run.session.stop() }
        var order: [Int] = []
        var thinking: [Double] = []
        var categories = Set<String>()
        // 3 laps of 4 questions: about 3 × 4 × (2 + 6) s.
        let deadline = Date().addingTimeInterval(130)
        var last: RepetitionPlayer.Phase = .idle
        var thinkingFrom: Date?
        while order.count < 13, Date() < deadline {
            let now = phase(run)
            if now != last {
                if case .question(let i) = now { order.append(i) }
                if case .thinking = now { thinkingFrom = Date() }
                if case .thinking = last, let from = thinkingFrom { thinking.append(Date().timeIntervalSince(from)) }
                last = now
            }
            categories.insert(AVAudioSession.sharedInstance().category.rawValue)
            #expect(run.session.isActive, "ended by itself at \(order.count) questions")
            try await Task.sleep(for: .milliseconds(25))
        }
        save(run, "laps")
        let expected = Array([0, 1, 2, 3, 0, 1, 2, 3, 0, 1, 2, 3, 0].prefix(order.count))
        #expect(order == expected, "order \(order)")
        #expect(order.count == 13, "only \(order.count) questions in 130 s")
        #expect(run.player?.lap ?? 0 >= 3)
        let mean = thinking.isEmpty ? 0 : thinking.reduce(0, +) / Double(thinking.count)
        #expect(thinking.allSatisfy { abs($0 - 6) < 0.8 }, "thinking times \(thinking)")
        #expect(categories == [AVAudioSession.Category.playback.rawValue], "audio session \(categories)")
        #expect(AVAudioApplication.shared.recordPermission == .undetermined, "the microphone was asked for")
        Self.note("R5d ordning i 3 varv: \(order.map { String($0 + 1) }.joined(separator: " ")) (\(order == expected ? "rätt" : "FEL"))")
        Self.note(String(format: "Betänketid: %d gånger, medel %.2f s, %.2f–%.2f s (krav 6 s ± 0,8)", thinking.count, mean,
                         thinking.min() ?? 0, thinking.max() ?? 0))
        Self.note("Ljudsessionen: \(categories.sorted().joined(separator: ", ")); mikrofonbehörighet: \(AVAudioApplication.shared.recordPermission == .undetermined ? "aldrig frågad" : "FRÅGAD")")
        Self.note("Avslutades aldrig av sig själv under \(order.count) frågor: \(run.session.isActive ? "ja" : "NEJ")")
    }

    // MARK: R6 logic: each press through the hub

    @Test func everyPressDoesWhatItShould() async throws {
        let run = try begin()
        defer { run.session.stop() }
        // 1 press (play) during question 1: the long answer (6 s), then question 2 without thinking time.
        #expect(await wait(5) { phase(run) == .question(0) } != nil)
        await run.hub.route(.play)
        let longStarted = await wait(2) { phase(run) == .answer(0, .long) }
        let longLasted = await wait(9) { phase(run) == .question(1) }
        // 2 presses (next track) during the thinking time of question 2: the short answer = the long file to 2.5 s.
        #expect(await wait(5) { phase(run) == .thinking(1) } != nil)
        await run.hub.route(.next)
        let shortStarted = await wait(2) { phase(run) == .answer(1, .short) }
        let shortLasted = await wait(6) { phase(run) == .question(2) }
        // toggle (also 1 press) during question 3.
        await run.hub.route(.toggle)
        let toggled = await wait(2) { phase(run) == .answer(2, .long) }
        await run.hub.route(.pause) // "pause" from iOS is 1 press too: the long answer again (or a pause on AirPods 1/2)
        let pauseCommand = await wait(2) { phase(run) == .answer(2, .long) }
        #expect(await wait(9) { phase(run) == .question(3) } != nil)
        // 2 presses on item 4: the short answer's own file (2.5 s).
        await run.hub.route(.next)
        let fileShort = await wait(2) { phase(run) == .answer(3, .short) }
        let fileShortLasted = await wait(6) { phase(run) == .question(0) }
        save(run, "presses")

        #expect(longStarted != nil && shortStarted != nil && toggled != nil && pauseCommand != nil && fileShort != nil)
        #expect(longLasted.map { abs($0 - 6) < 0.8 } == true, "long answer \(longLasted ?? -1) s")
        #expect(shortLasted.map { abs($0 - 2.5) < 0.6 } == true, "short answer (prefix) \(shortLasted ?? -1) s")
        #expect(fileShortLasted.map { abs($0 - 2.5) < 0.6 } == true, "short answer (file) \(fileShortLasted ?? -1) s")
        Self.note(String(format: "1 tryck (play) → långt svar: %@, %.2f s (fil 6,0 s), sedan nästa fråga utan betänketid",
                         longStarted != nil ? "ja" : "NEJ", longLasted ?? -1))
        Self.note(String(format: "2 tryck (nästa spår) → kort svar ur den långa filen: %@, stannade efter %.2f s (slut 2,5 s)",
                         shortStarted != nil ? "ja" : "NEJ", shortLasted ?? -1))
        Self.note(String(format: "2 tryck med egen kortsvarsfil: %@, %.2f s (fil 2,5 s)", fileShort != nil ? "ja" : "NEJ", fileShortLasted ?? -1))
        Self.note("toggle och pause från iOS räknas som 1 tryck: \(toggled != nil && pauseCommand != nil ? "ja" : "NEJ")")
    }

    // MARK: R7 proxy: pause and go on from the same position

    @Test func pauseGoesOnFromTheSamePosition() async throws {
        var rows: [String] = []
        var worst = 0.0
        for (n, resume) in [RemoteCommand.play, .next, .previous, .toggle].enumerated() {
            let run = try begin()
            #expect(await wait(5) { phase(run) == .question(0) } != nil)
            await run.hub.route(.play)
            #expect(await wait(2) { phase(run) == .answer(0, .long) } != nil)
            try await Task.sleep(for: .milliseconds(2_000 + 300 * n))
            await run.hub.route(.previous) // 3 presses
            #expect(await wait(2) { run.player?.isPaused == true } != nil)
            let pausedAt = run.source.last?.currentTime ?? -1
            try await Task.sleep(for: .seconds(3))
            let stillAt = run.source.last?.currentTime ?? -1
            #expect(abs(stillAt - pausedAt) < 0.05, "moved while paused: \(pausedAt) → \(stillAt)")
            #expect(run.session.isActive)
            await run.hub.route(resume) // every press goes on
            #expect(await wait(2) { run.player?.isPaused == false } != nil, "\(resume) did not go on")
            try await Task.sleep(for: .milliseconds(300))
            let goneOnFrom = run.recorder.events.last { $0.what.hasPrefix("play") }?.position ?? -1
            let phaseAfter = phase(run)
            let finished = await wait(8) { phase(run) == .question(1) }
            save(run, "pause-\(resume.rawValue)")
            run.session.stop()
            let jump = abs(goneOnFrom - pausedAt)
            worst = max(worst, jump)
            #expect(jump < 0.1, "\(resume): paused at \(pausedAt), went on from \(goneOnFrom)")
            #expect(phaseAfter == .answer(0, .long), "\(resume): \(phaseAfter) after going on")
            let rest = 6 - pausedAt
            #expect(finished.map { abs($0 + 0.3 - rest) < 0.8 } == true, "\(resume): the rest took \(finished ?? -1) s, expected \(rest)")
            rows.append(String(format: "%@: pausad vid %.2f s, fortsatte från %.2f s, resten %.2f s (väntat %.2f)",
                               resume.rawValue, pausedAt, goneOnFrom, (finished ?? -1) + 0.3, rest))
        }
        Self.note(String(format: "R7 (proxy) paus → fortsätt med alla fyra kommandon, största hopp %.3f s: ", worst) + rows.joined(separator: "; "))
    }

    // MARK: R8 proxy: iOS pauses, never ends

    @Test func iOSPausesAndRouteLossNeverEnd() async throws {
        let run = try begin()
        defer { run.session.stop() }
        #expect(await wait(5) { phase(run) == .question(0) } != nil)
        await run.hub.route(.play)
        #expect(await wait(2) { phase(run) == .answer(0, .long) } != nil)
        try await Task.sleep(for: .seconds(1))
        run.session.interruption(typeRaw: AVAudioSession.InterruptionType.began.rawValue, optionsRaw: 0)
        let pausedByCall = run.player?.isPaused == true
        run.session.interruption(typeRaw: AVAudioSession.InterruptionType.ended.rawValue,
                                 optionsRaw: AVAudioSession.InterruptionOptions.shouldResume.rawValue)
        let backAfterCall = await wait(2) { run.player?.isPaused == false } != nil

        run.session.interruption(typeRaw: AVAudioSession.InterruptionType.began.rawValue, optionsRaw: 0)
        run.session.interruption(typeRaw: AVAudioSession.InterruptionType.ended.rawValue, optionsRaw: 0)
        let waitsWithoutResume = run.player?.isPaused == true
        await run.hub.route(.next)
        let pressAfter = await wait(2) { run.player?.isPaused == false } != nil

        run.session.routeChanged(reasonRaw: AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue)
        let pausedByRoute = run.player?.isPaused == true
        try await Task.sleep(for: .seconds(5))
        let stillActive = run.session.isActive
        await run.hub.route(.play)
        let pressAfterRoute = await wait(2) { run.player?.isPaused == false } != nil
        save(run, "ios")

        #expect(pausedByCall && backAfterCall && waitsWithoutResume && pressAfter && pausedByRoute && stillActive && pressAfterRoute)
        Self.note("R8 (proxy): samtal pausar \(pausedByCall ? "ja" : "NEJ"), fortsätter av sig själv med shouldResume \(backAfterCall ? "ja" : "NEJ"); utan shouldResume väntar den på tryck \(waitsWithoutResume ? "ja" : "NEJ") och trycket fortsätter \(pressAfter ? "ja" : "NEJ"); ljudvägen borta pausar \(pausedByRoute ? "ja" : "NEJ"), aktiv efter 5 s \(stillActive ? "ja" : "NEJ"), tryck fortsätter \(pressAfterRoute ? "ja" : "NEJ")")
    }

    // MARK: Sound that is not made yet (K46 in play order)

    @Test func aQuestionWithoutSoundIsWaitedFor() async throws {
        // A reference, not a captured var: the track closure is Sendable (Swift 6).
        let ready = ReadySet()
        let run = try begin { ready.items.contains($0) ? Self.track($0) : nil }
        defer { run.session.stop() }
        let waiting = await wait(12) { phase(run) == .waitingForAudio(1) }
        try await Task.sleep(for: .seconds(2))
        let stillWaiting = phase(run) == .waitingForAudio(1) && run.session.isActive
        let category = AVAudioSession.sharedInstance().category
        ready.items.insert(1)
        let played = await wait(3) { phase(run) == .question(1) }
        save(run, "waiting")
        #expect(waiting != nil && stillWaiting && played != nil)
        Self.note(String(format: "Fråga utan ljud: väntar (waitingForAudio) %@, fortfarande aktiv efter 2 s %@, spelas %.2f s efter att ljudet finns (försök var 1 s), ljudsessionen %@",
                         waiting != nil ? "ja" : "NEJ", stillWaiting ? "ja" : "NEJ", played ?? -1, category.rawValue))
    }
}
