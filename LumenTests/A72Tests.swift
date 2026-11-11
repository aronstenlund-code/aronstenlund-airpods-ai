import Foundation
import Testing
@testable import Lumen

/// A72 (Toby T15): a held half question is sent at the latest 6 s after it was heard, and 1.5 s after its
/// continuation, however many uncommitted words keep coming (VAD and wearer focus in front of Scribe kept it 14–26 s).
@MainActor
@Suite struct A72Tests {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    private func say(_ text: String, at seconds: TimeInterval, to controller: ActivationController, in conversation: inout Conversation) {
        conversation.finalize(text, at: t0.addingTimeInterval(seconds))
        controller.segmentFinalized(conversation.finalSegments.last!, conversation: conversation, language: .swedish,
                                    isPlaybackSpeaking: false, now: t0.addingTimeInterval(seconds))
    }

    @Test func endlessWordsDoNotHoldAHalfForever() {
        let controller = makeTestActivation()
        var conversation = Conversation()
        say("Vad är skillnaden mellan ett virus", at: 0, to: controller, in: &conversation)
        for step in stride(from: 1.0, through: 20.0, by: 0.5) { controller.speechContinues(now: t0.addingTimeInterval(step)) }
        let due = controller.pendingDueAt ?? .distantFuture
        #expect(due <= t0.addingTimeInterval(ActivationController.maxHeld), "at most 6 s after it was heard")
        #expect(controller.fireDue(now: t0.addingTimeInterval(ActivationController.maxHeld)))
    }

    @Test func aContinuationIsSentSoonAfterIt() {
        let controller = makeTestActivation()
        var conversation = Conversation()
        say("Vilka är de största?", at: 0, to: controller, in: &conversation)
        say("Barierna i världen.", at: 1.5, to: controller, in: &conversation)
        for step in stride(from: 2.0, through: 20.0, by: 0.5) { controller.speechContinues(now: t0.addingTimeInterval(step)) }
        let due = controller.pendingDueAt ?? t0
        #expect(due <= t0.addingTimeInterval(1.5 + ActivationController.continuedHold))
    }
}
