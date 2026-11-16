import Foundation
import Observation

/// A108 (D194): the days practised in the repetition mode. A day counts at 3 played questions or 2 minutes read aloud
/// in the reading mode (not a mix). The day is the phone's own calendar day (its time zone), so midnight starts a new
/// count. The streak is `QuizDays.streak`'s rule: days in a row that end today, or yesterday while today is not done
/// yet; a missed day starts over.
struct PracticeDays: Codable, Equatable, Sendable {
    static let questionsPerDay = 3
    static let readingSecondsPerDay: TimeInterval = 120
    static let key = "repetition.practiceDays"

    /// The days that counted, "yyyy-MM-dd", oldest first (at most `QuizDays.limit`).
    var done: [String] = []
    /// The day `questions` and `readingSeconds` belong to.
    var day = ""
    var questions = 0
    var readingSeconds: TimeInterval = 0

    /// A question was played. True when it made the day count just now.
    @discardableResult
    mutating func recordQuestion(at date: Date = Date(), calendar: Calendar = .current) -> Bool {
        roll(to: date, calendar: calendar)
        questions += 1
        return markDoneIfReached(calendar: calendar)
    }

    /// Seconds read aloud in the reading mode. True when they made the day count just now.
    @discardableResult
    mutating func recordReading(seconds: TimeInterval, at date: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard seconds > 0, seconds.isFinite else { return false }
        roll(to: date, calendar: calendar)
        readingSeconds += seconds
        return markDoneIfReached(calendar: calendar)
    }

    func isDone(_ date: Date = Date(), calendar: Calendar = .current) -> Bool {
        done.contains(StudyHistory.day(date, calendar: calendar))
    }

    func streak(today: Date = Date(), calendar: Calendar = .current) -> QuizDays.Streak {
        QuizDays(days: done).streak(today: today, calendar: calendar)
    }

    static func load(_ defaults: UserDefaults = .standard) -> PracticeDays {
        guard let data = defaults.data(forKey: key),
              let value = try? JSONDecoder().decode(PracticeDays.self, from: data) else { return PracticeDays() }
        return value
    }

    func save(_ defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(self) { defaults.set(data, forKey: Self.key) }
    }

    /// A new day starts both counts at 0.
    private mutating func roll(to date: Date, calendar: Calendar) {
        let today = StudyHistory.day(date, calendar: calendar)
        guard today != day else { return }
        day = today
        questions = 0
        readingSeconds = 0
    }

    private mutating func markDoneIfReached(calendar: Calendar) -> Bool {
        guard !done.contains(day),
              questions >= Self.questionsPerDay || readingSeconds >= Self.readingSecondsPerDay else { return false }
        done = QuizDays(days: done + [day]).days
        return true
    }
}

/// A108 (D194): keeps `PracticeDays` from what the player reports, and tells the model when a day became done (today's
/// reminder is cancelled) and when an exam was played through for the first time (the moment to ask about
/// reminders, never at the first start).
@MainActor
@Observable
final class PracticeTracker {
    private(set) var days: PracticeDays
    /// The exam played last; the reminder opens it.
    private(set) var lastDrillID: UUID?
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private let now: () -> Date
    /// Called when today became a practised day.
    @ObservationIgnored var onDayDone: (@MainActor () -> Void)?

    static let lastDrillKey = "repetition.practice.lastDrill"
    static let finishedKey = "repetition.practice.finishedOnce"

    init(defaults: UserDefaults = .standard, calendar: Calendar = .current, now: @escaping () -> Date = Date.init) {
        self.defaults = defaults
        self.calendar = calendar
        self.now = now
        days = PracticeDays.load(defaults)
        lastDrillID = defaults.string(forKey: Self.lastDrillKey).flatMap(UUID.init(uuidString:))
    }

    var streak: QuizDays.Streak { days.streak(today: now(), calendar: calendar) }
    var practisedToday: Bool { days.isDone(now(), calendar: calendar) }

    /// An exam has been played through at least once (any exam, any time).
    var hasFinishedAnExam: Bool { defaults.bool(forKey: Self.finishedKey) }

    func questionPlayed(in drillID: UUID) {
        remember(drillID)
        let madeDay = days.recordQuestion(at: now(), calendar: calendar)
        days.save(defaults)
        if madeDay { onDayDone?() }
    }

    func read(seconds: TimeInterval, in drillID: UUID) {
        remember(drillID)
        let madeDay = days.recordReading(seconds: seconds, at: now(), calendar: calendar)
        days.save(defaults)
        if madeDay { onDayDone?() }
    }

    /// The exam was played to its end (the questions' first lap, or the text's last sentence). True the first time
    /// ever, when D194 asks about reminders.
    @discardableResult
    func examFinished() -> Bool {
        guard !hasFinishedAnExam else { return false }
        defaults.set(true, forKey: Self.finishedKey)
        return true
    }

    private func remember(_ drillID: UUID) {
        guard lastDrillID != drillID else { return }
        lastDrillID = drillID
        defaults.set(drillID.uuidString, forKey: Self.lastDrillKey)
    }
}

/// A108: what the model needs of iOS's notifications, so tests never touch them.
@MainActor
protocol PracticeReminding: AnyObject {
    /// Practice reminders are on in Inställningar (D194: on by default).
    var isOn: Bool { get }
    /// iOS has not been asked about notifications yet.
    func notAskedYet() async -> Bool
    func schedule(drillID: UUID?, examTitle: String?, doneToday: Bool, ask: Bool) async
    func cancelToday()
}

/// A108: `LumenNotifications`, the app's one notification engine.
@MainActor
final class LivePracticeReminders: PracticeReminding {
    var isOn: Bool { LumenNotifications.practiceRemindersOn }
    func notAskedYet() async -> Bool { await LumenNotifications.status() == .notDetermined }
    func schedule(drillID: UUID?, examTitle: String?, doneToday: Bool, ask: Bool) async {
        await LumenNotifications.schedulePractice(drillID: drillID, examTitle: examTitle, doneToday: doneToday, ask: ask)
    }
    func cancelToday() { LumenNotifications.cancelPracticeToday() }
}
