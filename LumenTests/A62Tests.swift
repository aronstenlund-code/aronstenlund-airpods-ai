import Foundation
import Testing
@testable import Lumen

/// A62 (K40): `done.quiz_key` is read, goes back as `context.quiz_key` (survives `clamped`), and its words lead the
/// keyterms.
@MainActor
@Suite struct A62Tests {
    @Test func doneCarriesTheKey() throws {
        let done = #"{"answered":true,"quiz_key":{"answer":"Nilen","alternatives":["Kongo","Niger","Zambezi"]}}"#
        guard case .done(let decoded)? = try AnswerSSEDecoder.decode(SSEEvent(name: "done", data: done)) else {
            Issue.record("not a done event")
            return
        }
        #expect(decoded.quizKey == QuizKey(answer: "Nilen", alternatives: ["Kongo", "Niger", "Zambezi"]))
        #expect(decoded.quizKey?.terms == ["Nilen", "Kongo", "Niger", "Zambezi"])
    }

    @Test func theKeyGoesBackInTheContext() throws {
        var context = AnswerContext()
        context.quizKey = QuizKey(answer: "Nilen", alternatives: ["Kongo"])
        #expect(context.clamped.quizKey == context.quizKey, "A48's lesson: a new field must be in `clamped`")
        let data = CloudAnswerProvider.encodeBody(AnswerRequest(fragment: "Nilan", mode: "tutor", language: "sv", context: context.clamped))
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let sent = try #require((json["context"] as? [String: Any])?["quiz_key"] as? [String: Any])
        #expect(sent["answer"] as? String == "Nilen")
        let plain = try #require(try JSONSerialization.jsonObject(with: CloudAnswerProvider.encodeBody(
            AnswerRequest(fragment: "x", mode: "tutor", language: "sv"))) as? [String: Any])
        #expect((plain["context"] as? [String: Any])?["quiz_key"] == nil)
    }

    @Test func theAnswerLeadsTheKeyterms() {
        let merged = ExamKeyterms.merged(exam: QuizKey(answer: "Nilen", alternatives: nil).terms + ["fotosyntes"], rest: ["nilen", "kortare"])
        #expect(merged.first == "Nilen")
        #expect(merged.count == 3, "no double Nilen")
    }
}
