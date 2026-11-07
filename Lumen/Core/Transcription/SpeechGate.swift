import Foundation

/// Scribe's own pause detection per mode (D78). Query parameters from ElevenLabs "Transcripts and commit
/// strategies": `vad_silence_threshold_secs` (0.192–3.0), `vad_threshold`, `min_speech_duration_ms`,
/// `min_silence_duration_ms`. `filter_background_audio=true` comes from the backend's `extra_query`; it cannot be
/// combined with `include_timestamps`, which the app never sets. Starting values, to tune with the Diagnostics export.
struct ScribeTuning: Equatable, Sendable {
    var silenceSeconds: Double
    var threshold: Double
    var minSpeechMs = 100
    var minSilenceMs = 100

    static func forMode(_ mode: ConversationMode) -> ScribeTuning {
        switch mode {
        case .standard: ScribeTuning(silenceSeconds: 1.0, threshold: 0.15)
        case .prov: ScribeTuning(silenceSeconds: 1.2, threshold: 0.3) // the wearer's own voice, close to the mic
        case .interview: ScribeTuning(silenceSeconds: 1.5, threshold: 0.15)
        case .social, .rizz: ScribeTuning(silenceSeconds: 0.8, threshold: 0.15)
        }
    }

    static let standard = forMode(.standard)

    var queryItems: [URLQueryItem] {
        [URLQueryItem(name: "vad_silence_threshold_secs", value: String(format: "%.2f", min(3.0, max(0.2, silenceSeconds)))),
         URLQueryItem(name: "vad_threshold", value: String(format: "%.2f", threshold)),
         URLQueryItem(name: "min_speech_duration_ms", value: String(minSpeechMs)),
         URLQueryItem(name: "min_silence_duration_ms", value: String(minSilenceMs))]
    }
}

/// A local voice activity detector (Silero via FluidAudio, OSS-2): the speech probability of one 256 ms window.
protocol VoiceActivityDetecting: Sendable {
    func speechProbability(_ window: [Float]) async throws -> Float
    func reset() async
}

/// Lets only speech through to Scribe (D78): silence and noise are not sent, so Scribe gets fewer false starts and
/// clearer ends, and fewer seconds are billed. Opens on speech with a short pre-roll, stays open through pauses long
/// enough for Scribe to commit on its own, then closes. Pure; unit-tested.
struct SpeechGate: Sendable {
    /// Silero's window: 4096 samples at 16 kHz = 256 ms.
    static let windowSamples = 4_096
    static let windowSeconds = Double(windowSamples) / LumenAudioFormat.sampleRate

    var openThreshold: Float = 0.5
    var closeThreshold: Float = 0.35
    /// Windows kept from before the speech started, so the first word is not cut.
    var preRollWindows = 2
    /// Quiet windows sent after the speech, so Scribe sees its own silence threshold and commits.
    private(set) var hangoverWindows: Int

    private(set) var isOpen = false
    private var preRoll: [[Int16]] = []
    private var quietWindows = 0
    private var pending: [Int16] = []

    init(scribeSilence: Double) {
        hangoverWindows = Self.hangover(for: scribeSilence)
    }

    static func hangover(for scribeSilence: Double) -> Int {
        Int(((scribeSilence + 0.3) / windowSeconds).rounded(.up))
    }

    mutating func setScribeSilence(_ seconds: Double) {
        hangoverWindows = Self.hangover(for: seconds)
    }

    /// Collects capture chunks into whole windows.
    mutating func collect(_ samples: [Int16]) -> [[Int16]] {
        pending += samples
        var windows: [[Int16]] = []
        while pending.count >= Self.windowSamples {
            windows.append(Array(pending.prefix(Self.windowSamples)))
            pending.removeFirst(Self.windowSamples)
        }
        return windows
    }

    /// One window and its speech probability → the audio to send now (possibly with the pre-roll in front).
    mutating func decide(_ window: [Int16], probability: Float) -> [Int16] {
        if isOpen {
            quietWindows = probability < closeThreshold ? quietWindows + 1 : 0
            if quietWindows > hangoverWindows {
                isOpen = false
                quietWindows = 0
                preRoll = [window]
                return []
            }
            return window
        }
        if probability >= openThreshold {
            isOpen = true
            quietWindows = 0
            let out = preRoll.flatMap { $0 } + window
            preRoll = []
            return out
        }
        preRoll.append(window)
        if preRoll.count > preRollWindows { preRoll.removeFirst(preRoll.count - preRollWindows) }
        return []
    }

    mutating func reset() {
        isOpen = false
        preRoll = []
        quietWindows = 0
        pending = []
    }

    static func floats(_ window: [Int16]) -> [Float] {
        window.map { Float($0) / 32_768 }
    }
}
