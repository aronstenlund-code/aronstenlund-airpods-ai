import Foundation

/// Which speech-to-text engine is in use: Scribe in the cloud (D44), else the on-device chain (D18).
enum STTEngine: String, Sendable, Equatable, CaseIterable {
    /// ElevenLabs Scribe v2 Realtime: audio goes to ElevenLabs. The consent text says so.
    case scribe
    /// `SpeechAnalyzer` + `SpeechTranscriber` (iOS 26, best quality, limited locales).
    case speechTranscriber
    /// `SpeechAnalyzer` + `DictationTranscriber` (keyboard-dictation locales).
    case dictationTranscriber
    /// `SFSpeechRecognizer` with `requiresOnDeviceRecognition = true`.
    case legacyOnDevice

    /// Audio stays on the phone.
    var isOnDevice: Bool { self != .scribe }

    var displayName: String {
        switch self {
        case .scribe: "Scribe"
        case .speechTranscriber: "SpeechTranscriber"
        case .dictationTranscriber: "DictationTranscriber"
        case .legacyOnDevice: "on-device SFSpeechRecognizer"
        }
    }
}

/// One recognition result. Partial (volatile) results replace each other until a final result closes the segment.
struct STTResult: Sendable, Equatable {
    var text: String
    var isFinal: Bool
    /// Audio time of the segment in seconds since the provider started, when the engine reports it.
    var audioStart: TimeInterval?
    var audioEnd: TimeInterval?
}

enum STTError: Error, Equatable, Sendable, LocalizedError {
    case languageUnsupported(locale: String)
    case onDeviceUnavailable(locale: String)
    case authorizationDenied
    case modelInstallFailed(detail: String)
    case audioFormat(detail: String)
    case startFailed(detail: String)

    var errorDescription: String? {
        switch self {
        case .languageUnsupported(let locale):
            "Speech recognition does not support \(locale) on this iPhone"
        case .onDeviceUnavailable(let locale):
            "On-device speech recognition is not available for \(locale) on this iPhone"
        case .authorizationDenied:
            "Speech recognition permission was denied"
        case .modelInstallFailed(let detail):
            "Could not install the speech model: \(detail)"
        case .audioFormat(let detail):
            "Audio format problem: \(detail)"
        case .startFailed(let detail):
            "Could not start speech recognition: \(detail)"
        }
    }
}

/// A speech-to-text engine fed with our 16 kHz mono Int16 chunks (D4).
@MainActor
protocol STTProvider: AnyObject {
    var engine: STTEngine { get }
    var locale: Locale { get }
    /// Partial and final results, in order. Ends when the provider is stopped.
    var results: AsyncStream<STTResult> { get }

    /// Checks support and installs the on-device model if needed (the first time this can take a while).
    func prepare() async throws(STTError)
    /// Starts recognising `audio` until the stream ends or `stop()` is called.
    func start(audio: AsyncStream<AudioChunk>) async throws(STTError)
    /// Finalises pending results and releases the engine. Idempotent.
    func stop() async
    /// Up to 100 short phrases (1–2 words) that bias recognition — prep topics (item 9). Applied at the next start.
    func setContextualStrings(_ strings: [String])
    /// Ask for the final result now (hold-to-ask released). Only Scribe has anything to do here.
    func commit()
}

extension STTProvider {
    func commit() {}
}

/// Where transcripts go (the Listening screen's model).
@MainActor
protocol TranscriptSink: AnyObject {
    func receivePartialTranscript(_ text: String, at date: Date)
    func receiveFinalTranscript(_ text: String, at date: Date)
}
