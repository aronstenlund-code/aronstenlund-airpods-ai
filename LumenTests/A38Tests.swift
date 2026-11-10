import Foundation
import Testing
@testable import Lumen

/// A38 (K31): the streak from the quiz days, K31's reply, and one reminder a day at the chosen time.
@MainActor
@Suite struct A38Tests {
    private static func calendar() throws -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Stockholm"))
        return calendar
    }

    private static func date(_ day: Int, hour: Int = 12, _ calendar: Calendar) throws -> Date {
        try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour)))
    }

    @Test func theStreakEndsTodayOrYesterdayAndAMissedDayStartsOver() throws {
        let calendar = try Self.calendar()
        let days = QuizDays(days: ["2026-11-05", "2026-11-07", "2026-11-08", "2026-11-09"])
        let tenth = try Self.date(10, calendar)
        let eleventh = try Self.date(11, calendar)
        let morning = try Self.date(10, hour: 8, calendar)
        let evening = try Self.date(10, hour: 20, calendar)
        let notYet = days.streak(today: tenth, calendar: calendar)
        #expect(notYet == QuizDays.Streak(current: 3, doneToday: false), "yesterday's streak lives until midnight")
        var done = days
        let first = done.record(morning, calendar: calendar)
        let second = done.record(evening, calendar: calendar)
        #expect(first && !second, "only the day's first answer counts")
        let after = done.streak(today: tenth, calendar: calendar)
        #expect(after == QuizDays.Streak(current: 4, doneToday: true))
        let missed = days.streak(today: eleventh, calendar: calendar)
        #expect(missed.current == 0, "the 10th was missed")
        #expect(QuizDays(days: (0..<500).map { String(format: "2025-%02d-%02d", $0 / 28 % 12 + 1, $0 % 28 + 1) }).days.count <= QuizDays.limit)
    }

    @Test func theRequestSendsTheQuizDaysAndTheReplyDecodes() throws {
        let body = StudyPlanAPI.Request(today: "2026-11-10", exams: [], quiz_days: ["2026-11-09"])
        let json = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(body)) as? [String: Any])
        #expect(json["quiz_days"] as? [String] == ["2026-11-09"])
        let reply = #"{"today":"2026-11-10","exams":[{"name":"Biologiprovet","date":"2026-11-13","days_left":3,"due":[],"prompt":null,"plan":[],"readiness":{"ready_pct":68,"practiced":7,"total":12,"weakest":[{"concept":"cellandning","score":0,"why":"fel senast"}],"explain":"Räknat på 12 begrepp, 7 övade."}}],"streak":{"current":2,"best":5,"done_today":false,"at_risk":true},"notification":{"title":"3 dagar kvar till Biologiprovet","body":"5 snabba frågor på cellandning håller din svit på 2 dagar vid liv."}}"#
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let decoded = try decoder.decode(StudyPlanAPI.Reply.self, from: Data(reply.utf8))
        #expect(decoded.streak?.current == 2 && decoded.streak?.atRisk == true && decoded.streak?.doneToday == false)
        #expect(decoded.notification?.title == "3 dagar kvar till Biologiprovet")
        #expect(decoded.exams.first?.readiness?.readyPct == 68)
        #expect(decoded.exams.first?.readiness?.weakest?.first?.why == "fel senast")
        let old = try decoder.decode(StudyPlanAPI.Reply.self, from: Data(#"{"exams":[]}"#.utf8))
        #expect(old.streak == nil && old.notification == nil, "a reply without K31 still decodes")
    }

    @Test func oneReminderADayTodaysFromTheBackendAndNoneWhenDone() throws {
        let calendar = try Self.calendar()
        let today = try Self.date(10, calendar)
        let note = StudyPlanAPI.Note(title: "3 dagar kvar till Biologiprovet", body: "5 snabba frågor på cellandning.")
        let examDay = try Self.date(13, calendar)
        let exams = [(name: "Biologiprovet", date: examDay)]
        let days = LumenNotifications.days(today: today, note: note, doneToday: false, exams: exams,
                                           plan: ["2026-11-11": ["mitos", "osmos"]], calendar: calendar)
        #expect(days.count == 7)
        #expect(days[0] == LumenNotifications.Daily(date: "2026-11-10", title: note.title, body: note.body))
        #expect(days[1].title == "2 dagar kvar till Biologiprovet" && days[1].body == "5 snabba frågor på mitos. Det tar två minuter.")
        #expect(days[2].title == "I morgon är det Biologiprovet")
        #expect(days[3].title == "I dag är det Biologiprovet. Lycka till!")
        #expect(days[4].title == "5 snabba frågor", "after the exam")
        let done = LumenNotifications.days(today: today, note: note, doneToday: true, exams: exams, plan: [:], calendar: calendar)
        #expect(done.first?.date == "2026-11-11", "today's question is done: no reminder today")
    }

    @Test func theReminderIsAtTheChosenTime() throws {
        let calendar = try Self.calendar()
        let morning = try Self.date(10, hour: 9, calendar)
        let fire = try #require(LumenNotifications.fireDate("2026-11-10", now: morning, minutes: 19 * 60 + 30, calendar: calendar))
        #expect(calendar.component(.hour, from: fire) == 19 && calendar.component(.minute, from: fire) == 30)
        #expect(LumenNotifications.fireDate("2026-11-10", now: morning, minutes: 8 * 60, calendar: calendar) == nil, "already past")
        #expect(LumenNotifications.timeText(16 * 60) == "16:00" && LumenNotifications.timeText(7 * 60 + 5) == "07:05")
    }
}
