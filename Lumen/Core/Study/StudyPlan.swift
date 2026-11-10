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
    }

    struct Reply: Decodable, Equatable, Sendable {
        var today: String?
        var exams: [ExamPlanReply]
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

    /// One notification per plan day at 16:00 (none for a time already past); the old ones are replaced.
    static func schedulePlan(_ days: [(subject: String, day: StudyPlanAPI.Day)], ask: Bool = false, now: Date = Date()) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(planPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: pending)
        guard remindersOn, !days.isEmpty, await allowed(ask: ask) else { return }
        for (subject, day) in days.prefix(14) {
            guard let fire = fireDate(day.date, now: now) else { continue }
            let content = UNMutableNotificationContent()
            content.title = "\(day.minutes) minuter \(subject.lowercased()) i dag"
            content.body = day.concepts.isEmpty ? (day.note ?? "Ett kort pass med Lumen.")
                : day.concepts.prefix(3).joined(separator: ", ") + ". Säg ”Lumen, förhör mig”."
            content.sound = .default
            let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
            let request = UNNotificationRequest(identifier: planPrefix + day.date + "." + subject,
                                                content: content,
                                                trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false))
            try? await center.add(request)
        }
    }

    static func fireDate(_ day: String, now: Date, calendar: Calendar = .current) -> Date? {
        let bits = day.split(separator: "-").compactMap { Int($0) }
        guard bits.count == 3 else { return nil }
        var parts = DateComponents(year: bits[0], month: bits[1], day: bits[2], hour: planHour)
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
