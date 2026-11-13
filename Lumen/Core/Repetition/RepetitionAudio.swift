import AVFAudio
import Foundation

/// D142 §4: the repetition plays saved files, never a stream, so a pause goes on from the same sample. Tests give a
/// mock with known lengths and no sound (0 ElevenLabs characters in CI).
@MainActor
protocol RepetitionAudioPlayer: AnyObject {
    /// Called once when the file (or the part up to `until`) has played to its end. Never after `stop()`.
    var onFinish: (@MainActor () -> Void)? { get set }
    var currentTime: TimeInterval { get }
    /// Plays from the current position; `until` stops there and counts as the end (D145's short answer).
    func play(until: TimeInterval?)
    func pause()
    func stop()
}

@MainActor
protocol RepetitionAudioSource: AnyObject {
    func player(for url: URL) throws -> any RepetitionAudioPlayer
}

/// The thinking time between a question and the next one.
@MainActor
protocol RepetitionTimer: AnyObject {
    func start(seconds: Double, _ fire: @escaping @MainActor () -> Void)
    func cancel()
}

// MARK: - Live

@MainActor
final class FileRepetitionAudioSource: RepetitionAudioSource {
    func player(for url: URL) throws -> any RepetitionAudioPlayer {
        try FileRepetitionPlayer(url: url)
    }
}

/// `AVAudioPlayer` per file. The end is watched by a short poll instead of a delegate: a player that iOS paused (call,
/// Siri) must not count as finished, and the poll knows the difference because only it ends the file.
@MainActor
final class FileRepetitionPlayer: RepetitionAudioPlayer {
    var onFinish: (@MainActor () -> Void)?
    private let player: AVAudioPlayer
    private var watch: Task<Void, Never>?
    private var until: TimeInterval?
    private var stopped = false
    /// The end counts only after the player was seen playing (it can read "not playing, at 0" right after `play`).
    private var sawPlaying = false

    init(url: URL) throws {
        player = try AVAudioPlayer(contentsOf: url)
        player.prepareToPlay()
    }

    var currentTime: TimeInterval { player.currentTime }

    func play(until: TimeInterval?) {
        guard !stopped else { return }
        self.until = until
        sawPlaying = false
        player.play()
        watch?.cancel()
        watch = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(40))
                guard let self, !Task.isCancelled else { return }
                if self.reachedEnd() { self.finish(); return }
            }
        }
    }

    func pause() {
        watch?.cancel()
        watch = nil
        player.pause()
    }

    func stop() {
        stopped = true
        watch?.cancel()
        watch = nil
        onFinish = nil
        player.stop()
    }

    private func reachedEnd() -> Bool {
        if player.isPlaying { sawPlaying = true }
        if let until, player.currentTime >= until { return true }
        guard sawPlaying else { return false }
        // AVAudioPlayer stops at the end and rewinds to 0; a pause by iOS keeps the position.
        return !player.isPlaying && (player.currentTime == 0 || player.currentTime >= player.duration - 0.05)
    }

    private func finish() {
        watch = nil
        if until != nil { player.pause() }
        let done = onFinish
        onFinish = nil
        done?()
    }
}

@MainActor
final class TaskRepetitionTimer: RepetitionTimer {
    private var task: Task<Void, Never>?
    /// D148: the thinking time is part of what plays. With the screen locked iOS suspends an audio app soon after its
    /// sound stops, and a suspended app's timer never fires, so the next question would never come. A silent file
    /// plays while the timer runs. It never plays during a pause (3 presses): the timer is cancelled then, and iOS
    /// wakes the app for the next press like a paused podcast (spec §3, guideline 2.5.4).
    private let keepsPlaying: Bool
    private var silence: AVAudioPlayer?

    init(keepsPlaying: Bool = false) {
        self.keepsPlaying = keepsPlaying
    }

    func start(seconds: Double, _ fire: @escaping @MainActor () -> Void) {
        task?.cancel()
        if keepsPlaying { playSilence() }
        task = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(Int(seconds * 1000)))
            guard !Task.isCancelled else { return }
            self?.silence?.stop()
            fire()
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
        silence?.stop()
    }

    private func playSilence() {
        if silence == nil, let url = Self.silenceFile() {
            silence = try? AVAudioPlayer(contentsOf: url)
            silence?.numberOfLoops = -1
            silence?.prepareToPlay()
        }
        silence?.currentTime = 0
        silence?.play()
    }

    /// One second of silence, written once to Caches.
    static func silenceFile() -> URL? {
        guard let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return nil }
        let url = caches.appendingPathComponent("repetition-silence-1s.wav")
        if FileManager.default.fileExists(atPath: url.path) { return url }
        do {
            try WAVWriter.write(samples: [Int16](repeating: 0, count: 22_050), sampleRate: 22_050, to: url)
            return url
        } catch {
            return nil
        }
    }
}
