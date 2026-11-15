import Foundation
import Observation

/// D185 (A105): one sentence of a read-aloud text, with where it is in its paragraph's sound file.
struct ReadingSentence: Codable, Equatable, Sendable {
    var text: String
    /// Seconds into the paragraph's file at normal speed (K70's timestamps, from ElevenLabs' character times).
    var start: TimeInterval
    var end: TimeInterval
}

/// D185: a paragraph of the text: one sound file and its sentences. A heading is a paragraph of its own.
struct ReadingParagraph: Codable, Equatable, Sendable {
    var sentences: [ReadingSentence]
    var isHeading: Bool = false
}

/// Where the reader is: paragraph and sentence in it, and the same as one number counted through the whole text.
struct ReadingPosition: Equatable, Sendable {
    var paragraph: Int
    var sentence: Int
}

/// D185 (A105): the reading mode's player. A text is paragraphs of sentences; each paragraph is one file.
///
/// The AirPods (and Control Center, and the screen's buttons) use the same three events as the questions (D142), with
/// the meanings of an ordinary player:
/// - 1 press (`.long`): pause, and 1 press again goes on **from the start of the sentence** (D164);
/// - 2 presses (`.short`, next track): the next sentence;
/// - 3 presses (`.pauseToggle`, previous track): the previous sentence.
///
/// While paused, 2 and 3 presses move the place and stay paused, so the next 1 press starts from the sentence chosen
/// (an ordinary player's next/previous while paused). After the last sentence the player stops at the end of the text
/// (`isAtEnd`); 1 press there starts the text from the beginning, 3 presses go back to the last sentence. Only
/// `stop()` (Avsluta) ends it.
///
/// A paragraph whose sound is not downloaded yet is waited for in silence, as with the questions (A103: everything
/// downloaded plays without network).
@MainActor
@Observable
final class ReadingPlayer {
    enum Phase: Equatable, Sendable {
        case idle
        case reading
        /// The paragraph's sound is not on the phone yet; looked for again every `audioRetrySeconds`.
        case waitingForAudio
        /// After the last sentence.
        case atEnd
    }

    private(set) var phase: Phase = .idle
    private(set) var isPaused = false
    private(set) var pausedBySystem = false
    /// The sentence being read (or to start from), counted through the whole text (0-based).
    private(set) var sentenceIndex: Int

    let paragraphs: [ReadingParagraph]
    /// The paragraph and sentence of every sentence number.
    let positions: [ReadingPosition]
    var tempo: Double = 1
    /// Called when the sentence changes, with the sentence to come back to ("Fortsätt där du slutade").
    var onProgress: (@MainActor (Int) -> Void)?
    var onStep: (@MainActor (String) -> Void)?

    static let audioRetrySeconds = 1.0

    private let audioAt: @MainActor (Int) -> URL?
    private let source: any RepetitionAudioSource
    private let timer: any RepetitionTimer
    private var current: (any RepetitionAudioPlayer)?
    /// The paragraph `current` plays.
    private var currentParagraph: Int?
    private var failuresInARow = 0

    /// `audio` gives a paragraph's file, or nil while it is not downloaded; asked again when it is needed.
    init(paragraphs: [ReadingParagraph], audio: @escaping @MainActor (Int) -> URL?, source: any RepetitionAudioSource,
         timer: any RepetitionTimer, startAt: Int = 0) {
        self.paragraphs = paragraphs
        self.positions = paragraphs.enumerated().flatMap { p, paragraph in
            paragraph.sentences.indices.map { ReadingPosition(paragraph: p, sentence: $0) }
        }
        self.audioAt = audio
        self.source = source
        self.timer = timer
        self.sentenceIndex = positions.isEmpty ? 0 : min(max(startAt, 0), positions.count - 1)
    }

    var sentenceCount: Int { positions.count }
    var isRunning: Bool { phase != .idle }
    var isAtEnd: Bool { phase == .atEnd }

    var currentSentence: ReadingSentence? {
        guard positions.indices.contains(sentenceIndex) else { return nil }
        let p = positions[sentenceIndex]
        return paragraphs[p.paragraph].sentences[p.sentence]
    }

    func start() {
        guard !positions.isEmpty, phase == .idle else { return }
        step("read: start at sentence \(sentenceIndex + 1) of \(positions.count)")
        playSentence(sentenceIndex)
    }

    /// Avsluta.
    func stop() {
        timer.cancel()
        current?.stop()
        current = nil
        currentParagraph = nil
        phase = .idle
        isPaused = false
        pausedBySystem = false
        step("read: stop")
    }

    // MARK: Presses

    func handle(_ event: RepetitionEvent) {
        guard isRunning else { return }
        switch event {
        case .long:
            togglePause()
        case .short:
            move(to: sentenceIndex + 1, why: "next")
        case .pauseToggle:
            move(to: sentenceIndex - 1, why: "previous")
        }
    }

    /// The screen: a tap on a sentence reads from there (and goes on reading if it was paused).
    func jump(to sentence: Int) {
        guard isRunning, positions.indices.contains(sentence) else { return }
        isPaused = false
        pausedBySystem = false
        step("read: tap on sentence \(sentence + 1)")
        playSentence(sentence)
    }

    private func togglePause() {
        if phase == .atEnd {
            // The end of the text: 1 press reads it again from the beginning.
            isPaused = false
            step("read: from the beginning again")
            playSentence(0)
            return
        }
        if isPaused { resume(by: "press") } else { pause(bySystem: false) }
    }

    private func move(to target: Int, why: String) {
        if phase == .atEnd {
            // 2 presses at the end do nothing; 3 presses go back to the last sentence.
            guard target < positions.count else { return }
            step("read: \(why) from the end")
            if isPaused { place(at: positions.count - 1) } else { playSentence(positions.count - 1) }
            return
        }
        let clamped = min(max(target, 0), positions.count - 1)
        if target >= positions.count {
            step("read: \(why) after the last sentence")
            reachEnd()
            return
        }
        step("read: \(why) → sentence \(clamped + 1)")
        if isPaused {
            place(at: clamped)
        } else {
            playSentence(clamped)
        }
    }

    // MARK: iOS

    func systemPaused(_ why: String) {
        guard isRunning, !isPaused else { return }
        step("read: system pause: \(why)")
        pause(bySystem: true)
    }

    func systemResumed(_ why: String) {
        guard isRunning, isPaused, pausedBySystem else { return }
        resume(by: "system: \(why)")
    }

    // MARK: Following the sound

    /// Moves `sentenceIndex` to the sentence the sound is in. The session calls it a few times a second while it reads
    /// (the highlighted sentence, Now Playing, the saved place).
    func followSound() {
        guard phase == .reading, let current, let paragraph = currentParagraph else { return }
        let time = current.currentTime
        let sentences = paragraphs[paragraph].sentences
        // The last sentence that has started (its start at or before the sound's time).
        guard let inParagraph = sentences.lastIndex(where: { $0.start <= time + 0.01 }) else { return }
        let found = firstIndex(paragraph: paragraph) + inParagraph
        if found != sentenceIndex { setSentence(found) }
    }

    // MARK: Steps

    private func firstIndex(paragraph: Int) -> Int {
        positions.firstIndex { $0.paragraph == paragraph } ?? 0
    }

    private func setSentence(_ i: Int) {
        sentenceIndex = i
        onProgress?(i)
    }

    /// Moves the place without sound (while paused): the next 1 press starts there.
    private func place(at i: Int) {
        timer.cancel()
        current?.stop()
        current = nil
        currentParagraph = nil
        if phase == .atEnd || phase == .waitingForAudio { phase = .reading }
        setSentence(i)
    }

    private func playSentence(_ i: Int) {
        timer.cancel()
        let position = positions[i]
        setSentence(i)
        let sentence = paragraphs[position.paragraph].sentences[position.sentence]
        if currentParagraph == position.paragraph, let current {
            // The same file: only move in it.
            phase = .reading
            current.seek(to: sentence.start)
            current.play(until: nil)
            return
        }
        current?.stop()
        current = nil
        currentParagraph = nil
        guard let url = audioAt(position.paragraph) else {
            if phase != .waitingForAudio { step("read: waiting for the sound of paragraph \(position.paragraph + 1)") }
            phase = .waitingForAudio
            timer.start(seconds: Self.audioRetrySeconds) { [weak self] in
                guard let self, self.phase == .waitingForAudio, !self.isPaused, self.sentenceIndex == i else { return }
                self.playSentence(i)
            }
            return
        }
        phase = .reading
        do {
            let player = try source.player(for: url)
            failuresInARow = 0
            player.rate = Float(max(RepetitionPlayer.lowestVoiceRate, tempo))
            let paragraph = position.paragraph
            player.onFinish = { [weak self] in self?.paragraphEnded(paragraph) }
            current = player
            currentParagraph = paragraph
            if sentence.start > 0 { player.seek(to: sentence.start) }
            player.play(until: nil)
        } catch {
            failuresInARow += 1
            step("read: could not open \(url.lastPathComponent): \(error.localizedDescription)")
            // Skip the paragraph that will not open, but never spin: a whole text of them waits instead.
            let wait: Double = failuresInARow < max(paragraphs.count, 1) ? 1 : 30
            timer.start(seconds: wait) { [weak self] in
                guard let self, self.phase == .reading, !self.isPaused, self.current == nil else { return }
                self.afterParagraph(position.paragraph)
            }
        }
    }

    private func paragraphEnded(_ paragraph: Int) {
        guard phase == .reading, currentParagraph == paragraph else { return }
        current = nil
        currentParagraph = nil
        afterParagraph(paragraph)
    }

    private func afterParagraph(_ paragraph: Int) {
        guard let next = positions.firstIndex(where: { $0.paragraph > paragraph }) else {
            reachEnd()
            return
        }
        playSentence(next)
    }

    private func reachEnd() {
        timer.cancel()
        current?.stop()
        current = nil
        currentParagraph = nil
        phase = .atEnd
        isPaused = false
        pausedBySystem = false
        step("read: end of the text")
        // Next time the text starts from the beginning.
        onProgress?(0)
    }

    private func pause(bySystem: Bool) {
        isPaused = true
        pausedBySystem = bySystem
        timer.cancel()
        current?.pause()
        step(bySystem ? "read: paused by iOS" : "read: paused")
    }

    private func resume(by why: String) {
        let byUser = !pausedBySystem
        isPaused = false
        pausedBySystem = false
        step("read: go on (\(why))")
        guard phase != .atEnd else { return }
        if let current, byUser || phase != .reading {
            // D164: the user's pause goes on from the start of the sentence.
            current.seek(to: currentSentence?.start ?? 0)
            current.play(until: nil)
        } else if let current {
            // iOS's own short pause (a call, Siri) goes on from the word.
            current.play(until: nil)
        } else {
            playSentence(sentenceIndex)
        }
    }

    private func step(_ line: String) {
        Log.repetition.info("Reading: \(line, privacy: .public)")
        onStep?(line)
    }
}
