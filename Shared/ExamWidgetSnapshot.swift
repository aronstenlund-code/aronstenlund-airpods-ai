import AppIntents
import Foundation

/// A44 (N2): what the home screen widget shows, written by the app into the shared app group and read by the widget
/// extension. Nothing else is shared: no questions, answers or audio. Without the app group (a sideloaded build that
/// was signed without it) the widget finds nothing and shows "Öppna Lumen".
struct ExamWidgetSnapshot: Codable, Equatable, Sendable {
    static let appGroup = "group.com.rsolutions.lumen"
    static let key = "widget.exam"
    static let kind = "com.rsolutions.lumen.widget.exam"

    var examName: String?
    var examDate: Date?
    var streak: Int
    var doneToday: Bool
    var readyPct: Int?
    var updatedAt: Date

    /// Whole days from today to the exam (0 on the day), nil without an exam.
    func daysLeft(now: Date = Date(), calendar: Calendar = .current) -> Int? {
        guard let examDate else { return nil }
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: examDate)).day
    }

    /// "5 dagar kvar", "I morgon", "I dag"; nil once the exam is past.
    func daysLeftText(now: Date = Date(), calendar: Calendar = .current) -> String? {
        guard let days = daysLeft(now: now, calendar: calendar), days >= 0 else { return nil }
        switch days {
        case 0: return "I dag"
        case 1: return "I morgon"
        default: return "\(days) dagar kvar"
        }
    }

    /// The streak only while it is alive: today, or yesterday while today's question is not done.
    func liveStreak(now: Date = Date(), calendar: Calendar = .current) -> Int {
        let written = calendar.startOfDay(for: updatedAt)
        let today = calendar.startOfDay(for: now)
        let days = calendar.dateComponents([.day], from: written, to: today).day ?? 0
        switch days {
        case 0: return streak
        case 1: return doneToday ? streak : 0
        default: return 0
        }
    }

    static func load(_ defaults: UserDefaults? = UserDefaults(suiteName: appGroup)) -> ExamWidgetSnapshot? {
        guard let data = defaults?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(ExamWidgetSnapshot.self, from: data)
    }

    func save(_ defaults: UserDefaults? = UserDefaults(suiteName: Self.appGroup)) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults?.set(data, forKey: Self.key)
    }
}

/// A44: "Förhör mig" on the widget: opens Lumen and starts the quiz for the nearest exam (Provläge without an exam).
/// Runs with the app open, like every intent that switches the microphone on (D58).
struct StartQuizIntent: AppIntent {
    static let title: LocalizedStringResource = "Förhör mig"
    static let supportedModes: IntentModes = .foreground

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        await ListeningRemote.quiz?()
        return .result()
    }
}
