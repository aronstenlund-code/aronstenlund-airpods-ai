import Foundation
import Testing
@testable import Lumen

/// A167 (Deangelo 2026-11-26): accessibility and small screens in the repetition before the App Store. What can be
/// tested without a screen: the words VoiceOver hears. The layouts with the largest text on the smallest phone
/// are checked on pictures (Fable screens), not here.
@MainActor
@Suite struct A167AccessibilityTests {
    private func text(_ key: String, _ language: AppLanguage) -> String {
        language.bundle.localizedString(forKey: key, value: "(missing)", table: nil)
    }

    @Test func voiceOverHearsWhichCardAFieldBelongsTo() {
        #expect(OwnDeckText.field(.question, number: 2) == "Fråga 2" && OwnDeckText.field(.answer, number: 2) == "Svar 2")
        // What is seen in the field stays the plain word.
        #expect(OwnDeckText.field(.question) == "Fråga" && OwnDeckText.field(.answer) == "Svar")
    }

    @Test func theRecordingIsSaidWhenItStartsAndWhenItIsDone() {
        #expect(OwnDeckText.nowRecording(.question) == "Spelar in frågan" && OwnDeckText.nowRecording(.answer) == "Spelar in svaret")
        #expect(OwnDeckText.doneRecording(.question) == "Klar, frågan är inspelad")
        #expect(OwnDeckText.doneRecording(.answer) == "Klar, svaret är inspelat")
        // While it records the button is "Stoppa inspelningen" and the time is its value, read as seconds.
        #expect(OwnDeckText.stopRecording == "Stoppa inspelningen")
        #expect(OwnDeckText.seconds(0.2) == "0 sekunder" && OwnDeckText.seconds(1.2) == "1 sekund" && OwnDeckText.seconds(4.4) == "4 sekunder")
    }

    @Test func whatIsNotReadInIsSaidWithTheRecordButton() {
        // The button's value: with a text the phone reads it, without one there is nothing to read.
        #expect(OwnDeckText.recordLabel(.answer) == "Spela in svaret")
        #expect(OwnDeckText.notRecorded(hasText: true) == "Inte inspelad · läses av telefonen")
        #expect(OwnDeckText.notRecorded(hasText: false) == "Inte inspelad")
        #expect(OwnDeckText.playLabel(.answer, seconds: 6) == "Spela upp svaret, 6 sekunder")
        #expect(OwnDeckText.recordAgainLabel(.question) == "Spela in frågan igen")
    }

    @Test func theWordsVoiceOverHearsAreInBothLanguages() {
        let english = ["Stoppa inspelningen": "Stop the recording", "1 sekund": "1 second",
                       "Spelar in frågan": "Recording the question", "Spelar in svaret": "Recording the answer",
                       "Klar, frågan är inspelad": "Done, the question is recorded",
                       "Klar, svaret är inspelat": "Done, the answer is recorded",
                       "Spela in frågan igen": "Record the question again", "Spela in svaret igen": "Record the answer again"]
        for (key, value) in english {
            #expect(text(key, .en) == value, "\(key)")
            #expect(text(key, .sv) == key, "\(key)")
        }
        for key in ["Fråga %lld", "Svar %lld", "%lld sekunder", "Spela upp frågan, %lld sekunder", "Spela upp svaret, %lld sekunder"] {
            #expect(text(key, .en) != "(missing)" && text(key, .en) != key, "\(key)")
        }
    }
}
