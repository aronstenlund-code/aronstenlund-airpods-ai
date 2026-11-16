import Foundation
import Observation

/// D185 (A105): a part of a read-aloud text as the screen shows it: a heading (one sentence) or a paragraph.
struct ReadingParagraph: Equatable, Sendable {
    var sentences: [String]
    var isHeading: Bool = false
}

/// D185, K70: a part's downloaded file and where each of its sentences starts and ends in it (seconds at normal
/// speed, from the server's `audio.text.sentences`).
struct ReadingAudio: Equatable, Sendable {
    var url: URL
    var times: [ClosedRange<TimeInterval>]

    /// Where sentence `i` starts. K70 promises as many times as sentences; a missing one starts at the last known
    /// start (never past the file), so a short list can only replay, never skip.
    func start(of i: Int) -> TimeInterval {
        guard !times.isEmpty else { return 0 }
        return times[min(max(i, 0), times.count - 1)].lowerBound
    }
}

/// D185 (A105): where a text was left, per text ("Fortsätt" starts there, Kelly Ke63 §5).
struct ReadingProgress: Codable, Equatable, Sendable {
    var sentence: Int
    var savedAt: Date

    static let key = "earmind.reading.progress"

    static func load(_ drillID: UUID, _ defaults: UserDefaults) -> ReadingProgress? {
        all(defaults)[drillID.uuidString]
    }

    static func save(_ drillID: UUID, sentence: Int, _ defaults: UserDefaults, now: Date = Date()) {
        var all = all(defaults)
        all[drillID.uuidString] = ReadingProgress(sentence: sentence, savedAt: now)
        if all.count > 50 {
            // Only the 50 latest texts are remembered.
            for key in all.sorted(by: { $0.value.savedAt > $1.value.savedAt }).dropFirst(50).map(\.key) {
                all[key] = nil
            }
        }
        if let data = try? JSONEncoder().encode(all) { defaults.set(data, forKey: key) }
    }

    static func clear(_ drillID: UUID, _ defaults: UserDefaults) {
        var all = all(defaults)
        all[drillID.uuidString] = nil
        if let data = try? JSONEncoder().encode(all) { defaults.set(data, forKey: key) }
    }

    private static func all(_ defaults: UserDefaults) -> [String: ReadingProgress] {
        guard let data = defaults.data(forKey: key) else { return [:] }
        return (try? JSONDecoder().decode([String: ReadingProgress].self, from: data)) ?? [:]
    }
}

/// D185 (A105): the reading mode's player. A text is parts (headings and paragraphs) of sentences; each part is one
/// file. No microphone, only files and presses, like `RepetitionPlayer`.
///
/// The AirPods, Control Center, the Lock Screen and the screen's buttons all send the three events of D142, which
/// mean what they mean in an ordinary player (Play/Pause, Next track, Previous track):
/// - 1 press (`.long`): pause, and 1 press again goes on **from the start of the sentence** (D164);
/// - 2 presses (`.short`): the next sentence (the next part's first after a part's last);
/// - 3 presses (`.pauseToggle`): the previous sentence, never before the first.
///
/// While paused, 2 and 3 presses move the place and stay paused; the next 1 press reads from there. A tap on a sentence
/// reads from it, also when paused (Kelly Ke63 §3). After the last sentence the text stops (`atEnd`, Ke63 "Slut på
/// texten"): 1 press = Börja om, 3 presses = the last sentence, 2 presses nothing. Only `stop()` (Avsluta) ends it.
///
/// A part whose sound is not downloaded is waited for in silence (`waitingForAudio`); with A103 everything downloaded
/// plays without network.
@MainActor
@Observable
final class ReadingPlayer {
    enum Phase: Equatable, Sendable {
        case idle
        case reading
        /// The part's sound is not on the phone yet; looked for again every `audioRetrySeconds`.
        case waitingForAudio
        /// After the last sentence (Ke63 "Slut på texten").
        case atEnd
    }

    struct Position: Equatable, Sendable {
        var part: Int
        var sentence: Int
    }

    private(set) var phase: Phase = .idle
    private(set) var isPaused = false
    /// Why it paused: a press, or iOS (a call, Siri, an AirPod out). Only iOS's own pause comes back by itself.
    private(set) var pausedBySystem = false
    /// The sentence being read, or to start from, counted through the whole text (0-based): "Mening 5 av 9".
    private(set) var sentenceIndex: Int

    let parts: [ReadingParagraph]
    /// Part and sentence of every sentence number.
    let positions: [Position]
    /// A84 (D151): the chosen tempo, as for the questions (the voice never under 0.7).
    var tempo: Double = 1
    /// Called when the sentence changes, with the sentence to come back to; 0 after the end (next time from the start).
    var onProgress: (@MainActor (Int) -> Void)?
    /// Every step as one line, for the log and the Simulator tests.
    var onStep: (@MainActor (String) -> Void)?
    /// A108 (D194): the text was read to its end.
    var onEnd: (@MainActor () -> Void)?

    static let audioRetrySeconds = 1.0

    private let audioAt: @MainActor (Int) -> ReadingAudio?
    private let source: any RepetitionAudioSource
    private let timer: any RepetitionTimer
    private var current: (any RepetitionAudioPlayer)?
    /// The part `current` plays, and its sentence times.
    private var currentPart: Int?
    private var currentAudio: ReadingAudio?
    private var failuresInARow = 0

    /// `audio` gives a part's file and times, or nil while it is not downloaded; asked each time a part begins.
    init(parts: [ReadingParagraph], audio: @escaping @MainActor (Int) -> ReadingAudio?,
         source: any RepetitionAudioSource, timer: any RepetitionTimer, startAt: Int = 0) {
        self.parts = parts
        self.positions = parts.enumerated().flatMap { p, part in
            part.sentences.indices.map { Position(part: p, sentence: $0) }
        }
        self.audioAt = audio
        self.source = source
        self.timer = timer
        self.sentenceIndex = positions.isEmpty ? 0 : min(max(startAt, 0), positions.count - 1)
    }

    var sentenceCount: Int { positions.count }
    var isRunning: Bool { phase != .idle }
    var isAtEnd: Bool { phase == .atEnd }

    /// The part being read.
    var position: Position? { positions.indices.contains(sentenceIndex) ? positions[sentenceIndex] : nil }

    var currentSentence: String? {
        guard let position else { return nil }
        return parts[position.part].sentences[position.sentence]
    }

    /// Ke63: the heading the reader is under ("Mening 5 av 9" and the heading; the Lock Screen's title). Nil before
    /// the first heading and in a text without headings.
    var currentHeading: String? {
        guard let position else { return nil }
        return parts[...position.part].last(where: \.isHeading)?.sentences.joined(separator: " ")
    }

    func start() {
        guard !positions.isEmpty, phase == .idle else { return }
        step("start at sentence \(sentenceIndex + 1) of \(positions.count)")
        read(from: sentenceIndex)
    }

    /// Avsluta: the place is kept by `onProgress`.
    func stop() {
        timer.cancel()
        drop()
        phase = .idle
        isPaused = false
        pausedBySystem = false
        step("stop")
    }

    // MARK: Presses

    func handle(_ event: RepetitionEvent) {
        guard isRunning else { return }
        switch event {
        case .long: playPause()
        case .short: move(by: 1)
        case .pauseToggle: move(by: -1)
        }
    }

    /// Ke63 §3: a tap on a sentence reads from it, also when paused.
    func jump(to sentence: Int) {
        guard isRunning, positions.indices.contains(sentence) else { return }
        isPaused = false
        pausedBySystem = false
        step("tap on sentence \(sentence + 1)")
        read(from: sentence)
    }

    /// Ke63 "Börja om" on the end screen (the same as 1 press there).
    func startOver() {
        guard isRunning else { return }
        isPaused = false
        pausedBySystem = false
        step("from the beginning")
        read(from: 0)
    }

    private func playPause() {
        if phase == .atEnd { startOver(); return }
        if isPaused { resume(by: "press") } else { pause(bySystem: false) }
    }

    private func move(by delta: Int) {
        let target = sentenceIndex + delta
        if phase == .atEnd {
            // 2 presses at the end do nothing; 3 presses read the last sentence again.
            guard delta < 0 else { return }
            step("previous from the end")
            read(from: positions.count - 1)
            return
        }
        if target >= positions.count {
            step("next after the last sentence")
            reachEnd()
            return
        }
        let clamped = max(target, 0)
        step("\(delta > 0 ? "next" : "previous") → sentence \(clamped + 1)")
        if isPaused {
            // Stays paused: the next 1 press reads from here.
            place(at: clamped)
        } else {
            read(from: clamped)
        }
    }

    // MARK: iOS

    /// A call, Siri, an alarm, an AirPod out of the ear or AirPods gone: pause, never end.
    func systemPaused(_ why: String) {
        guard isRunning, !isPaused, phase != .atEnd else { return }
        step("system pause: \(why)")
        pause(bySystem: true)
    }

    /// An interruption ended with `shouldResume`: only a pause iOS made comes back by itself.
    func systemResumed(_ why: String) {
        guard isRunning, isPaused, pausedBySystem else { return }
        resume(by: "system: \(why)")
    }

    // MARK: Following the sound

    /// Moves `sentenceIndex` to the sentence the sound is in. The session calls it a few times a second while reading
    /// (the highlighted sentence, the Lock Screen, the saved place).
    func followSound() {
        guard phase == .reading, !isPaused, let current, let part = currentPart, let audio = currentAudio else { return }
        let time = current.currentTime
        // Only sentences with a time of their own: without times the place stays where the presses put it.
        let known = min(parts[part].sentences.count, audio.times.count)
        guard known > 0, let inPart = (0..<known).last(where: { audio.start(of: $0) <= time + 0.01 }) else { return }
        let found = firstSentence(of: part) + inPart
        if found != sentenceIndex { setSentence(found) }
    }

    // MARK: Steps

    private func firstSentence(of part: Int) -> Int {
        positions.firstIndex { $0.part == part } ?? 0
    }

    private func setSentence(_ i: Int) {
        sentenceIndex = i
        onProgress?(i)
    }

    private func drop() {
        current?.stop()
        current = nil
        currentPart = nil
        currentAudio = nil
    }

    /// Moves the place without sound (while paused).
    private func place(at i: Int) {
        timer.cancel()
        drop()
        if phase != .reading { phase = .reading }
        setSentence(i)
    }

    private func read(from i: Int) {
        timer.cancel()
        let position = positions[i]
        setSentence(i)
        if currentPart == position.part, let current, let audio = currentAudio {
            // The same file: only move in it.
            phase = .reading
            current.seek(to: audio.start(of: position.sentence))
            current.play(until: nil)
            return
        }
        drop()
        guard let audio = audioAt(position.part) else {
            if phase != .waitingForAudio { step("waiting for the sound of part \(position.part + 1)") }
            phase = .waitingForAudio
            timer.start(seconds: Self.audioRetrySeconds) { [weak self] in
                guard let self, self.phase == .waitingForAudio, !self.isPaused, self.sentenceIndex == i else { return }
                self.read(from: i)
            }
            return
        }
        phase = .reading
        do {
            let player = try source.player(for: audio.url)
            failuresInARow = 0
            player.rate = Float(max(RepetitionPlayer.lowestVoiceRate, tempo))
            let part = position.part
            player.onFinish = { [weak self] in self?.partEnded(part) }
            current = player
            currentPart = part
            currentAudio = audio
            let start = audio.start(of: position.sentence)
            if start > 0 { player.seek(to: start) }
            player.play(until: nil)
        } catch {
            failuresInARow += 1
            step("could not open \(audio.url.lastPathComponent): \(error.localizedDescription)")
            // The part is skipped after a second; a whole text that will not open waits longer instead of spinning.
            let wait: Double = failuresInARow < max(parts.count, 1) ? 1 : 30
            timer.start(seconds: wait) { [weak self] in
                guard let self, self.phase == .reading, !self.isPaused, self.current == nil else { return }
                if wait > 1 { self.failuresInARow = 0 }
                self.afterPart(position.part)
            }
        }
    }

    private func partEnded(_ part: Int) {
        guard phase == .reading, currentPart == part else { return }
        current = nil
        currentPart = nil
        currentAudio = nil
        afterPart(part)
    }

    private func afterPart(_ part: Int) {
        guard let next = positions.firstIndex(where: { $0.part > part }) else {
            reachEnd()
            return
        }
        read(from: next)
    }

    private func reachEnd() {
        timer.cancel()
        drop()
        phase = .atEnd
        isPaused = false
        pausedBySystem = false
        step("end of the text")
        onEnd?()
        // The next start begins from the beginning (Ke63: the text does not go round by itself).
        onProgress?(0)
    }

    private func pause(bySystem: Bool) {
        isPaused = true
        pausedBySystem = bySystem
        timer.cancel()
        current?.pause()
        step(bySystem ? "paused by iOS" : "paused")
    }

    private func resume(by why: String) {
        let byUser = !pausedBySystem
        isPaused = false
        pausedBySystem = false
        step("go on (\(why))")
        guard phase == .reading, let current else {
            read(from: sentenceIndex)
            return
        }
        if byUser, let position, let audio = currentAudio {
            // D164: the user's pause goes on from the start of the sentence; iOS's own short pause from the word.
            current.seek(to: audio.start(of: position.sentence))
        }
        current.play(until: nil)
    }

    private func step(_ line: String) {
        Log.repetition.info("Reading: \(line, privacy: .public)")
        onStep?(line)
    }
}

#if DEBUG
extension ReadingPlayer {
    /// The Simulator screenshots (A106): the player in a given state, without sound or timers.
    func stageForScreenshot(_ phase: Phase, sentence: Int, paused: Bool = false) {
        self.phase = phase
        self.sentenceIndex = min(max(sentence, 0), max(positions.count - 1, 0))
        self.isPaused = paused
    }
}
#endif
