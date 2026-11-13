import Foundation
import Observation

/// D142 (A78): the repetition mode's player. No microphone, no speech recognition, only files and presses.
///
/// The flow: question → thinking time → next question. A press during a question or its thinking time plays the
/// chosen answer (1 = long A+, 2 = short), then the next question. A press during an answer starts that kind of
/// answer for the same question again (2 during the long answer = the short one from the start, and the other way).
/// 3 presses pause; while paused **every** press goes on from the same word (D143). After the last question the list
/// starts again in exactly the same order. The player never ends by itself: only `stop()` (Avsluta on the phone).
///
/// A question whose sound the server has not made yet (K46 makes them in play order) is waited for in silence
/// (`waitingForAudio`, Kelly Ke49 "Gör ljud …"), so Starta prov works as soon as the first question has its sound.
@MainActor
@Observable
final class RepetitionPlayer {
    enum AnswerKind: String, Equatable, Sendable { case long, short }

    enum Phase: Equatable, Sendable {
        case idle
        case question(Int)
        case thinking(Int)
        case answer(Int, AnswerKind)
        /// The question's sound is not made yet; looked for again every `audioRetrySeconds`.
        case waitingForAudio(Int)
    }

    private(set) var phase: Phase = .idle
    private(set) var isPaused = false
    /// The question being asked (0-based), also during its answer and thinking time.
    private(set) var index: Int
    /// Laps played through the whole list (R5d).
    private(set) var lap = 0
    /// Why it paused: a press, or iOS (call, Siri, an AirPod out). Only iOS's own pause comes back by itself.
    private(set) var pausedBySystem = false
    /// When the thinking time began (the screen's ring counts down from it).
    private(set) var thinkingStarted: Date?

    /// The number of questions.
    let count: Int
    let thinkingSeconds: Double
    /// Spec §3, AirPods 1/2 (one function per earbud, no triple press): 1 press during an answer pauses instead of
    /// starting the long answer again. Set from the AirPods check (`ControlCheck.usesEarbudLayout`).
    var onePressPausesAnswer = false
    /// Kelly N1: a new user's first lap. The screen says "Tryck på AirPods för svaret", and `cue` ("Tryck en gång för
    /// svaret.") plays once after the first thinking time that passes without a press.
    var isFirstLap = false
    var cue: URL?
    /// Called after every step with the index to come back to (R8: "Fortsätt där du var?").
    var onProgress: (@MainActor (Int) -> Void)?
    /// Every step as one line, for the log and the Simulator tests.
    var onStep: (@MainActor (String) -> Void)?

    static let audioRetrySeconds = 1.0

    private let trackAt: @MainActor (Int) -> RepetitionTrack?
    private let source: any RepetitionAudioSource
    private let timer: any RepetitionTimer
    private var current: (any RepetitionAudioPlayer)?
    /// Files that would not open in a row; a whole lap of them stops the loop instead of spinning.
    private var failuresInARow = 0

    init(count: Int, track: @escaping @MainActor (Int) -> RepetitionTrack?, source: any RepetitionAudioSource,
         timer: any RepetitionTimer, thinkingSeconds: Double, startAt: Int = 0) {
        self.count = count
        self.trackAt = track
        self.source = source
        self.timer = timer
        self.thinkingSeconds = thinkingSeconds
        self.index = count == 0 ? 0 : min(max(startAt, 0), count - 1)
    }

    /// All tracks known up front (the tests, the iPhone-voice mock).
    convenience init(tracks: [RepetitionTrack], source: any RepetitionAudioSource, timer: any RepetitionTimer,
                     thinkingSeconds: Double, startAt: Int = 0) {
        self.init(count: tracks.count, track: { tracks.indices.contains($0) ? tracks[$0] : nil },
                  source: source, timer: timer, thinkingSeconds: thinkingSeconds, startAt: startAt)
    }

    var isRunning: Bool { phase != .idle }

    func start() {
        guard count > 0, phase == .idle else { return }
        step("start at \(index + 1) of \(count), thinking \(thinkingSeconds) s")
        playQuestion(index)
    }

    /// Avsluta: the only way the repetition ends.
    func stop() {
        timer.cancel()
        current?.stop()
        current = nil
        phase = .idle
        isPaused = false
        pausedBySystem = false
        thinkingStarted = nil
        step("stop")
    }

    // MARK: Presses

    func handle(_ event: RepetitionEvent) {
        guard isRunning else { return }
        if isPaused {
            // D143: under paus fortsätter alla tryck från samma ord.
            resume(by: "press \(event.rawValue)")
            return
        }
        if case .waitingForAudio = phase {
            // Nothing to answer yet: only a pause means something.
            if event == .pauseToggle { pause(bySystem: false) }
            return
        }
        switch event {
        case .pauseToggle:
            pause(bySystem: false)
        case .long:
            if onePressPausesAnswer, case .answer = phase {
                pause(bySystem: false)
            } else {
                playAnswer(index, .long)
            }
        case .short:
            playAnswer(index, .short)
        }
    }

    // MARK: iOS

    /// A call, Siri, an alarm, an AirPod out of the ear or AirPods gone: pause, never end.
    func systemPaused(_ why: String) {
        guard isRunning, !isPaused else { return }
        step("system pause: \(why)")
        pause(bySystem: true)
    }

    /// An interruption ended with `shouldResume`: only a pause iOS made comes back by itself.
    func systemResumed(_ why: String) {
        guard isRunning, isPaused, pausedBySystem else { return }
        resume(by: "system: \(why)")
    }

    // MARK: Steps

    private func playQuestion(_ i: Int) {
        index = i
        thinkingStarted = nil
        guard let track = trackAt(i) else {
            if phase != .waitingForAudio(i) { step("waiting for the sound of question \(i + 1)") }
            phase = .waitingForAudio(i)
            timer.start(seconds: Self.audioRetrySeconds) { [weak self] in
                guard let self, self.phase == .waitingForAudio(i), !self.isPaused else { return }
                self.playQuestion(i)
            }
            return
        }
        phase = .question(i)
        step("question \(i + 1)")
        play(track.question, until: nil) { [weak self] in self?.questionEnded(i) }
    }

    private func questionEnded(_ i: Int) {
        guard phase == .question(i) else { return }
        current = nil
        startThinking(i)
    }

    private func startThinking(_ i: Int) {
        phase = .thinking(i)
        thinkingStarted = Date()
        step("thinking \(i + 1)")
        timer.start(seconds: thinkingSeconds) { [weak self] in
            guard let self, self.phase == .thinking(i), !self.isPaused else { return }
            if self.isFirstLap, self.lap == 0, let cue = self.cue {
                // Kelly N1: once, so the next question does not sound like a skipped answer.
                self.cue = nil
                self.step("cue: press for the answer")
                self.play(cue, until: nil) { [weak self] in
                    guard let self, self.phase == .thinking(i) else { return }
                    self.current = nil
                    self.next()
                }
                return
            }
            self.next()
        }
    }

    private func playAnswer(_ i: Int, _ kind: AnswerKind) {
        guard let track = trackAt(i) else { return }
        timer.cancel()
        current?.stop()
        current = nil
        thinkingStarted = nil
        phase = .answer(i, kind)
        step("\(kind.rawValue) answer \(i + 1)")
        let done: @MainActor () -> Void = { [weak self] in
            guard let self, self.phase == .answer(i, kind) else { return }
            self.current = nil
            self.next()
        }
        switch (kind, track.short) {
        case (.long, _):
            play(track.long, until: nil, then: done)
        case (.short, .prefix(let end)):
            play(track.long, until: end.isFinite ? end : nil, then: done)
        case (.short, .file(let url)):
            play(url, until: nil, then: done)
        }
    }

    private func next() {
        let following = (index + 1) % count
        if following == 0 { lap += 1; step("lap \(lap) done, from question 1 again") }
        onProgress?(following)
        playQuestion(following)
    }

    private func play(_ url: URL, until: TimeInterval?, then done: @escaping @MainActor () -> Void) {
        current?.stop()
        do {
            let player = try source.player(for: url)
            failuresInARow = 0
            player.onFinish = done
            current = player
            player.play(until: until)
        } catch {
            failuresInARow += 1
            step("could not open \(url.lastPathComponent): \(error.localizedDescription)")
            current = nil
            guard failuresInARow < max(count * 2, 2) else {
                // Nothing plays at all: wait as long as a question takes instead of spinning, never end by itself.
                timer.start(seconds: 30) { [weak self] in self?.failuresInARow = 0; done() }
                return
            }
            timer.start(seconds: 1) { done() }
        }
    }

    private func pause(bySystem: Bool) {
        isPaused = true
        pausedBySystem = bySystem
        timer.cancel()
        current?.pause()
        step(bySystem ? "paused by iOS" : "paused")
    }

    private func resume(by why: String) {
        isPaused = false
        pausedBySystem = false
        step("go on (\(why))")
        switch phase {
        case .idle:
            break
        case .thinking(let i):
            // The thinking time starts over: a whole pause has passed.
            startThinking(i)
        case .waitingForAudio(let i):
            playQuestion(i)
        case .question, .answer:
            if let current {
                current.play(until: untilForCurrentPhase())
            } else if case .question(let i) = phase {
                playQuestion(i)
            } else {
                next()
            }
        }
    }

    private func untilForCurrentPhase() -> TimeInterval? {
        guard case .answer(let i, .short) = phase, let track = trackAt(i), case .prefix(let end) = track.short,
              end.isFinite else { return nil }
        return end
    }

    private func step(_ line: String) {
        Log.repetition.info("Repetition: \(line, privacy: .public)")
        onStep?(line)
    }
}

#if DEBUG
extension RepetitionPlayer {
    /// The Simulator screenshots (Kelly Ke49 §7): the player in a given state, without sound or timers.
    func stageForScreenshot(_ phase: Phase, index: Int, lap: Int = 0, paused: Bool = false) {
        self.phase = phase
        self.index = index
        self.lap = lap
        self.isPaused = paused
        // A picture taken seconds later still shows the ring 2 s in (the view clamps to the thinking time).
        if case .thinking = phase { thinkingStarted = .distantFuture }
    }
}
#endif
