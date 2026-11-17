import Foundation
import Testing
@testable import Lumen

/// A108 (D194): a day counts at 3 played questions or 2 minutes read aloud; a missed day starts the streak over; the
/// reminder comes once a day at 18:00 (changeable) only on days not practised. Written before the code (Deangelo).
/// 0 ElevenLabs (D180).
@MainActor
@Suite struct A108PracticeStreakTests {
    static func calendar(_ zone: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: zone)!
        return calendar
    }

    static let stockholm = calendar("Europe/Stockholm")

    /// 2026-11-15 at hh:mm in `calendar`'s zone.
    static func at(_ day: Int, _ hour: Int, _ minute: Int = 0, _ calendar: Calendar = stockholm) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
    }

    // MARK: When a day counts

    @Test func threeQuestionsMakeADay() {
        var days = PracticeDays()
        let made1 = days.recordQuestion(at: Self.at(15, 9), calendar: Self.stockholm)
        #expect(!made1)
        let made2 = days.recordQuestion(at: Self.at(15, 9, 1), calendar: Self.stockholm)
        #expect(!made2)
        #expect(!days.isDone(Self.at(15, 9, 2), calendar: Self.stockholm))
        let made3 = days.recordQuestion(at: Self.at(15, 9, 2), calendar: Self.stockholm)
        #expect(made3, "the third question makes the day")
        #expect(days.isDone(Self.at(15, 22), calendar: Self.stockholm))
        let made4 = days.recordQuestion(at: Self.at(15, 9, 3), calendar: Self.stockholm)
        #expect(!made4, "only once")
    }

    @Test func twoMinutesReadAloudMakeADay() {
        var days = PracticeDays()
        let made5 = days.recordReading(seconds: 70, at: Self.at(15, 10), calendar: Self.stockholm)
        #expect(!made5)
        let made6 = days.recordReading(seconds: 50, at: Self.at(15, 10, 2), calendar: Self.stockholm)
        #expect(made6)
        #expect(days.isDone(Self.at(15, 10, 3), calendar: Self.stockholm))
    }

    @Test func questionsAndReadingDoNotAdd() {
        // D194 counts either 3 questions or 2 minutes, not a mix.
        var days = PracticeDays()
        days.recordQuestion(at: Self.at(15, 9), calendar: Self.stockholm)
        days.recordQuestion(at: Self.at(15, 9), calendar: Self.stockholm)
        days.recordReading(seconds: 100, at: Self.at(15, 9), calendar: Self.stockholm)
        #expect(!days.isDone(Self.at(15, 9), calendar: Self.stockholm))
    }

    // MARK: The day's edge

    @Test func midnightStartsANewCount() {
        var days = PracticeDays()
        days.recordQuestion(at: Self.at(15, 23, 58), calendar: Self.stockholm)
        days.recordQuestion(at: Self.at(15, 23, 59), calendar: Self.stockholm)
        // The third question after midnight is the new day's first, not the old day's third.
        let made7 = days.recordQuestion(at: Self.at(16, 0, 1), calendar: Self.stockholm)
        #expect(!made7)
        #expect(!days.isDone(Self.at(15, 23, 59), calendar: Self.stockholm))
        #expect(!days.isDone(Self.at(16, 0, 2), calendar: Self.stockholm))
    }

    @Test func theDayIsThePhonesOwnTimeZone() {
        // 23:30 in Stockholm is 17:30 the same day in New York, and 00:30 on the 16th is still the 15th there.
        let newYork = Self.calendar("America/New_York")
        var days = PracticeDays()
        for minute in 30..<33 { days.recordQuestion(at: Self.at(16, 0, minute), calendar: newYork) }
        #expect(days.isDone(Self.at(15, 20, 0, newYork), calendar: newYork), "the 15th in New York")
        #expect(!days.isDone(Self.at(16, 12, 0, newYork), calendar: newYork), "not the 16th")
        #expect(days.done == ["2026-11-15"])
    }

    // MARK: The streak

    @Test func daysInARowCountAndAMissedDayStartsOver() {
        var days = PracticeDays()
        for day in [12, 13, 14] {
            for minute in 0..<3 { days.recordQuestion(at: Self.at(day, 18, minute), calendar: Self.stockholm) }
        }
        #expect(days.streak(today: Self.at(14, 20), calendar: Self.stockholm) == .init(current: 3, doneToday: true))
        // The 15th: not done yet, the streak still stands until midnight.
        #expect(days.streak(today: Self.at(15, 20), calendar: Self.stockholm) == .init(current: 3, doneToday: false))
        // The 16th without the 15th: a missed day starts over.
        #expect(days.streak(today: Self.at(16, 8), calendar: Self.stockholm).current == 0)
        for minute in 0..<3 { days.recordQuestion(at: Self.at(16, 9, minute), calendar: Self.stockholm) }
        #expect(days.streak(today: Self.at(16, 10), calendar: Self.stockholm) == .init(current: 1, doneToday: true))
    }

    @Test func savedAndLoaded() throws {
        let defaults = try #require(UserDefaults(suiteName: "a108-\(UUID())"))
        var days = PracticeDays()
        for minute in 0..<3 { days.recordQuestion(at: Self.at(15, 9, minute), calendar: Self.stockholm) }
        days.save(defaults)
        #expect(PracticeDays.load(defaults) == days)
    }

    // MARK: The reminder

    @Test func theReminderIsOnlyForDaysNotPractised() {
        // 7 days from today at 18:00; today only when it is not done and 18:00 has not passed.
        let notDone = LumenNotifications.practiceDays(today: Self.at(15, 9), doneToday: false, minutes: 18 * 60,
                                                      calendar: Self.stockholm)
        #expect(notDone.first == "2026-11-15" && notDone.count == 7)
        let done = LumenNotifications.practiceDays(today: Self.at(15, 9), doneToday: true, minutes: 18 * 60,
                                                   calendar: Self.stockholm)
        #expect(done.first == "2026-11-16" && done.count == 6)
        let late = LumenNotifications.practiceDays(today: Self.at(15, 19), doneToday: false, minutes: 18 * 60,
                                                   calendar: Self.stockholm)
        #expect(late.first == "2026-11-16", "18:00 has passed today")
        let own = LumenNotifications.practiceDays(today: Self.at(15, 19), doneToday: false, minutes: 20 * 60 + 30,
                                                  calendar: Self.stockholm)
        #expect(own.first == "2026-11-15", "the time is changeable (20:30)")
    }

    @Test func theDefaultTimeIsSixInTheEvening() {
        #expect(LumenNotifications.practiceHour == 18)
        #expect(LumenNotifications.timeText(LumenNotifications.practiceHour * 60) == "18:00")
    }
}

/// A108: the player, the session and the model together, with a mock for iOS's notifications.
@MainActor
@Suite struct A108PracticeWiringTests {
    @MainActor final class MockReminders: PracticeReminding {
        var isOn = true
        var notAsked = true
        var scheduled: [(drillID: UUID?, title: String?, doneToday: Bool, ask: Bool)] = []
        var cancelled = 0
        func notAskedYet() async -> Bool { notAsked }
        func schedule(drillID: UUID?, examTitle: String?, doneToday: Bool, ask: Bool) async {
            scheduled.append((drillID, examTitle, doneToday, ask))
        }
        func cancelToday() { cancelled += 1 }
    }

    func setup() throws -> (RepetitionModel, RepetitionSession, A78RepetitionTests.MockSource, A78RepetitionTests.MockTimer, MockReminders, Drill) {
        let folder = try A79A81RepetitionTests.folder("a108")
        let store = DrillStore(url: folder.appendingPathComponent("drills.json"))
        let defaults = try #require(UserDefaults(suiteName: "a108w-\(UUID())"))
        let source = A78RepetitionTests.MockSource()
        let timer = A78RepetitionTests.MockTimer()
        let session = RepetitionSession(inputs: [], makeSource: { source }, makeTimer: { timer }, defaults: defaults,
                                        activatesAudioSession: false)
        let model = RepetitionModel(store: store, session: session, maker: MockDrillMaker(),
                                    audio: DeviceVoiceDrillAudio(folder: folder, makesSound: false),
                                    sharing: A79A81RepetitionTests.MockSharing(), remote: RemoteCommandHub(),
                                    defaults: defaults)
        let reminders = MockReminders()
        model.reminders = reminders
        let drill = A79A81RepetitionTests.bio(3)
        store.save(drill)
        return (model, session, source, timer, reminders, drill)
    }

    @Test func threePlayedQuestionsMakeTheDayAndCancelTodaysReminder() async throws {
        let (model, session, source, timer, reminders, drill) = try setup()
        session.start(drill, tracks: A78RepetitionTests.tracks(3))
        for _ in 0..<3 {
            source.last.finish() // the question
            timer.fire()         // the thinking time, then the next question
        }
        #expect(model.practice.practisedToday)
        #expect(model.practice.streak.current == 1)
        #expect(model.practice.lastDrillID == drill.id)
        #expect(reminders.cancelled == 1, "D194: no reminder on a practised day")
    }

    @Test func theAskComesAfterTheFirstFinishedExamOnly() async throws {
        let (model, session, source, timer, reminders, drill) = try setup()
        #expect(!model.asksForReminders, "never at the first start")
        session.start(drill, tracks: A78RepetitionTests.tracks(3))
        for _ in 0..<3 { source.last.finish(); timer.fire() } // the lap ends after the third question
        for _ in 0..<50 where !model.asksForReminders { try await Task.sleep(for: .milliseconds(5)) }
        #expect(model.asksForReminders && model.practice.hasFinishedAnExam)
        model.declinePracticeReminders()
        #expect(!model.asksForReminders)
        await model.allowPracticeReminders()
        #expect(reminders.scheduled.last?.ask == true, "iOS asks only after the app's own question")
        #expect(reminders.scheduled.last?.drillID == drill.id)
    }

    /// D215 (A132): a text said in "Säg i AirPods" is no exam, so the reminder never names or opens one, also when
    /// it was the last thing practised.
    @Test func theReminderIsForTheLatestExamNeverForASaidText() async throws {
        let (model, _, _, _, reminders, drill) = try setup()
        var said = Drill.text(title: SaidText.title("Hej hej hooooo"), summary: DrillSummary(subject: "", grade: "", covers: ""),
                              parts: [DrillItem.textPart("Hej hej hooooo", part: .para)])
        said.said = true
        let saved = model.save(said)
        #expect(saved.isSaid && model.drills.first?.id == saved.id, "the list is newest first")

        await model.reschedulePracticeReminders()
        #expect(reminders.scheduled.last?.drillID == drill.id, "nothing practised: the exam, not the said text")

        model.practice.read(seconds: 130, in: saved.id) // the said text was listened to last
        #expect(model.practice.lastDrillID == saved.id)
        await model.reschedulePracticeReminders()
        #expect(reminders.scheduled.last?.drillID == drill.id)
        #expect(reminders.scheduled.last?.title == drill.title)

        model.practice.questionPlayed(in: drill.id) // an exam practised last is the reminder's exam
        await model.reschedulePracticeReminders()
        #expect(reminders.scheduled.last?.drillID == drill.id)

        // With the said text practised last again, the reminder is for the newest exam.
        let newer = model.save(A79A81RepetitionTests.bio(2))
        model.practice.read(seconds: 10, in: saved.id)
        await model.reschedulePracticeReminders()
        #expect(reminders.scheduled.last?.drillID == newer.id)
    }

    @Test func readingTimeIsCountedOnlyWhileReading() throws {
        let (model, session, _, _, _, _) = try setup()
        let text = Drill.from(try A105TextDrillTests.view())
        session.startReading(text) { _ in ReadingAudio(url: URL(fileURLWithPath: "/tmp/r.mp3"), times: [0...1]) }
        let t0 = Date()
        for i in 0...20 { session.tick(reading: true, now: t0.addingTimeInterval(Double(i) * 4)) } // 80 s read
        session.tick(reading: false, now: t0.addingTimeInterval(500)) // paused 420 s: not counted
        for i in 1...9 { session.tick(reading: true, now: t0.addingTimeInterval(500 + Double(i) * 4)) } // 36 s more
        session.stop() // reports what is left
        #expect(abs(model.practice.days.readingSeconds - 116) < 1)
        #expect(!model.practice.practisedToday, "116 s is under 2 minutes")
    }
}
