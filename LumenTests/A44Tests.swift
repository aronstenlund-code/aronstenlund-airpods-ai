import Foundation
import Testing
@testable import Lumen

/// A44 (N2): the widget's snapshot: the days left, a streak that is still alive, and when the widget reloads.
@MainActor
@Suite struct A44Tests {
    private static func calendar() throws -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Stockholm"))
        return calendar
    }

    private static func date(_ day: Int, hour: Int = 12, _ calendar: Calendar) throws -> Date {
        try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour)))
    }

    @Test func theDaysLeftTurnOverAtMidnight() throws {
        let calendar = try Self.calendar()
        let exam = try Self.date(15, hour: 8, calendar)
        let snapshot = ExamWidgetSnapshot(examName: "Biologiprovet", examDate: exam, streak: 2, doneToday: true, readyPct: 68,
                                          updatedAt: try Self.date(10, calendar))
        let late = try Self.date(10, hour: 23, calendar)
        let next = try Self.date(11, hour: 0, calendar)
        let eve = try Self.date(14, calendar)
        let day = try Self.date(15, hour: 18, calendar)
        let after = try Self.date(16, calendar)
        #expect(snapshot.daysLeftText(now: late, calendar: calendar) == "5 dagar kvar")
        #expect(snapshot.daysLeftText(now: next, calendar: calendar) == "4 dagar kvar")
        #expect(snapshot.daysLeftText(now: eve, calendar: calendar) == "I morgon")
        #expect(snapshot.daysLeftText(now: day, calendar: calendar) == "I dag")
        #expect(snapshot.daysLeftText(now: after, calendar: calendar) == nil, "the exam is past")
    }

    @Test func aStreakOnTheWidgetDiesLikeInTheApp() throws {
        let calendar = try Self.calendar()
        let written = try Self.date(10, calendar)
        let tomorrow = try Self.date(11, calendar)
        let later = try Self.date(12, calendar)
        let done = ExamWidgetSnapshot(examName: nil, examDate: nil, streak: 3, doneToday: true, readyPct: nil, updatedAt: written)
        let notDone = ExamWidgetSnapshot(examName: nil, examDate: nil, streak: 3, doneToday: false, readyPct: nil, updatedAt: written)
        #expect(done.liveStreak(now: written, calendar: calendar) == 3)
        #expect(done.liveStreak(now: tomorrow, calendar: calendar) == 3, "alive until tomorrow's midnight")
        #expect(notDone.liveStreak(now: tomorrow, calendar: calendar) == 0, "yesterday's question was not done")
        #expect(done.liveStreak(now: later, calendar: calendar) == 0)
    }

    @Test func theWidgetReloadsOnlyOnAChange() throws {
        let calendar = try Self.calendar()
        let morning = try Self.date(10, hour: 8, calendar)
        let evening = try Self.date(10, hour: 20, calendar)
        let tomorrow = try Self.date(11, hour: 8, calendar)
        let old = ExamWidgetSnapshot(examName: "Biologiprovet", examDate: tomorrow, streak: 2, doneToday: false, readyPct: 60, updatedAt: morning)
        var same = old
        same.updatedAt = evening
        #expect(!ListeningModel.widgetChanged(old, same, calendar: calendar))
        var streak = same
        streak.streak = 3
        #expect(ListeningModel.widgetChanged(old, streak, calendar: calendar))
        var newDay = old
        newDay.updatedAt = tomorrow
        #expect(ListeningModel.widgetChanged(old, newDay, calendar: calendar))
        #expect(ListeningModel.widgetChanged(nil, old, calendar: calendar))
    }

    @Test func theSnapshotRoundTrips() throws {
        let defaults = try #require(UserDefaults(suiteName: "a44.\(UUID().uuidString)"))
        #expect(ExamWidgetSnapshot.load(defaults) == nil)
        let whole = Date(timeIntervalSinceReferenceDate: 800_000_000) // whole seconds: JSON keeps them exactly
        let snapshot = ExamWidgetSnapshot(examName: "Kemiprovet", examDate: whole, streak: 1, doneToday: true, readyPct: nil, updatedAt: whole)
        snapshot.save(defaults)
        #expect(ExamWidgetSnapshot.load(defaults) == snapshot)
    }
}
