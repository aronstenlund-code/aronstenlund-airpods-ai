import Foundation
import Observation

/// D142 (A78): the repetition mode's player. No microphone, no speech recognition, only files and presses.
///
/// The flow: question → thinking time → next question. A press during a question or its thinking time plays the
/// chosen answer (1 = long A+, 2 = short), then the next question. A press during an answer starts that kind of
/// answer for the same question again (2 during the long answer = the short one from the start, and the other way).
/// 3 presses pause; while paused **every** press goes on from the same word (D143). After the last question the list
/// starts again in exactly the same order. The player never ends by itself: only `stop()` (Avsluta on the phone).
@MainActor
@Observable
final class RepetitionPlayer {
    enum AnswerKind: String, Equatable, Sendable { case long, short }

    enum Phase: Equatable, Sendable {
        case idle
        case question(Int)
        case thinking(Int)
        case answer(Int, AnswerKind)
    }

    private(set) var phase: Phase = .idle
    private(set) var isPaused = false
    /// The question being asked (0-based), also during its answer and thinking time.
    private(set) var index: Int
    /// Laps played through the whole list (R5d).
    private(set) var lap = 0
    /// Why it paused: a press, or iOS (call, Siri, an AirPod out). Only iOS's own pause comes back by itself.
    private(set) var pausedBySystem = false

    let tracks: [RepetitionTrack]
    let thinkingSeconds: Double
    /// Called after every step with the index to come back to (R8: "Fortsätt där du var?").
    var onProgress: (@MainActor (Int) -> Void)?
    /// Every step as one line, for the log and the Simulator tests.
    var onStep: (@MainActor (String) -> Void)?

    private let source: any RepetitionAudioSource
    private let timer: any RepetitionTimer
    private var current: (any RepetitionAudioPlayer)?
    /// Files that would not open in a row; a whole lap of them stops the loop instead of spinning.
    private var failuresInARow = 0

    init(tracks: [RepetitionTrack], source: any RepetitionAudioSource, timer: any RepetitionTimer,
         thinkingSeconds: Double, startAt: Int = 0) {
        self.tracks = tracks
        self.source = source
        self.timer = timer
        self.thinkingSeconds = thinkingSeconds
        self.index = tracks.isEmpty ? 0 : min(max(startAt, 0), tracks.count - 1)
    }

    var isRunning: Bool { phase != .idle }

    func start() {
        guard !tracks.isEmpty, phase == .idle else { return }
        step("start at \(index + 1) of \(tracks.count), thinking \(thinkingSeconds) s")
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
        switch event {
        case .pauseToggle:
            pause(bySystem: false)
        case .long:
            playAnswer(index, .long)
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
        phase = .question(i)
        step("question \(i + 1)")
        play(tracks[i].question, until: nil) { [weak self] in self?.questionEnded(i) }
    }

    private func questionEnded(_ i: Int) {
        guard phase == .question(i) else { return }
        current = nil
        phase = .thinking(i)
        step("thinking \(i + 1)")
        timer.start(seconds: thinkingSeconds) { [weak self] in
            guard let self, self.phase == .thinking(i), !self.isPaused else { return }
            self.next()
        }
    }

    private func playAnswer(_ i: Int, _ kind: AnswerKind) {
        timer.cancel()
        current?.stop()
        current = nil
        phase = .answer(i, kind)
        step("\(kind.rawValue) answer \(i + 1)")
        let track = tracks[i]
        let done: @MainActor () -> Void = { [weak self] in
            guard let self, self.phase == .answer(i, kind) else { return }
            self.current = nil
            self.next()
        }
        switch (kind, track.short) {
        case (.long, _):
            play(track.long, until: nil, then: done)
        case (.short, .prefix(let end)):
            play(track.long, until: end, then: done)
        case (.short, .file(let url)):
            play(url, until: nil, then: done)
        }
    }

    private func next() {
        let following = (index + 1) % tracks.count
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
            guard failuresInARow < max(tracks.count * 2, 2) else {
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
            timer.start(seconds: thinkingSeconds) { [weak self] in
                guard let self, self.phase == .thinking(i), !self.isPaused else { return }
                self.next()
            }
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
        guard case .answer(let i, .short) = phase, case .prefix(let end) = tracks[i].short else { return nil }
        return end
    }

    private func step(_ line: String) {
        Log.repetition.info("Repetition: \(line, privacy: .public)")
        onStep?(line)
    }
}
