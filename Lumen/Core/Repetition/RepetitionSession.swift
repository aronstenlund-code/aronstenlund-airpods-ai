import AVFAudio
import Foundation
import MediaPlayer

/// D142 (A78): runs one `RepetitionPlayer` in the background with the screen locked.
///
/// - Audio session `.playback` (never `.playAndRecord`): no microphone, no orange dot, AirPods in A2DP (R9).
/// - Calls, Siri and alarms pause; the end of the interruption with `shouldResume` goes on from the same word.
/// - An AirPod out of the ear and AirPods gone (`oldDeviceUnavailable`) pause, never end (R8).
/// - Now Playing shows the question, so the Lock Screen's buttons work as the fallback for every AirPods model.
/// - Every input (`RepetitionInput`) goes to the player; Avsluta in the app is the only end.
@MainActor
@Observable
final class RepetitionSession {
    private(set) var player: RepetitionPlayer?
    /// A105 (D185): a text read aloud. At most one of `player` and `reader` runs.
    private(set) var reader: ReadingPlayer?
    private(set) var drill: Drill?
    /// The last steps, newest last, for the screen's small log line and Diagnostik.
    private(set) var steps: [String] = []

    private let inputs: [any RepetitionInput]
    private let makeSource: @MainActor () -> any RepetitionAudioSource
    private let makeTimer: @MainActor () -> any RepetitionTimer
    private let defaults: UserDefaults
    private let activatesAudioSession: Bool
    private var observers: [NSObjectProtocol] = []
    /// A105: moves the reader's sentence with the sound (the highlight, the Lock Screen, the saved place).
    private var follow: Task<Void, Never>?
    /// A108 (D194): a question played to its end, seconds read aloud, and an exam played through (any exam id).
    @ObservationIgnored var onQuestionPlayed: (@MainActor (UUID) -> Void)?
    @ObservationIgnored var onReadSeconds: (@MainActor (UUID, TimeInterval) -> Void)?
    @ObservationIgnored var onFinished: (@MainActor (UUID) -> Void)?
    /// A108: seconds read since they were last reported (reported every 10 s and at the end, not every tick).
    @ObservationIgnored private var unreportedReading: TimeInterval = 0
    @ObservationIgnored private var lastTick: Date?
    static let followInterval: Duration = .milliseconds(250)

    init(inputs: [any RepetitionInput],
         makeSource: @escaping @MainActor () -> any RepetitionAudioSource = { FileRepetitionAudioSource() },
         makeTimer: @escaping @MainActor () -> any RepetitionTimer = { TaskRepetitionTimer(keepsPlaying: true) },
         defaults: UserDefaults = .standard, activatesAudioSession: Bool = true) {
        self.inputs = inputs
        self.makeSource = makeSource
        self.makeTimer = makeTimer
        self.defaults = defaults
        self.activatesAudioSession = activatesAudioSession
    }

    var isActive: Bool { player?.isRunning == true || reader?.isRunning == true }

    /// A105 (D185, Ke63 §5): the sentence a text was left at, if any ("Fortsätt"); nil after the end.
    func savedSentence(for drill: Drill) -> Int? {
        guard let saved = ReadingProgress.load(drill.id, defaults), saved.sentence > 0,
              saved.sentence < drill.sentenceCount else { return nil }
        return saved.sentence
    }

    /// A105 (D185): reads `drill` (a text) from `sentence`. `audio` is asked at every part, so sound that arrives while
    /// it reads is used; a part without sound yet is waited for.
    func startReading(_ drill: Drill, at sentence: Int = 0, tempo: Double = 1, saying: SayOptions? = nil,
                      audio: @escaping @MainActor (Int) -> ReadingAudio?) {
        stop()
        // A115 (D203): "Säg i AirPods". The text goes round until the time is out; nothing is scheduled, and it only
        // ever plays with the player on the screen.
        self.saying = saying
        readingLap = 1
        repeatStarted = saying?.repeatMinutes == nil ? nil : now()
        let parts = drill.readingParts
        guard parts.contains(where: { !$0.sentences.isEmpty }) else { return }
        if activatesAudioSession { activatePlayback() }
        let reader = ReadingPlayer(parts: parts, audio: audio, source: makeSource(), timer: makeTimer(), startAt: sentence)
        reader.tempo = tempo
        let defaults = self.defaults
        let id = drill.id
        reader.onProgress = { [weak self] index in
            ReadingProgress.save(id, sentence: index, defaults)
            self?.updateNowPlaying()
        }
        reader.onStep = { [weak self] line in self?.record(line) }
        reader.onEnd = { [weak self, weak reader] in
            self?.reportReading()
            self?.onFinished?(id)
            // A115 (D203): "Upprepa i 10 min": the text starts over while time is left. The lap that is being read
            // when the time runs out is read to its end, and then it stops.
            if let self, let reader, self.repeatSecondsLeft > 0 {
                self.readingLap += 1
                self.record("Saying: lap \(self.readingLap)")
                reader.startOver()
            }
        }
        self.reader = reader
        self.drill = drill
        for input in inputs {
            input.onEvent = { [weak self] event in self?.press(event) }
            input.begin()
        }
        if activatesAudioSession { installObservers() }
        reader.start()
        ReadingProgress.save(id, sentence: reader.sentenceIndex, defaults)
        startFollowing()
        updateNowPlaying()
    }

    /// A105, Ke63 §3: a tap on a sentence on the screen.
    func read(from sentence: Int) {
        reader?.jump(to: sentence)
        updateNowPlaying()
    }

    /// A105, Ke63 "Börja om".
    func readFromStart() {
        reader?.startOver()
        updateNowPlaying()
    }

    private func startFollowing() {
        follow?.cancel()
        lastTick = Date()
        follow = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.followInterval)
                guard let self, !Task.isCancelled, let reader = self.reader else { return }
                reader.followSound()
                self.tick(reading: reader.phase == .reading && !reader.isPaused)
            }
        }
    }

    /// A108: counts the time the text is actually read aloud (not paused, not waiting for sound).
    func tick(reading: Bool, now: Date = Date()) {
        defer { lastTick = now }
        guard reading, let lastTick else { return }
        unreportedReading += min(max(now.timeIntervalSince(lastTick), 0), 5) // a long gap is a suspended app
        if unreportedReading >= 10 { reportReading() }
    }

    private func reportReading() {
        guard unreportedReading > 0, let id = drill?.id else { return }
        let seconds = unreportedReading
        unreportedReading = 0
        onReadSeconds?(id, seconds)
    }

    /// "Fortsätt där du var?": the saved question for this exam, if the last run was this exam.
    func savedIndex(for drill: Drill) -> Int? {
        guard let saved = RepetitionProgress.load(defaults), saved.drillID == drill.id,
              saved.index > 0, saved.index < drill.items.count else { return nil }
        return saved.index
    }

    func start(_ drill: Drill, tracks: [RepetitionTrack], at index: Int = 0) {
        start(drill, count: tracks.count, at: index) { tracks.indices.contains($0) ? tracks[$0] : nil }
    }

    /// `track` is asked at every question, so sound that arrives while the list plays is used (K46 makes it in play
    /// order); a question without sound yet is waited for.
    func start(_ drill: Drill, count: Int, at index: Int = 0, onePressPausesAnswer: Bool = false,
               firstLap: Bool = false, cue: URL? = nil, tempo: Double = 1,
               pauseMusic: (any RepetitionPauseMusic)? = nil,
               track: @escaping @MainActor (Int) -> RepetitionTrack?) {
        stop()
        guard count > 0 else { return }
        if activatesAudioSession { activatePlayback() }
        let thinking = ThinkingTime.seconds(questionCount: count, defaults: defaults)
        let player = RepetitionPlayer(count: count, track: track, source: makeSource(), timer: makeTimer(),
                                      thinkingSeconds: thinking, startAt: index)
        player.onePressPausesAnswer = onePressPausesAnswer
        player.isFirstLap = firstLap
        player.tempo = tempo
        player.pauseMusic = pauseMusic
        player.cue = firstLap ? cue : nil
        let defaults = self.defaults
        let id = drill.id
        player.onProgress = { next in RepetitionProgress(drillID: id, index: next, savedAt: Date()).save(defaults) }
        player.onStep = { [weak self] line in self?.record(line) }
        player.onQuestionPlayed = { [weak self] _ in self?.onQuestionPlayed?(id) } // A108
        player.onLapDone = { [weak self] _ in self?.onFinished?(id) }
        self.player = player
        self.drill = drill
        for input in inputs {
            input.onEvent = { [weak self] event in self?.press(event) }
            input.begin()
        }
        if activatesAudioSession { installObservers() }
        player.start()
        RepetitionProgress(drillID: id, index: player.index, savedAt: Date()).save(defaults)
        updateNowPlaying()
    }

    /// The phone's own buttons on the playing screen use the same path as AirPods.
    /// A112b (D200): the next or the previous question by hand, while the player waits for a sound.
    func stepQuestion(by delta: Int) {
        player?.stepByHand(delta)
        updateNowPlaying()
    }

    func press(_ event: RepetitionEvent) {
        player?.handle(event)
        reader?.handle(event)
        updateNowPlaying()
    }

    /// Avsluta.
    /// A115 (D203): how "Säg i AirPods" reads: once, or round and round for some minutes.
    struct SayOptions: Equatable, Sendable {
        /// Nil = once ("En gång"); else "Upprepa i 5, 10, 20 min".
        var repeatMinutes: Int?
    }

    /// A115: set while a text from "Säg i AirPods" is read (the player then says "Spelar i AirPods" and shows the lap).
    private(set) var saying: SayOptions?
    private(set) var readingLap = 1
    private var repeatStarted: Date?
    /// The clock (tests set it).
    @ObservationIgnored var now: @MainActor () -> Date = { Date() }

    /// A115: seconds left of the repetition; 0 when it reads once or the time is out.
    var repeatSecondsLeft: TimeInterval {
        guard let minutes = saying?.repeatMinutes, let repeatStarted else { return 0 }
        return max(0, Double(minutes) * 60 - now().timeIntervalSince(repeatStarted))
    }

    func stop() {
        guard player != nil || reader != nil else { return }
        saying = nil
        repeatStarted = nil
        readingLap = 1
        reportReading()
        player?.stop()
        player = nil
        follow?.cancel()
        follow = nil
        reader?.stop()
        reader = nil
        drill = nil
        for input in inputs { input.end(); input.onEvent = nil }
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        observers = []
        if activatesAudioSession {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    // MARK: iOS

    private func activatePlayback() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .spokenAudio, options: [])
            try session.setActive(true)
            record("audio session .playback active")
        } catch {
            record("audio session failed: \(error.localizedDescription)")
        }
    }

    private func installObservers() {
        let center = NotificationCenter.default
        let session = AVAudioSession.sharedInstance()
        observers.append(center.addObserver(forName: AVAudioSession.interruptionNotification, object: session, queue: .main) { [weak self] note in
            let typeRaw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt ?? UInt.max
            let optionsRaw = note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            MainActor.assumeIsolated { self?.interruption(typeRaw: typeRaw, optionsRaw: optionsRaw) }
        })
        observers.append(center.addObserver(forName: AVAudioSession.routeChangeNotification, object: session, queue: .main) { [weak self] note in
            let reasonRaw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt ?? UInt.max
            MainActor.assumeIsolated { self?.routeChanged(reasonRaw: reasonRaw) }
        })
    }

    func interruption(typeRaw: UInt, optionsRaw: UInt) {
        switch AVAudioSession.InterruptionType(rawValue: typeRaw) {
        case .began?:
            player?.systemPaused("interruption")
            reader?.systemPaused("interruption")
        case .ended?:
            if AVAudioSession.InterruptionOptions(rawValue: optionsRaw).contains(.shouldResume) {
                if activatesAudioSession { try? AVAudioSession.sharedInstance().setActive(true) }
                player?.systemResumed("interruption ended")
                reader?.systemResumed("interruption ended")
            } else {
                record("interruption ended without shouldResume: waits for a press")
            }
        default:
            break
        }
        updateNowPlaying()
    }

    func routeChanged(reasonRaw: UInt) {
        // An AirPod out of the ear and AirPods gone both arrive as oldDeviceUnavailable (untested on device which).
        if AVAudioSession.RouteChangeReason(rawValue: reasonRaw) == .oldDeviceUnavailable {
            player?.systemPaused("output gone")
            reader?.systemPaused("output gone")
            updateNowPlaying()
        }
    }

    /// A105, Kelly Ke63 §4.3: title = the heading the reader is under (the exam's name without one), artist =
    /// "EarMind · <exam> · mening 5 av 9". The title changes only with the heading, so the Lock Screen does not blink.
    static func readingNowPlaying(_ reader: ReadingPlayer, title: String) -> (title: String, artist: String) {
        let n = min(reader.sentenceIndex + 1, reader.sentenceCount)
        return (reader.currentHeading ?? title, "EarMind · \(title) · mening \(n) av \(reader.sentenceCount)")
    }

    private func updateNowPlaying() {
        if activatesAudioSession, let reader, let drill {
            let shown = Self.readingNowPlaying(reader, title: drill.title)
            MPNowPlayingInfoCenter.default().nowPlayingInfo = [
                MPMediaItemPropertyTitle: shown.title,
                MPMediaItemPropertyArtist: shown.artist,
                MPMediaItemPropertyAlbumTitle: drill.title,
                MPNowPlayingInfoPropertyPlaybackRate: reader.isPaused || reader.phase != .reading ? 0.0 : 1.0,
            ]
            return
        }
        guard activatesAudioSession, let player, let drill else { return }
        let item = drill.items.indices.contains(player.index) ? drill.items[player.index] : nil
        // Kelly Ke49 "Låsskärmen": title = the question, artist = "EarMind · <exam> · 7 av 20".
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: item?.question ?? drill.title,
            MPMediaItemPropertyArtist: "EarMind · \(drill.title) · \(player.index + 1) av \(player.count)",
            MPMediaItemPropertyAlbumTitle: drill.title,
            MPNowPlayingInfoPropertyPlaybackRate: player.isPaused ? 0.0 : 1.0,
        ]
    }

    private func record(_ line: String) {
        steps.append(line)
        if steps.count > 40 { steps.removeFirst(steps.count - 40) }
        if line.hasPrefix("question") || line.hasPrefix("waiting") { updateNowPlaying() }
    }
}

#if DEBUG
extension RepetitionSession {
    /// The Simulator screenshots: a session that shows `drill` without sound, Now Playing or the AirPods.
    func stageForScreenshot(_ drill: Drill, player: RepetitionPlayer) {
        self.player = player
        self.drill = drill
    }

    /// A115's screenshots: a text from "Säg i AirPods" on its third lap of ten minutes.
    func stageSaying(_ drill: Drill, reader: ReadingPlayer, minutes: Int?, lap: Int) {
        self.reader = reader
        self.drill = drill
        saying = SayOptions(repeatMinutes: minutes)
        readingLap = lap
        repeatStarted = minutes == nil ? nil : now().addingTimeInterval(-168) // 7:12 left of 10 min
    }

    /// A106's screenshots: a text being read, without sound, Now Playing or the AirPods.
    func stageForScreenshot(_ drill: Drill, reader: ReadingPlayer) {
        self.reader = reader
        self.drill = drill
    }
}
#endif
