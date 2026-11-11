import Foundation
import Testing
@testable import Lumen

/// A74: a question that repeats one asked in the last 60 s is not sent again; a different one, a later one, or "igen"
/// is.
@MainActor
@Suite struct A74Tests {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func theSameQuestionIsNotSentTwice() {
        var guardrail = RepeatGuard()
        guardrail.record("Vilka är de största sjöarna?", at: t0)
        #expect(guardrail.repeats("vilka är de största sjöarna", at: t0.addingTimeInterval(20)) != nil)
        #expect(guardrail.repeats("Lumen, vilka är de största sjöarna?", at: t0.addingTimeInterval(20)) != nil)
    }

    @Test func aDifferentOrLaterOrRepeatedOnPurposeQuestionGoes() {
        var guardrail = RepeatGuard()
        guardrail.record("Vilka är de största sjöarna?", at: t0)
        #expect(guardrail.repeats("Vilka är de fem största sjöarna i världen?", at: t0.addingTimeInterval(20)) == nil, "a new question")
        #expect(guardrail.repeats("Vilka är de största sjöarna?", at: t0.addingTimeInterval(61)) == nil, "after 60 s")
        #expect(guardrail.repeats("Säg de största sjöarna igen", at: t0.addingTimeInterval(10)) == nil, "asked for again")
        #expect(guardrail.repeats("Vad är fotosyntes?", at: t0.addingTimeInterval(10)) == nil)
    }

    @Test func theUtteranceLengthGoesInTheBody() throws {
        var context = AnswerContext()
        context.utteranceSeconds = 0.42
        #expect(context.clamped.utteranceSeconds == 0.42, "A48's lesson: a new field must be in `clamped`")
        let data = CloudAnswerProvider.encodeBody(AnswerRequest(fragment: "utveckla", mode: "auto", language: "sv", context: context.clamped))
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let inner = try #require(json["context"] as? [String: Any])
        #expect((inner["utterance_ms"] as? Int) == 420, "A77: the server reads context.utterance_ms (K42.5)")
        #expect(json["utterance_seconds"] == nil)
    }
}
