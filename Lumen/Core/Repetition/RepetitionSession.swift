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
    private(set) var drill: Drill?
    /// The last steps, newest last, for the screen's small log line and Diagnostik.
    private(set) var steps: [String] = []

    private let inputs: [any RepetitionInput]
    private let makeSource: @MainActor () -> any RepetitionAudioSource
    private let makeTimer: @MainActor () -> any RepetitionTimer
    private let defaults: UserDefaults
    private let activatesAudioSession: Bool
    private var observers: [NSObjectProtocol] = []

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

    var isActive: Bool { player?.isRunning == true }

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
        player.cue = firstLap ? cue : nil
        let defaults = self.defaults
        let id = drill.id
        player.onProgress = { next in RepetitionProgress(drillID: id, index: next, savedAt: Date()).save(defaults) }
        player.onStep = { [weak self] line in self?.record(line) }
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
    func press(_ event: RepetitionEvent) {
        player?.handle(event)
        updateNowPlaying()
    }

    /// Avsluta.
    func stop() {
        guard player != nil else { return }
        player?.stop()
        player = nil
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
        case .ended?:
            if AVAudioSession.InterruptionOptions(rawValue: optionsRaw).contains(.shouldResume) {
                if activatesAudioSession { try? AVAudioSession.sharedInstance().setActive(true) }
                player?.systemResumed("interruption ended")
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
            updateNowPlaying()
        }
    }

    private func updateNowPlaying() {
        guard activatesAudioSession, let player, let drill else { return }
        let item = drill.items.indices.contains(player.index) ? drill.items[player.index] : nil
        // Kelly Ke49 "Låsskärmen": title = the question, artist = "Earmind · <exam> · 7 av 20".
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: item?.question ?? drill.title,
            MPMediaItemPropertyArtist: "Earmind · \(drill.title) · \(player.index + 1) av \(player.count)",
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
}
#endif
