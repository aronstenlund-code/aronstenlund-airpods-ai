import AVFoundation
import Foundation

/// A164 (D263): a text without a recording is read by the phone's own voice (AVSpeechSynthesizer), never by
/// ElevenLabs. The voice is written to a file once, so the player plays it like any other sound.
@MainActor
protocol PhoneVoicing: AnyObject {
    /// Writes `text` spoken in `language` (`sv` | `en`) to `url`. False when the phone made no sound for it.
    func write(_ text: String, language: String, to url: URL) async -> Bool
}

/// The phone's voice, as it is on the phone. Nothing leaves the phone and nothing is counted.
@MainActor
final class PhoneVoice: PhoneVoicing {
    private var synthesizer: AVSpeechSynthesizer?

    func write(_ text: String, language: String, to url: URL) async -> Bool {
        let synthesizer = self.synthesizer ?? AVSpeechSynthesizer()
        self.synthesizer = synthesizer
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language == "sv" ? "sv-SE" : "en-US")
        let (stream, continuation) = AsyncStream<TTSChunk>.makeStream(bufferingPolicy: .unbounded)
        synthesizer.write(utterance, toBufferCallback: PlaybackService.ttsBufferCallback(continuation))
        var samples: [Int16] = []
        var rate = 22_050.0
        for await chunk in stream {
            rate = chunk.sampleRate
            samples.append(contentsOf: chunk.samples.map { Int16(max(-1, min(1, $0)) * 32_767) })
        }
        guard !samples.isEmpty else { return false }
        do {
            try WAVWriter.write(samples: samples, sampleRate: Int(rate), to: url)
            return true
        } catch {
            return false
        }
    }
}

#if LUMEN_TESTMODE
/// T58 (Toby) and the screenshots: a voice that writes a short silent file, for the Simulator and the seeded deck
/// (`-SeedOwnDeck 1`). Only in the test builds (Debug and Beta), never in Release.
@MainActor
final class SilentPhoneVoice: PhoneVoicing {
    func write(_ text: String, language: String, to url: URL) async -> Bool {
        do {
            try WAVWriter.write(samples: [Int16](repeating: 0, count: 6_400), sampleRate: 16_000, to: url)
            return true
        } catch {
            return false
        }
    }
}
#endif
