import Foundation

/// D84: "Lumen, jag går i åk 9 och ska snart ha prov i biologi på fredag" in any mode. Read on the phone first, so
/// the confirmation ("Biologi åk 9, sparat") comes at once and works offline; the backend may add to it later.
struct ProfileStatement: Equatable, Sendable {
    var grade: StudyProfile.Grade?
    var course: String?
    var subject: String?
    var examDate: Date?

    var isEmpty: Bool { grade == nil && subject == nil && examDate == nil }

    /// A statement about the wearer's school: "jag går i …", "jag läser …", "… ska ha prov i …".
    static func isAboutSchool(_ text: String) -> Bool {
        let words = VoiceChannel.normalized(text)
        guard words.hasPrefix("jag ") || words.hasPrefix("vi ") else { return false } // a statement, not a question
        if words.range(of: #"jag (går|läser) (i|på|ettan|tvåan|trean|sexan|sjuan|åttan|nian|kursen)\b"#, options: .regularExpression) != nil {
            return true
        }
        return ["prov i ", "provet i ", "prov på ", "kursen "].contains { words.contains($0) }
    }

    static func parse(_ text: String, now: Date = Date(), calendar: Calendar = .current) -> ProfileStatement? {
        guard isAboutSchool(text) else { return nil }
        let words = VoiceChannel.normalized(text)
        var result = ProfileStatement()
        result.grade = grade(in: words)
        if result.grade?.isGymnasium == true { result.course = course(in: text) }
        result.subject = subject(in: words)
        if let range = words.range(of: #"\b(på|om|imorgon|idag|den|nästa)\b.*$"#, options: .regularExpression,
                                   range: (words.range(of: "prov")?.upperBound ?? words.startIndex)..<words.endIndex) {
            var rest = String(words[range])
            if rest.hasPrefix("nästa ") { rest = String(rest.dropFirst("nästa ".count)) }
            result.examDate = StudyProfileVoice.date(from: rest, now: now, calendar: calendar)
        }
        return result.isEmpty ? nil : result
    }

    private static let yearWords = ["sexan": StudyProfile.Grade.y6, "sjuan": .y7, "åttan": .y8, "nian": .y9]

    static func grade(in words: String) -> StudyProfile.Grade? {
        if let match = words.range(of: #"(åk|årskurs|klass) ?([6-9])\b"#, options: .regularExpression) {
            switch words[match].last ?? " " {
            case "6": return .y6
            case "7": return .y7
            case "8": return .y8
            case "9": return .y9
            default: break
            }
        }
        for (word, grade) in yearWords where words.contains(" \(word)") || words.hasPrefix(word) {
            if !words.contains("gymnas") { return grade }
        }
        if words.contains("gymnas") {
            if words.contains("trean") || words.range(of: #"gymnasiet? ?3|år 3|tredje"#, options: .regularExpression) != nil { return .gy3 }
            if words.contains("tvåan") || words.range(of: #"gymnasiet? ?2|år 2|andra"#, options: .regularExpression) != nil { return .gy2 }
            return .gy1
        }
        if words.contains("högskola") || words.contains("universitet") || words.contains("uni ") { return .university }
        return nil
    }

    /// "Matematik 1c", "Biologi 2": a subject with a course number, as said.
    static func course(in text: String) -> String? {
        guard let match = text.range(of: #"[A-ZÅÄÖa-zåäö]+ ?[1-5][a-c]?\b"#, options: .regularExpression) else { return nil }
        let course = String(text[match])
        guard StudyProfile.subjects.contains(where: { course.lowercased().hasPrefix($0.lowercased()) }) else { return nil }
        return course.prefix(1).uppercased() + course.dropFirst()
    }

    /// The word after "prov i" / "provet i", or a known subject named anywhere.
    static func subject(in words: String) -> String? {
        if let range = words.range(of: #"prov(et)? i ([a-zåäö]+)"#, options: .regularExpression) {
            let word = String(words[range].split(separator: " ").last ?? "")
            if !["morgon", "dag"].contains(word) { return word.prefix(1).uppercased() + word.dropFirst() }
        }
        return StudyProfile.subjects.first { words.contains($0.lowercased()) }
    }

    /// "Biologi åk 9, sparat."
    func confirmation() -> String {
        var parts: [String] = []
        if let subject { parts.append(subject) }
        if let grade { parts.append(grade.spoken) }
        if let examDate { parts.append("prov " + StudyProfile.dateText(examDate)) }
        return parts.joined(separator: " ") + ", sparat."
    }

    /// Into the D83 profile; what was not said stays as it was.
    func apply(to profile: inout StudyProfile) {
        if let grade { profile.grade = grade }
        if let course { profile.course = course }
        if let subject { profile.subject = subject }
        if let examDate {
            profile.examDate = examDate
            profile.noExam = false
        }
    }
}

extension StudyProfile.Grade {
    var isGymnasium: Bool { self == .gy1 || self == .gy2 || self == .gy3 }

    /// As it is said: "åk 9", "gymnasiet 2".
    var spoken: String { StudyProfile.gradeName(self).lowercased() }
}

/// D84: `POST /functions/v1/study-profile` (Kevin). The words after "Lumen," → the profile as the server reads it,
/// with an absolute date, and 30–50 terms for the subject. The phone's own reading has already answered; this adds
/// the terms and corrects what the phone could not read.
struct StudyProfileReply: Decodable, Equatable, Sendable {
    struct Profile: Decodable, Equatable, Sendable {
        var grade: String?
        var course: String?
        var subject: String?
        var examDate: String?
        var noExam: Bool?
    }
    var profile: Profile
    var terms: [String]

    /// Into the D83 profile: only what the server read; nothing it left empty is cleared.
    func apply(to target: inout StudyProfile, calendar: Calendar = .current) {
        if let grade = profile.grade.flatMap(StudyProfile.Grade.init(rawValue:)) { target.grade = grade }
        if let course = profile.course, !course.isEmpty { target.course = course }
        if let subject = profile.subject, !subject.isEmpty { target.subject = subject }
        if let iso = profile.examDate, let date = Self.date(iso, calendar: calendar) {
            target.examDate = date
            target.noExam = false
        } else if profile.noExam == true {
            target.examDate = nil
            target.noExam = true
        }
        if !terms.isEmpty { target.terms = Array(terms.prefix(50)) }
    }

    /// "2026-11-13" as midnight that day on this phone.
    static func date(_ iso: String, calendar: Calendar = .current) -> Date? {
        let parts = iso.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }
}

@MainActor
final class StudyProfileClient {
    struct Body: Encodable, Sendable {
        struct Known: Encodable, Sendable {
            var grade: String?
            var course: String?
            var subject: String?
            var examDate: String?
        }
        var text: String
        var profile: Known?
        var language: String
    }

    private let config: BackendConfig
    private let auth: SupabaseAuth
    private let http: any HTTPStreaming

    init(config: BackendConfig, auth: SupabaseAuth, http: any HTTPStreaming) {
        self.config = config
        self.auth = auth
        self.http = http
    }

    static func body(text: String, profile: StudyProfile, swedish: Bool, calendar: Calendar = .current) -> Body {
        let date = profile.examDate.map { d -> String in
            let c = calendar.dateComponents([.year, .month, .day], from: d)
            return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
        }
        let known = Body.Known(grade: profile.grade?.rawValue, course: profile.course.isEmpty ? nil : profile.course,
                               subject: profile.subject.isEmpty ? nil : profile.subject, examDate: date)
        return Body(text: String(text.prefix(600)), profile: known, language: swedish ? "sv" : "en")
    }

    func read(_ body: Body) async -> StudyProfileReply? {
        do {
            let token = try await auth.accessToken()
            var request = URLRequest(url: config.studyProfileURL)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue(config.publishableKey, forHTTPHeaderField: "apikey")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 15
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            request.httpBody = try encoder.encode(body)
            let (response, data) = try await http.data(for: request)
            guard response.statusCode == 200 else {
                Log.answer.error("study profile: HTTP \(response.statusCode, privacy: .public)")
                return nil
            }
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(StudyProfileReply.self, from: data)
        } catch {
            return nil
        }
    }
}

/// A33 (D109): the answer to "Har du prov snart? Säg vilket ämne och när." asked aloud in the first start. A short
/// answer ("biologi på fredag", "ja, matte nästa tisdag") becomes a statement the phone and `/study-profile` read; "nej"
/// declines. Pure.
enum ExamAnswer {
    static func isDecline(_ text: String) -> Bool {
        let words = VoiceChannel.normalized(text)
        if ["nej", "nä", "nää", "nope", "inte nu", "nej tack", "inget prov", "inga prov", "jag har inget prov",
            "jag har inga prov", "inte än", "nej inte än", "nej det har jag inte"].contains(words) { return true }
        return words.hasPrefix("nej ") && !words.contains("prov i") && !words.contains(" på ")
    }

    /// The answer as a statement about an exam.
    static func statement(_ text: String) -> String {
        if ProfileStatement.isAboutSchool(text) { return text }
        var words = VoiceChannel.normalized(text)
        for lead in ["ja ", "japp ", "jo ", "ja det har jag ", "ja jag har ", "det är ", "i "] where words.hasPrefix(lead) {
            words = String(words.dropFirst(lead.count))
        }
        if words.hasPrefix("prov i ") { words = String(words.dropFirst("prov i ".count)) }
        return "jag har prov i " + words
    }
}

