import Foundation

/// A voice the user can pick: Apple's on-device voice for the language, or one of the three allowlisted
/// ElevenLabs voices served by the backend (D23).
struct VoiceChoice: Equatable, Sendable, Codable, Identifiable, Hashable {
    enum Kind: String, Codable, Sendable {
        case apple
        case elevenLabs
    }

    var kind: Kind
    /// Apple: `AVSpeechSynthesisVoice.identifier` or "" for the language default. ElevenLabs: the voice id.
    var voiceID: String
    var name: String

    var id: String { "\(kind.rawValue):\(voiceID)" }

    static let appleDefault = VoiceChoice(kind: .apple, voiceID: "", name: "Apple")
}

enum TTSError: Error, Equatable, Sendable, LocalizedError {
    case noVoice(language: String)
    case audio(detail: String)
    /// Backend / network problem (reuses the answer path's error model).
    case network(AnswerError)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .noVoice(let language): "No voice installed for \(language)"
        case .audio(let detail): "Playback problem: \(detail)"
        case .network(let error): "Voice service: \(error.localizedDescription)"
        case .cancelled: "Cancelled"
        }
    }

    /// Fall back to Apple's voice for this sentence (quota, offline, backend down).
    var wantsFallback: Bool {
        switch self {
        case .network: true
        case .noVoice, .audio, .cancelled: false
        }
    }
}

/// Speaks one piece of text through `PlaybackService` (so it plays in the AirPods while capture runs).
/// `speak` returns once the audio has been fully scheduled; cancelling the task stops the request.
@MainActor
protocol TTSProvider: AnyObject {
    var name: String { get }
    func speak(_ text: String, language: TranscriptionLanguage, voice: VoiceChoice) async throws(TTSError)
}
