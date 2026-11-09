import Foundation
import Testing
@testable import Lumen

/// A17: "igen" repeats exactly, when it is meant for Lumen.
@Suite struct AgainRuleTests {
    private let t0 = Date(timeIntervalSince1970: 5_000_000)

    private func judge(_ text: String, ago: TimeInterval?, other: Bool? = nil) -> AgainRule.Verdict? {
        AgainRule.judge(text, lastAnswerAt: ago.map { t0.addingTimeInterval(-$0) }, now: t0, isOtherVoice: other)
    }

    @Test func wholeUtteranceWithinFifteenMinutes() {
        #expect(judge("Igen.", ago: 60) == .repeatAnswer)
        #expect(judge("Lumen, igen", ago: 600) == .repeatAnswer)
        #expect(judge("En gång till.", ago: 14 * 60) == .repeatAnswer)
        #expect(judge("Va?", ago: 30) == .repeatAnswer)
        #expect(judge("hörde inte", ago: 300) == .repeatAnswer)
        #expect(judge("igen", ago: 16 * 60) == .notForLumen)
        #expect(judge("igen", ago: nil) == .notForLumen, "no answer yet")
    }

    @Test func insideAnUtteranceOnlyWithin45SecondsAndLast() {
        #expect(judge("eh tåget skramlar igen", ago: 20) == .repeatAnswer, "noise and then 'igen' after 20 s")
        #expect(judge("bla bla igen äh", ago: 20) == .repeatAnswer, "a filler after it does not count")
        #expect(judge("eh tåget skramlar igen", ago: 50) == .notForLumen)
        #expect(judge("gör det igen sen", ago: 120) == nil, "'igen' in the middle of an ordinary sentence")
        #expect(judge("gör det igen sen", ago: 10) == nil)
    }

    @Test func onlyTheWearersVoice() {
        #expect(judge("igen", ago: 30, other: true) == .notForLumen)
        #expect(judge("igen", ago: 30, other: false) == .repeatAnswer)
        #expect(judge("igen", ago: 30, other: nil) == .repeatAnswer, "no profile: the wearer is assumed")
    }

    @Test func otherWordsAreNotAgain() {
        #expect(judge("vad är fotosyntes", ago: 10) == nil)
        #expect(judge("Lumen.", ago: 10) == nil)
        #expect(judge("igenom skogen", ago: 10) == nil)
    }
}
