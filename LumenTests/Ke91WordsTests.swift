import Foundation
import Testing
@testable import Lumen

/// Ke91 (Kelly 2026-11-26, `docs/design/ordlista-app.md`): one word per thing in the English app, as on the site and
/// the App Store page. The repetition views' part (Angela Fable). The Swedish stays as it was.
@Suite struct Ke91WordsTests {
    private func text(_ key: String, _ language: AppLanguage) -> String {
        language.bundle.localizedString(forKey: key, value: "(missing)", table: nil)
    }

    @Test func theEnglishSaysAudioCreatePracticeAndSpeed() {
        let english = ["Gör ljudet …": "Creating audio …", "Gör": "Create", "Gör frågor": "Create questions",
                       "Gör med ChatGPT": "Create with ChatGPT", "Tempo": "Speed", "Tempo, normal": "Speed, normal",
                       "Röster": "Voices", "Att provlyssna": "Under review", "Att öva på": "To practice",
                       "Kom förberedd till provet": "Be ready for your quiz", "Något fel? Skriv det": "Something wrong? Tell us",
                       "Öppnar samlingen": "Opens the quiz", "Visar vad som kostar vad": "Shows what things cost",
                       "Provlyssning kostar inget. En ny röst blir nytt ljud.": "Previews are free. A new voice means new audio.",
                       "1 tecken nytt ljud": "1 character of new audio", "BETA": "Beta",
                       "Ljudet görs när du startar provet.": "The audio is created when you start the quiz."]
        for (key, value) in english {
            #expect(text(key, .en) == value, "\(key)")
            #expect(text(key, .sv) == key, "the Swedish stays: \(key)")
        }
    }

    @Test func theOwnRecordingStillSaysSound() {
        // Kelly: your own voice is not created audio, so it stays "sound".
        #expect(text("Helt gratis. Ljudet stannar på din telefon.", .en) == "Completely free. The sound stays on your phone.")
    }
}
