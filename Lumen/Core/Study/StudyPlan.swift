import Foundation
import UIKit
import UserNotifications

/// A19 (K17): every time a concept comes up in a practice exam (and later quizzes), right or wrong, per exam. Kept on
/// this phone and sent to `POST /study-plan`, which works out what is due today and a plan up to the exam.
struct StudyHistory: Codable, Equatable, Sendable {
    struct Entry: Codable, Equatable, Sendable {
        var date: String // yyyy-MM-dd, the phone's own calendar day
        var ok: Bool
    }

    static let perConcept = 30 // the backend's history limit
    static let concepts = 60
    /// Exam id → concept → history, oldest first.
    private(set) var exams: [String: [String: [Entry]]] = [:]

    mutating func record(_ concept: String, ok: Bool, exam: UUID, at date: Date = Date()) {
        let key = String(concept.trimmingCharacters(in: .whitespacesAndNewlines).prefix(60))
        guard !key.isEmpty else { return }
        var concepts = exams[exam.uuidString] ?? [:]
        var history = concepts[key] ?? []
        history.append(Entry(date: Self.day(date), ok: ok))
        concepts[key] = Array(history.suffix(Self.perConcept))
        if concepts.count > Self.concepts,
           let oldest = concepts.min(by: { ($0.value.last?.date ?? "") < ($1.value.last?.date ?? "") })?.key {
            concepts[oldest] = nil
        }
        exams[exam.uuidString] = concepts
    }

    func history(for exam: UUID) -> [String: [Entry]] { exams[exam.uuidString] ?? [:] }

    static func day(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 2000, c.month ?? 1, c.day ?? 1)
    }

    static let key = "study.history"

    static func load(_ defaults: UserDefaults = .standard) -> StudyHistory {
        guard let data = defaults.data(forKey: key), let value = try? JSONDecoder().decode(StudyHistory.self, from: data) else {
            return StudyHistory()
        }
        return value
    }

    func save(_ defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(self) { defaults.set(data, forKey: Self.key) }
    }
}

/// A38 (K31): every day with at least one quiz answer (the phone's own calendar), for the streak. Kept on the phone.
struct QuizDays: Equatable, Sendable {
    static let key = "study.quizDays"
    static let limit = 400 // the backend's
    private(set) var days: [String] = [] // yyyy-MM-dd, sorted, unique

    init(days: [String] = []) {
        self.days = Array(Array(Set(days)).sorted().suffix(Self.limit))
    }

    /// True when this is the day's first quiz answer.
    @discardableResult
    mutating func record(_ date: Date = Date(), calendar: Calendar = .current) -> Bool {
        let day = StudyHistory.day(date, calendar: calendar)
        guard !days.contains(day) else { return false }
        days = Array((days + [day]).sorted().suffix(Self.limit))
        return true
    }

    struct Streak: Equatable, Sendable {
        var current: Int
        var doneToday: Bool
    }

    /// K31's rule: the days in a row that end today, or yesterday while today's question is not done; a missed day
    /// starts over (no freeze, like Duolingo).
    func streak(today: Date = Date(), calendar: Calendar = .current) -> Streak {
        let set = Set(days)
        let doneToday = set.contains(StudyHistory.day(today, calendar: calendar))
        var day = doneToday ? today : (calendar.date(byAdding: .day, value: -1, to: today) ?? today)
        var count = 0
        while set.contains(StudyHistory.day(day, calendar: calendar)) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return Streak(current: count, doneToday: doneToday)
    }

    static func load(_ defaults: UserDefaults = .standard) -> QuizDays {
        QuizDays(days: defaults.stringArray(forKey: key) ?? [])
    }

    func save(_ defaults: UserDefaults = .standard) {
        defaults.set(days, forKey: Self.key)
    }
}

/// A19: Kevin's `/study-plan` request and reply.
enum StudyPlanAPI {
    struct ConceptIn: Encodable, Equatable {
        var concept: String
        var history: [StudyHistory.Entry]
    }

    struct ExamIn: Encodable, Equatable {
        var name: String
        var date: String
        var concepts: [ConceptIn]
    }

    struct Request: Encodable, Equatable {
        var today: String
        var exams: [ExamIn]
        /// A38 (K31): the days with a quiz answer; the reply's streak and notification come from them.
        var quiz_days: [String]? = nil
    }

    /// K31: `{current, best, done_today, at_risk}`.
    struct Streak: Decodable, Equatable, Sendable {
        var current: Int
        var best: Int?
        var doneToday: Bool?
        var atRisk: Bool?
    }

    /// K31: today's reminder; nil when today's question is done.
    struct Note: Decodable, Equatable, Sendable {
        var title: String
        var body: String
    }

    /// K33 (A43): how ready the student is for an exam.
    struct Readiness: Decodable, Equatable, Sendable {
        struct Weak: Decodable, Equatable, Sendable {
            var concept: String
            var score: Double?
            var why: String?
        }
        var readyPct: Int?
        var practiced: Int?
        var total: Int?
        var weakest: [Weak]?
        var explain: String?
    }

    struct Day: Decodable, Equatable, Sendable {
        var date: String
        var minutes: Int
        var concepts: [String]
        var note: String?
    }

    struct ExamPlanReply: Decodable, Equatable, Sendable {
        var name: String
        var date: String?
        var daysLeft: Int?
        var prompt: String?
        var plan: [Day]
        var readiness: Readiness? = nil
    }

    struct Reply: Decodable, Equatable, Sendable {
        var today: String?
        var exams: [ExamPlanReply]
        var streak: Streak? = nil
        var notification: Note? = nil
    }

    /// A38: the countdown in a day's reminder, the same words as K31: "3 dagar kvar till Biologiprovet".
    static func countdown(name: String, daysLeft: Int) -> String {
        switch daysLeft {
        case ..<1: return "I dag är det \(name). Lycka till!"
        case 1: return "I morgon är det \(name)"
        default: return "\(daysLeft) dagar kvar till \(name)"
        }
    }

    /// The concepts of an exam: those with a history first, then the exam's own topics without one (Kevin: without
    /// history the plan is built from the profile's concepts).
    static func concepts(history: [String: [StudyHistory.Entry]], topics: [String]) -> [ConceptIn] {
        var out = history.sorted { $0.key < $1.key }.map { ConceptIn(concept: $0.key, history: $0.value) }
        for topic in topics {
            let clean = topic.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !clean.isEmpty, !out.contains(where: { $0.concept.caseInsensitiveCompare(clean) == .orderedSame }) else { continue }
            out.append(ConceptIn(concept: String(clean.prefix(60)), history: []))
        }
        return Array(out.prefix(StudyHistory.concepts))
    }

    /// The exam's topics as concepts: "cellandning, klorofyll och fotosyntes" → three.
    static func topics(_ text: String) -> [String] {
        text.replacingOccurrences(of: " och ", with: ",")
            .split(whereSeparator: { ",;\n".contains($0) })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// "I dag: 10 min Biologi (cellandning, klorofyll)".
    static func todayLine(subject: String, day: Day) -> String {
        let concepts = day.concepts.prefix(3).joined(separator: ", ")
        return "I dag: \(day.minutes) min \(subject)" + (concepts.isEmpty ? "" : " (\(concepts))")
    }
}

/// A19: `POST /functions/v1/study-plan` (code only on the server, nothing stored there).
@MainActor
final class StudyPlanClient {
    private let config: BackendConfig
    private let auth: SupabaseAuth
    private let http: any HTTPStreaming

    init(config: BackendConfig, auth: SupabaseAuth, http: any HTTPStreaming) {
        self.config = config
        self.auth = auth
        self.http = http
    }

    func plan(_ body: StudyPlanAPI.Request) async -> StudyPlanAPI.Reply? {
        do {
            let token = try await auth.accessToken()
            var request = URLRequest(url: config.studyPlanURL)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue(config.publishableKey, forHTTPHeaderField: "apikey")
            request.markTestTraffic() // T24: x-earmind-test in Debug UI tests
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 15
            request.httpBody = try JSONEncoder().encode(body)
            let (response, data) = try await http.data(for: request)
            guard response.statusCode == 200 else {
                Log.answer.error("study-plan: HTTP \(response.statusCode, privacy: .public)")
                return nil
            }
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(StudyPlanAPI.Reply.self, from: data)
        } catch {
            return nil
        }
    }
}

/// A19 (K19): a checked link to a film or page from Swedish learning resources, from `done.resource`.
struct LearningLink: Codable, Equatable, Sendable {
    var url: URL
    var title: String
    var source: String?
    /// `login_likely` (the SSE decoder converts snake case).
    var loginLikely: Bool?

    /// "UR Play" for "urplay.se".
    var sourceName: String {
        let host = (source ?? url.host() ?? "").replacingOccurrences(of: "www.", with: "")
        switch host {
        case "urplay.se": return "UR Play"
        case "binogi.se": return "Binogi"
        case "sli.se": return "SLI"
        case "skolverket.se": return "Skolverket"
        case "ne.se": return "NE"
        case "khanacademy.org", "sv.khanacademy.org": return "Khan Academy"
        default: return host
        }
    }
}

/// A19: local notifications. The study plan's days (at a fixed time, can be turned off) and a link Lumen sent.
/// A tap on a link's notification opens it in Safari.
final class LumenNotifications: NSObject, UNUserNotificationCenterDelegate, Sendable {
    static let shared = LumenNotifications()
    static let planPrefix = "lumen.plan."
    static let enabledKey = "reminders.studyPlan"
    /// Aron decides the time (K17 "Till Aron"); 16:00 until then.
    static let planHour = 16

    static var remindersOn: Bool {
        UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard let text = response.notification.request.content.userInfo["url"] as? String, let url = URL(string: text) else { return }
        await MainActor.run { UIApplication.shared.open(url) }
    }

    static func status() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// Whether notifications may be shown. iOS's question comes only when `ask` (a tap by the student, or a link
    /// they asked for), never by itself on Start, so no alert appears in the middle of something else.
    static func allowed(ask: Bool) async -> Bool {
        switch await status() {
        case .authorized, .provisional, .ephemeral: return true
        case .notDetermined:
            guard ask else { return false }
            return (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
        default: return false
        }
    }

    /// A38: the reminder's time, minutes after midnight, chosen in Inställningar; 16:00 until Aron decides.
    static let timeKey = "reminders.minutes"
    static var reminderMinutes: Int {
        let value = UserDefaults.standard.object(forKey: timeKey) as? Int ?? planHour * 60
        return min(max(value, 0), 24 * 60 - 1)
    }

    /// "16:00".
    static func timeText(_ minutes: Int = reminderMinutes) -> String {
        String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }

    struct Daily: Equatable, Sendable {
        var date: String // yyyy-MM-dd
        var title: String
        var body: String
    }

    /// A38 (K31): one reminder a day for the coming week at the chosen time. Today's is the backend's (none when
    /// today's question is done); the others count down to the nearest exam and say "5 snabba frågor" on the plan's
    /// concept for that day. The old ones (also A19's per plan day) are replaced.
    static func days(today: Date, note: StudyPlanAPI.Note?, doneToday: Bool,
                     exams: [(name: String, date: Date)], plan: [String: [String]],
                     calendar: Calendar = .current) -> [Daily] {
        var out: [Daily] = []
        for offset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            let day = StudyHistory.day(date, calendar: calendar)
            if offset == 0 {
                if let note, !doneToday { out.append(Daily(date: day, title: note.title, body: note.body)) }
                continue
            }
            let start = calendar.startOfDay(for: date)
            let next = exams
                .map { (name: $0.name, left: calendar.dateComponents([.day], from: start, to: calendar.startOfDay(for: $0.date)).day ?? -1) }
                .filter { $0.left >= 0 }
                .min { $0.left < $1.left }
            let title = next.map { StudyPlanAPI.countdown(name: $0.name, daysLeft: $0.left) } ?? "5 snabba frågor"
            let concept = plan[day]?.first
            let body: String
            if let concept {
                body = "5 snabba frågor på \(concept). Det tar två minuter."
            } else if next != nil {
                body = "5 snabba frågor. Det tar två minuter."
            } else {
                body = "Det tar två minuter och håller din svit vid liv."
            }
            out.append(Daily(date: day, title: title, body: body))
        }
        return out
    }

    static let dailyPrefix = "lumen.daily."

    static func scheduleDaily(_ days: [Daily], ask: Bool = false, now: Date = Date()) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests().map(\.identifier)
            .filter { $0.hasPrefix(planPrefix) || $0.hasPrefix(dailyPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: pending)
        guard remindersOn, !days.isEmpty, await allowed(ask: ask) else { return }
        for daily in days {
            guard let fire = fireDate(daily.date, now: now) else { continue }
            let content = UNMutableNotificationContent()
            content.title = daily.title
            content.body = daily.body
            content.sound = .default
            let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
            let request = UNNotificationRequest(identifier: dailyPrefix + daily.date, content: content,
                                                trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false))
            try? await center.add(request)
        }
    }

    /// Today's question is done: today's reminder is not needed.
    static func cancelToday(_ date: Date = Date()) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [dailyPrefix + StudyHistory.day(date)])
    }

    static func fireDate(_ day: String, now: Date, minutes: Int = reminderMinutes, calendar: Calendar = .current) -> Date? {
        let bits = day.split(separator: "-").compactMap { Int($0) }
        guard bits.count == 3 else { return nil }
        var parts = DateComponents(year: bits[0], month: bits[1], day: bits[2], hour: minutes / 60, minute: minutes % 60)
        parts.calendar = calendar
        guard let date = calendar.date(from: parts), date > now else { return nil }
        return date
    }

    /// The link Lumen sent, so it is on the lock screen while the phone stays in the pocket.
    static func sendLink(_ link: LearningLink) async {
        guard await allowed(ask: true) else { return }
        let content = UNMutableNotificationContent()
        content.title = link.title
        content.body = "Från \(link.sourceName)" + (link.loginLikely == true ? ", kan kräva skolkonto." : ".") + " Tryck för att öppna."
        content.userInfo = ["url": link.url.absoluteString]
        let request = UNNotificationRequest(identifier: "lumen.link." + UUID().uuidString, content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }
}
