import Foundation
import Testing
@testable import Lumen

@Suite struct ConversationTests {
    private let t0 = Date(timeIntervalSince1970: 1_000_000)

    @Test func partialResultsReplaceEachOther() {
        var c = Conversation()
        c.updatePartial("vad", at: t0)
        c.updatePartial("vad är", at: t0.addingTimeInterval(0.3))
        c.updatePartial("vad är foto", at: t0.addingTimeInterval(0.6))

        #expect(c.segments.count == 1)
        #expect(c.segments[0].text == "vad är foto")
        #expect(c.segments[0].isFinal == false)
        #expect(c.segments[0].startedAt == t0, "start time is when the utterance began, not the last update")
        #expect(c.finalSegments.isEmpty)
    }

    @Test func finalizeKeepsIdentityAndClearsPartial() {
        var c = Conversation()
        c.updatePartial("vad är", at: t0)
        let partialID = c.partial?.id

        c.finalize("Vad är fotosyntes?", at: t0.addingTimeInterval(1))

        #expect(c.partial == nil)
        #expect(c.finalSegments.count == 1)
        #expect(c.finalSegments[0].id == partialID)
        #expect(c.finalSegments[0].isFinal)
        #expect(c.finalSegments[0].text == "Vad är fotosyntes?")
        #expect(c.finalSegments[0].startedAt == t0)
    }

    @Test func emptyResultsAreDropped() {
        var c = Conversation()
        c.updatePartial("   ", at: t0)
        #expect(c.partial == nil)

        c.updatePartial("hej", at: t0)
        c.updatePartial("", at: t0)
        #expect(c.partial == nil, "an empty partial clears the row")

        c.finalize("  \n", at: t0)
        #expect(c.finalSegments.isEmpty)
        #expect(c.isEmpty)
    }

    @Test func finalWithoutPartialIsAppended() {
        var c = Conversation()
        c.finalize("Första meningen.", at: t0)
        c.finalize("Andra meningen.", at: t0.addingTimeInterval(2))
        #expect(c.finalSegments.map(\.text) == ["Första meningen.", "Andra meningen."])
        #expect(c.finalSegments[0].id != c.finalSegments[1].id)
    }

    @Test func segmentsAreCappedOldestFirst() {
        var c = Conversation()
        for i in 0..<(Conversation.maxSegments + 10) {
            c.finalize("segment \(i)", at: t0.addingTimeInterval(Double(i)))
        }
        #expect(c.finalSegments.count == Conversation.maxSegments)
        #expect(c.finalSegments.first?.text == "segment 10")
        #expect(c.finalSegments.last?.text == "segment \(Conversation.maxSegments + 9)")
    }

    @Test func answersAreCapped() {
        var c = Conversation()
        for i in 0..<(Conversation.maxAnswers + 3) {
            c.append(AnswerTurn(question: "q\(i)", answer: "a\(i)", createdAt: t0, source: "mock"))
        }
        #expect(c.answers.count == Conversation.maxAnswers)
        #expect(c.answers.first?.question == "q3")
    }

    @Test func recentTextExcludesOldAndPlaybackOverlap() {
        var c = Conversation()
        c.finalize("gammalt", at: t0)
        c.finalize("under uppspelning", at: t0.addingTimeInterval(100), overlapsPlayback: true)
        c.finalize("nytt ett", at: t0.addingTimeInterval(110))
        c.finalize("nytt två", at: t0.addingTimeInterval(115))

        let text = c.recentText(seconds: 60, now: t0.addingTimeInterval(120))
        #expect(text == "nytt ett nytt två")
    }

    @Test func overlapFlagSticksFromPartialToFinal() {
        var c = Conversation()
        c.updatePartial("växternas", at: t0, overlapsPlayback: true)
        c.updatePartial("växternas sätt", at: t0, overlapsPlayback: false)
        c.finalize("växternas sätt att", at: t0, overlapsPlayback: false)
        #expect(c.finalSegments[0].overlapsPlayback)
    }

    @Test func clearEmptiesEverything() {
        var c = Conversation()
        c.updatePartial("x", at: t0)
        c.finalize("y", at: t0)
        c.append(AnswerTurn(question: "q", answer: "a", createdAt: t0, source: "mock"))
        c.clear()
        #expect(c.isEmpty)
        #expect(c.segments.isEmpty)
    }
}
