import AVFAudio
import Foundation

/// `AVSpeechSynthesizer.write` → our engine (PlaybackService). Always available; the fallback for every other voice.
@MainActor
final class AppleTTSProvider: TTSProvider {
    let name = "apple"
    private let playback: any PlaybackServicing

    init(playback: any PlaybackServicing) {
        self.playback = playback
    }

    func speak(_ text: String, language: TranscriptionLanguage, voice: VoiceChoice) async throws(TTSError) {
        let identifier = voice.kind == .apple && !voice.voiceID.isEmpty ? voice.voiceID : nil
        do {
            try await playback.speak(text, language: language.rawValue, voiceIdentifier: identifier)
        } catch {
            if case .ttsFailed(let detail) = error, detail.hasPrefix("no voice") {
                throw TTSError.noVoice(language: language.rawValue)
            }
            throw TTSError.audio(detail: error.localizedDescription)
        }
    }

    /// Installed Apple voices for the language (for the picker), enhanced/premium first.
    static func installedVoices(for language: TranscriptionLanguage) -> [VoiceChoice] {
        let prefix = language.rawValue.split(separator: "-").first.map(String.init) ?? language.rawValue
        return AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.lowercased().hasPrefix(prefix.lowercased()) }
            .sorted { lhs, rhs in
                if lhs.quality != rhs.quality { return lhs.quality.rawValue > rhs.quality.rawValue }
                return lhs.name < rhs.name
            }
            .map { VoiceChoice(kind: .apple, voiceID: $0.identifier, name: "Apple · \($0.name)") }
    }
}
