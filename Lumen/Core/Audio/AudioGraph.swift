import AVFAudio

/// Owns the single `AVAudioEngine` shared by capture (input tap) and playback (player node).
/// Main-actor only; the engine itself is not Sendable.
@MainActor
final class AudioGraph {
    private(set) var engine = AVAudioEngine()

    /// Called after `rebuild()` so attached nodes (playback) can re-attach to the new engine.
    var onRebuild: (@MainActor () -> Void)?

    var isRunning: Bool { engine.isRunning }

    /// Starts the engine if needed. Callers must have activated the audio session first.
    func ensureRunning() throws(AudioError) {
        guard !engine.isRunning else { return }
        engine.prepare()
        do {
            try engine.start()
        } catch {
            throw .engineStart(detail: error.localizedDescription)
        }
        Log.session.info("AVAudioEngine started")
    }

    func stop() {
        guard engine.isRunning else { return }
        engine.stop()
        Log.session.info("AVAudioEngine stopped")
    }

    /// After a media-services reset the engine must be discarded and recreated (Apple docs); taps and
    /// attached nodes are gone with it.
    func rebuild() {
        engine.stop()
        engine = AVAudioEngine()
        Log.session.warning("AVAudioEngine rebuilt after media services reset")
        onRebuild?()
    }
}
