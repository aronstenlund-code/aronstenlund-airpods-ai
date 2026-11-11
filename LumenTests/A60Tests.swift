import Foundation
import Testing
@testable import Lumen

/// A60 (Toby T8b finding 1): a question after "Har du prov snart?" is not taken as the exam answer when it comes late
/// or is a question of its own.
@MainActor
@Suite struct A60Tests {
    @Test func anAnswerInTimeIsTheExam() {
        let asked = Date(timeIntervalSince1970: 1_800_000_000)
        #expect(ListeningModel.answersExamQuestion("Biologi på fredag", askedAt: asked, at: asked.addingTimeInterval(5)))
        #expect(ListeningModel.answersExamQuestion("Nej", askedAt: asked, at: asked.addingTimeInterval(5)))
    }

    @Test func aLateAnswerOrAQuestionIsNot() {
        let asked = Date(timeIntervalSince1970: 1_800_000_000)
        #expect(!ListeningModel.answersExamQuestion("Biologi på fredag", askedAt: asked, at: asked.addingTimeInterval(45)))
        #expect(!ListeningModel.answersExamQuestion("Hur många ben har en spindel?", askedAt: asked, at: asked.addingTimeInterval(8)))
        #expect(!ListeningModel.answersExamQuestion("Biologi på fredag", askedAt: nil, at: asked))
    }
}

/// A61 (Ke35): a mode switch while listening keeps the answers and marks where it happened.
@MainActor
@Suite struct A61Tests {
    @Test func theSwitchIsMarkedAfterTheLastAnswer() {
        var conversation = Conversation()
        conversation.markModeSwitch(to: "Provläge")
        #expect(conversation.answers.isEmpty, "nothing to mark yet")
        conversation.beginAnswer(question: "Vad är en cell?", source: "cloud")
        conversation.appendAnswerText("Livets minsta byggsten.")
        _ = conversation.completeAnswer(latencyMs: nil)
        conversation.markModeSwitch(to: "Provläge")
        #expect(conversation.answers.last?.switchedAfter == "Provläge")
        #expect(conversation.answers.count == 1, "the answers stay")
    }
}
