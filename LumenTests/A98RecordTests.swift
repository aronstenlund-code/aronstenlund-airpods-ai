import Foundation
import Testing
@testable import Lumen

/// A98 (D173): Spela in in Mina svar is two steps. The question first; the microphone only on Spela in svaret; Klar
/// only with a recorded answer. (The microphone itself is not started here: that is verified on the phone.)
@MainActor
struct A98RecordTests {
    @Test func nothingRecordsBeforeTheQuestion() {
        let recording = MyAnswerRecording()
        #expect(recording.answerRecorder.state == .idle, "opening the sheet starts nothing")
        #expect(!recording.canRecordAnswer, "Spela in svaret waits for a question")
        #expect(!recording.canFinish, "Klar is off")
        recording.question = "   "
        #expect(!recording.canRecordAnswer)
        recording.question = "Vad är fotosyntesen?"
        #expect(recording.canRecordAnswer)
        #expect(!recording.canFinish, "still no answer")
    }

    @Test func klarNeedsARecordedAnswer() {
        #expect(!MyAnswerRecording.hasAnswer(state: .idle, elapsed: 0))
        #expect(!MyAnswerRecording.hasAnswer(state: .recording, elapsed: 0.4), "a tap is not an answer")
        #expect(MyAnswerRecording.hasAnswer(state: .recording, elapsed: 4))
        #expect(MyAnswerRecording.hasAnswer(state: .recorded, elapsed: 4), "after Stoppa")
        #expect(!MyAnswerRecording.hasAnswer(state: .failed("x"), elapsed: 4))
    }

    @Test func choicesComeFromTheExamsWithoutAnsweredOnes() {
        let bio = Drill(title: "Biologiprovet", summary: DrillSummary(subject: "Biologi", grade: "", covers: ""),
                        items: [DrillItem(question: "Vad är fotosyntes?", short: "a.", long: "a."),
                                DrillItem(question: "Vad gör klorofyllet?", short: "b.", long: "b.")])
        let history = Drill(title: "Historiaprovet", summary: DrillSummary(subject: "Historia", grade: "", covers: ""),
                            items: [DrillItem(question: "Vad var ångmaskinen?", short: "c.", long: "c."),
                                    DrillItem(question: "Vad är fotosyntes?", short: "a.", long: "a.")])
        let choices = MyAnswerRecording.choices(drills: [bio, history], subject: "biologi",
                                                answered: ["vad gör klorofyllet"])
        #expect(choices == ["Vad är fotosyntes?"], "the subject's exam, the answered one left out")
        let all = MyAnswerRecording.choices(drills: [bio, history], subject: "Kemi", answered: [])
        #expect(all == ["Vad är fotosyntes?", "Vad gör klorofyllet?", "Vad var ångmaskinen?"], "no match: every exam, once each")
    }

    @Test func choosingFillsTheQuestion() {
        let recording = MyAnswerRecording(choices: ["Vad är fotosyntes?"])
        recording.choose("Vad är fotosyntes?")
        #expect(recording.question == "Vad är fotosyntes?")
        #expect(recording.canRecordAnswer)
    }

    @Test func finishDoesNothingWithoutAnAnswer() async {
        let recording = MyAnswerRecording()
        recording.question = "Vad är fotosyntes?"
        var called = false
        let draft = await recording.finish { _, _ in
            called = true
            return nil
        }
        #expect(draft == nil)
        #expect(!called, "nothing is sent before an answer is recorded")
    }
}
