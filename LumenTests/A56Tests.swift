import Foundation
import Testing
@testable import Lumen

/// A56 (Toby T5b/T7b): `two_level` goes with Standardläge and Provläge and survives `clamped`; `done.more` is read, so
/// "ja" in the Mer? window can say the developed answer without a new call.
@MainActor
@Suite struct A56Tests {
    @Test func twoLevelSurvivesClampedAndGoesInTheBody() throws {
        var context = AnswerContext()
        context.twoLevel = true
        #expect(context.clamped.twoLevel, "A48's lesson: a new field must be in `clamped`")
        let data = CloudAnswerProvider.encodeBody(AnswerRequest(fragment: "vad är fotosyntes", mode: "tutor", language: "sv", context: context.clamped))
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["two_level"] as? Bool == true)
        let plain = try #require(try JSONSerialization.jsonObject(with: CloudAnswerProvider.encodeBody(
            AnswerRequest(fragment: "x", mode: "auto", language: "sv"))) as? [String: Any])
        #expect(plain["two_level"] == nil)
    }

    @Test func doneCarriesTheDevelopedAnswer() throws {
        let done = #"{"answered":true,"more":"Fotosyntesen sker i kloroplasterna. Klorofyllet fångar ljuset, och glukosen lagrar energin."}"#
        guard case .done(let decoded)? = try AnswerSSEDecoder.decode(SSEEvent(name: "done", data: done)) else {
            Issue.record("not a done event")
            return
        }
        #expect(decoded.more?.hasPrefix("Fotosyntesen sker") == true)
        // more_delta is not spoken: the parser ignores it (done.more has the whole text).
        #expect(try AnswerSSEDecoder.decode(SSEEvent(name: "more_delta", data: #"{"text":"x"}"#)) == nil)
    }

    @Test func theDevelopedAnswerIsKeptAboutTwoMinutes() {
        #expect(MoreOffer.cacheLife == 120)
    }
}
