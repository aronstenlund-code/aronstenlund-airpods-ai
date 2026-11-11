import Foundation
import Testing
@testable import Lumen

/// A54 (D127): the logo vote comes after the first answer, "Senare" brings it back after 2 days at most 3 times, never
/// after a vote, and the order is shuffled once per user and kept.
@MainActor
@Suite struct A54Tests {
    private struct Fixed: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return state
        }
    }

    @Test func notBeforeTheFirstAnswer() {
        let schedule = LogoVoteSchedule()
        #expect(!schedule.shouldShow(now: Date(), hasAnswered: false))
        #expect(schedule.shouldShow(now: Date(), hasAnswered: true))
    }

    @Test func laterComesBackAfterTwoDaysAtMostThreeTimes() {
        var schedule = LogoVoteSchedule()
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        schedule.later(now: start)
        #expect(!schedule.shouldShow(now: start.addingTimeInterval(86_400), hasAnswered: true))
        #expect(schedule.shouldShow(now: start.addingTimeInterval(2 * 86_400), hasAnswered: true))
        schedule.later(now: start.addingTimeInterval(2 * 86_400))
        schedule.later(now: start.addingTimeInterval(4 * 86_400))
        #expect(schedule.laterCount == 3)
        #expect(!schedule.shouldShow(now: start.addingTimeInterval(30 * 86_400), hasAnswered: true), "then never again")
    }

    @Test func neverAfterAVote() {
        var schedule = LogoVoteSchedule()
        schedule.voted = true
        #expect(!schedule.shouldShow(now: Date(), hasAnswered: true))
    }

    @Test func theOrderIsShuffledOnceAndKept() {
        var schedule = LogoVoteSchedule()
        var generator = Fixed(state: 42)
        schedule.ensureOrder(using: &generator)
        let first = schedule.order
        #expect(Set(first) == Set(LogoChoice.allCases) && first.count == 6) // A71: six
        schedule.ensureOrder(using: &generator)
        #expect(schedule.order == first, "shuffled once per user")
        let defaults = UserDefaults(suiteName: "a54-\(UUID().uuidString)")!
        schedule.later(now: Date(timeIntervalSince1970: 1_800_000_000))
        schedule.save(defaults)
        let loaded = LogoVoteSchedule.load(defaults)
        #expect(loaded == schedule)
    }

    @Test func theNamesFavourNone() {
        #expect(LogoChoice.allCases.map(\.name) == ["Klotet", "Den gröna formen", "Den orange ringen", "Glasklotet", "Glasringen", "Glasvågen"])
        #expect(LogoChoice.allCases.allSatisfy { !$0.imageName.isEmpty })
    }
}
