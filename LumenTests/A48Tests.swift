import Foundation
import Testing
@testable import Lumen

/// A48 (D116, K30): `qa_log: true` goes with a question only when the consent with D116's text (version 5) is accepted.
@MainActor
@Suite struct A48Tests {
    @Test func onlyVersionFiveOrLaterAllowsTheLog() {
        #expect(!ConsentPolicy.allowsQALog(nil))
        #expect(!ConsentPolicy.allowsQALog(ConsentRecord(version: 4, grantedAt: Date())))
        #expect(ConsentPolicy.allowsQALog(ConsentRecord(version: 5, grantedAt: Date())))
        #expect(ConsentPolicy.currentVersion >= ConsentPolicy.qaLogVersion, "the consent shown today has D116's text")
    }

    @Test func theFlagIsSentOnlyWhenAllowed() throws {
        var context = AnswerContext()
        context.qaLog = true
        let logged = try #require(try JSONSerialization.jsonObject(with: CloudAnswerProvider.encodeBody(
            AnswerRequest(fragment: "vad är fotosyntes", mode: "tutor", language: "sv", context: context))) as? [String: Any])
        #expect(logged["qa_log"] as? Bool == true)
        let plain = try #require(try JSONSerialization.jsonObject(with: CloudAnswerProvider.encodeBody(
            AnswerRequest(fragment: "vad är fotosyntes", mode: "tutor", language: "sv"))) as? [String: Any])
        #expect(plain["qa_log"] == nil, "no key at all without consent")
    }
}
