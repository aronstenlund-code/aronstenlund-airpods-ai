import Foundation
import Testing
@testable import Lumen

/// Toby 1 T17 findings 3 and 4.
@Suite struct T17EchoRepeatTests {
    private let t0 = Date(timeIntervalSince1970: 9_000)

    @Test func aShortFollowUpWithTheAnswersWordsIsNotEcho() {
        var echo = EchoFilter()
        echo.record("En virus är mycket mindre än en bakterie och kan bara föröka sig i en cell.", at: t0)
        #expect(!echo.isEcho("Och en bakterie.", now: t0.addingTimeInterval(3)), "finding 4: one content word")
        #expect(echo.isEcho("en virus är mycket mindre än en bakterie", now: t0.addingTimeInterval(3)), "the echo itself")
    }

    @Test func theLongerVersionOfACutQuestionIsNotARepeat() {
        var guardrail = RepeatGuard()
        guardrail.record("Vilka är de största? Barnen är-", at: t0)
        #expect(guardrail.repeats("Vilka är de största barnen?", at: t0.addingTimeInterval(5)) == nil, "finding 3: the same words, now whole")
        var whole = RepeatGuard()
        whole.record("Vilka är de största sjöarna?", at: t0)
        #expect(whole.repeats("Vilka är de största sjöarna", at: t0.addingTimeInterval(5)) != nil, "A74 still holds")
    }
}
