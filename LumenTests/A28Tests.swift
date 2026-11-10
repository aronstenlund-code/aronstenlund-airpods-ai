import Foundation
import Testing
@testable import Lumen

/// A28 (Oscar O30): an echo can only come while Lumen speaks or just after; a follow-up that quotes the answer later
/// is the wearer's question.
@Suite struct EchoTimingTests {
    private let end = Date(timeIntervalSince1970: 2_000_000)

    @Test func duringOrJustAfterLumenSpeaksItMayBeEcho() {
        #expect(EchoFilter.mayBeEcho(startedAt: end.addingTimeInterval(-3), speaking: true, overlapsPlayback: false, lastSpeechEnd: nil))
        #expect(EchoFilter.mayBeEcho(startedAt: end, speaking: false, overlapsPlayback: true, lastSpeechEnd: nil))
        #expect(EchoFilter.mayBeEcho(startedAt: end.addingTimeInterval(1.0), speaking: false, overlapsPlayback: false, lastSpeechEnd: end))
    }

    @Test func laterItIsTheWearer() {
        #expect(!EchoFilter.mayBeEcho(startedAt: end.addingTimeInterval(3), speaking: false, overlapsPlayback: false, lastSpeechEnd: end))
        #expect(!EchoFilter.mayBeEcho(startedAt: end, speaking: false, overlapsPlayback: false, lastSpeechEnd: nil), "Lumen never spoke")
    }

    @Test func oscarsFollowUpsQuoteTheAnswerHeavily() {
        // Why timing is needed: by words alone O30's check question is Lumen's own.
        var echo = EchoFilter()
        echo.record("Fotosyntesen omvandlar ljusenergi till kemisk energi i form av glukos.", at: end)
        #expect(echo.isEcho("så fotosyntesen omvandlar ljusenergi till kemisk energi?", now: end.addingTimeInterval(4)))
    }
}
