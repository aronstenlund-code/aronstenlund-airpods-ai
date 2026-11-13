import Foundation

// MARK: - A83 (D149, D150, K49): Publicera prov and Prov från din skola

/// A school from Skolverket's register (K49 `schools`).
struct DrillSchool: Codable, Equatable, Hashable, Sendable, Identifiable {
    var code: String
    var name: String
    var locality: String?

    var id: String { code }
}

/// What anyone may see of a published exam (K49 `publicView`): never the account, photos or documents.
struct DrillPublicationView: Decodable, Equatable, Sendable, Identifiable {
    var id: String
    var title: String
    var subject: String
    var school: DrillSchool
    var exam_date: String
    var items: Int
    var display_name: String?

    var examDate: Date? { DrillPublishing.date(exam_date) }
}

/// The owner's own publication, kept on the exam on the phone.
struct DrillPublication: Codable, Equatable, Sendable {
    var id: String
    var school: DrillSchool
    var subject: String
    var examDate: Date
    var displayName: String?
}

enum DrillReportReason: String, CaseIterable, Sendable {
    case fel, krankande, upphovsratt, annat

    /// Kelly Ke52 "Rapportera".
    var label: String {
        switch self {
        case .fel: "Fel i frågor eller svar"
        case .krankande: "Kränkande innehåll"
        case .upphovsratt: "Någon annans material"
        case .annat: "Något annat"
        }
    }
}

@MainActor
protocol DrillPublishingService: AnyObject, Sendable {
    func schools(matching query: String) async throws(DrillCloudError) -> [DrillSchool]
    func publish(drillID: String, school: DrillSchool, subject: String, examDate: Date,
                 displayName: String?) async throws(DrillCloudError) -> DrillPublicationView
    func unpublish(drillID: String) async throws(DrillCloudError)
    func search(school: DrillSchool?, subject: String?, mySchool: DrillSchool?) async throws(DrillCloudError) -> [DrillPublicationView]
    func importPublication(id: String) async throws(DrillCloudError) -> DrillCloudView
    func report(publicationID: String, reason: DrillReportReason) async throws(DrillCloudError)
    func played(drillID: String) async
}

/// The words and dates of Publicera prov (Kelly Ke52 §2).
enum DrillPublishing {
    /// Ke52: the subjects in this order; the exam's own subject is chosen when it is one of them.
    static let subjects = ["Biologi", "Fysik", "Kemi", "NO", "Matematik", "Svenska", "Engelska", "Moderna språk",
                           "Historia", "Geografi", "Religion", "Samhällskunskap", "SO", "Teknik", "Annat"]

    static func subject(from summary: String) -> String? {
        let s = summary.trimmingCharacters(in: .whitespaces).lowercased()
        return subjects.first { $0.lowercased() == s }
    }

    /// Ke52: the date picker allows 30 days back to 365 days ahead.
    static func dateRange(now: Date = Date(), calendar: Calendar = .current) -> ClosedRange<Date> {
        let start = calendar.date(byAdding: .day, value: -30, to: calendar.startOfDay(for: now)) ?? now
        let end = calendar.date(byAdding: .day, value: 365, to: now) ?? now
        return start...end
    }

    private static func formatter(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "sv_SE")
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = .current
        f.dateFormat = format
        return f
    }

    /// "2026-11-20" for K49.
    static func dayString(_ date: Date) -> String { formatter("yyyy-MM-dd").string(from: date) }

    static func date(_ day: String) -> Date? { formatter("yyyy-MM-dd").date(from: day) }

    /// Ke52: "fre 20 nov", with the year when it is not this year.
    static func shortDate(_ date: Date, now: Date = Date()) -> String {
        let calendar = Calendar(identifier: .gregorian)
        let sameYear = calendar.component(.year, from: date) == calendar.component(.year, from: now)
        return formatter(sameYear ? "EEE d MMM" : "EEE d MMM yyyy").string(from: date).replacingOccurrences(of: ".", with: "")
    }

    /// "Kungsholmens gymnasium · Biologi · fre 20 nov · utan namn" / "· som plugghajen".
    static func line(_ p: DrillPublication) -> String {
        "\(p.school.name) · \(p.subject) · \(shortDate(p.examDate)) · " + (p.displayName.map { "som \($0)" } ?? "utan namn")
    }

    /// K49 `publish_incomplete` with `missing`: "Saknas: skola, ämne, provdatum" (Ke52), checked on the phone first.
    static func missing(school: DrillSchool?, subject: String?, date: Date?) -> String? {
        var parts: [String] = []
        if school == nil { parts.append("skola") }
        if subject?.isEmpty ?? true { parts.append("ämne") }
        if date == nil { parts.append("provdatum") }
        return parts.isEmpty ? nil : "Saknas: " + parts.joined(separator: ", ")
    }
}

extension DrillCloudClient: DrillPublishingService {
    func schools(matching query: String) async throws(DrillCloudError) -> [DrillSchool] {
        struct Reply: Decodable { var schools: [DrillSchool] }
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard q.count >= 2 else { return [] }
        let reply: Reply = try await call(["action": "schools", "q": q], timeout: 15)
        return reply.schools
    }

    func publish(drillID: String, school: DrillSchool, subject: String, examDate: Date,
                 displayName: String?) async throws(DrillCloudError) -> DrillPublicationView {
        struct Reply: Decodable { var publication: DrillPublicationView }
        var body: [String: Any] = ["action": "publish", "id": drillID, "school_code": school.code, "subject": subject,
                                   "exam_date": DrillPublishing.dayString(examDate)]
        if let name = displayName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            body["show_name"] = true // D150: only when the user chose it
            body["display_name"] = String(name.prefix(30))
        } else {
            body["show_name"] = false
        }
        let reply: Reply = try await call(body, timeout: 20)
        return reply.publication
    }

    func unpublish(drillID: String) async throws(DrillCloudError) {
        struct Reply: Decodable { var unpublished: Bool? }
        let _: Reply = try await call(["action": "unpublish", "id": drillID], timeout: 20)
    }

    func search(school: DrillSchool?, subject: String?, mySchool: DrillSchool?) async throws(DrillCloudError) -> [DrillPublicationView] {
        struct Reply: Decodable { var results: [DrillPublicationView] }
        var body: [String: Any] = ["action": "search"]
        if let school { body["school_code"] = school.code }
        if let subject, !subject.isEmpty { body["subject"] = subject }
        if let mySchool { body["my_school"] = mySchool.code }
        let reply: Reply = try await call(body, timeout: 20)
        return reply.results
    }

    func importPublication(id: String) async throws(DrillCloudError) -> DrillCloudView {
        try await call(["action": "import", "publication_id": id], timeout: 30)
    }

    func report(publicationID: String, reason: DrillReportReason) async throws(DrillCloudError) {
        struct Reply: Decodable { var reports: Int?; var hidden: Bool? }
        let _: Reply = try await call(["action": "report", "publication_id": publicationID, "reason": reason.rawValue], timeout: 20)
    }

    func played(drillID: String) async {
        struct Reply: Decodable { var counted: Bool? }
        let _: Reply? = try? await call(["action": "played", "id": drillID], timeout: 15)
    }
}
