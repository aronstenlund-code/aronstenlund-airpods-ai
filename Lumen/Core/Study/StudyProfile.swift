import Foundation
import Observation

/// D83: what Provläge asks the first time, one question per screen, every one skippable. Sent as `persona: "tutor"`
/// with `persona_setup` on every Provläge call, and mirrored into Minne (D80) with the exam's absolute date.
struct StudyProfile: Codable, Equatable, Sendable {
    enum ExamWhen: String, Codable, CaseIterable, Sendable { case today, tomorrow, withinWeek, later, none }
    enum Grade: String, Codable, CaseIterable, Sendable { case y6, y7, y8, y9, gy1, gy2, gy3, university, other }
    enum CheckQuestions: String, Codable, CaseIterable, Sendable { case none, yesNo, short, hard }
    enum Explanations: String, Codable, CaseIterable, Sendable { case short, medium, detailed }

    var examDate: Date?
    /// "Inget prov just nu".
    var noExam = false
    var grade: Grade?
    /// Gymnasiet: the course, e.g. "Matematik 1c".
    var course = ""
    var subject = ""
    var checkQuestions: CheckQuestions?
    var explanations: Explanations?
    /// The first-start questions were answered or skipped.
    var onboarded = false
    /// D84: 30–50 central terms for the grade and subject (Kevin's `/study-profile`), for Scribe and `prep_terms`.
    var terms: [String]?
    /// D86: "Vad kommer på provet?", as typed (chapters, areas, concepts).
    var topics: String?

    static let subjects = ["Matematik", "Svenska", "Engelska", "Biologi", "Fysik", "Kemi", "Historia", "Samhällskunskap",
                           "Geografi", "Religion", "Spanska", "Tyska", "Franska", "Teknik", "Programmering"]

    /// The exam's absolute date for a quick answer. "Inom en vecka" means a week from today; "Senare" uses a picked date.
    static func examDate(for when: ExamWhen, now: Date, calendar: Calendar = .current) -> Date? {
        let today = calendar.startOfDay(for: now)
        switch when {
        case .today: return today
        case .tomorrow: return calendar.date(byAdding: .day, value: 1, to: today)
        case .withinWeek: return calendar.date(byAdding: .day, value: 7, to: today)
        case .later, .none: return nil
        }
    }

    static func gradeName(_ grade: Grade) -> String {
        switch grade {
        case .y6: "Åk 6"
        case .y7: "Åk 7"
        case .y8: "Åk 8"
        case .y9: "Åk 9"
        case .gy1: "Gymnasiet 1"
        case .gy2: "Gymnasiet 2"
        case .gy3: "Gymnasiet 3"
        case .university: "Högskola"
        case .other: "Annat"
        }
    }

    static func checkName(_ check: CheckQuestions) -> String {
        switch check {
        case .none: "Inga kontrollfrågor"
        case .yesNo: "Ja–nej-frågor (svara med rösten eller nicka)"
        case .short: "Korta frågor"
        case .hard: "Svåra frågor"
        }
    }

    static func explanationName(_ length: Explanations) -> String {
        switch length {
        case .short: "Korta förklaringar"
        case .medium: "Mellanlånga förklaringar"
        case .detailed: "Utförliga förklaringar"
        }
    }

    /// "fredag 14 november 2026", always absolute (D80).
    static func dateText(_ date: Date, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "sv_SE")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "EEEE d MMMM yyyy"
        return formatter.string(from: date)
    }

    /// `persona_setup` for Provläge: everything answered, in plain Swedish. Nil when nothing was answered.
    func setupText(now: Date = Date(), calendar: Calendar = .current) -> String? {
        var lines: [String] = []
        if noExam {
            lines.append("Inget prov just nu.")
        } else if let examDate {
            let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: examDate)).day ?? 0
            let when = days == 0 ? "idag" : days == 1 ? "imorgon" : days > 1 ? "om \(days) dagar" : "har varit"
            lines.append("Prov\(subject.isEmpty ? "" : " i \(subject)") \(Self.dateText(examDate, calendar: calendar)) (\(when)).")
        }
        if let grade { lines.append("Årskurs: \(Self.gradeName(grade))\(course.isEmpty ? "" : ", kurs \(course)").") }
        if !subject.isEmpty, examDate == nil || noExam { lines.append("Ämne: \(subject).") }
        if let topics, !topics.isEmpty { lines.append("På provet: \(topics).") }
        if let checkQuestions { lines.append("Kontrollfrågor: \(Self.checkName(checkQuestions)).") }
        if let explanations { lines.append("Förklaringar: \(Self.explanationName(explanations).lowercased()).") }
        return lines.isEmpty ? nil : String(lines.joined(separator: " ").prefix(1_500))
    }

    /// Facts for Minne, each starting with "Provprofil:" so a change replaces them.
    func memoryFacts(calendar: Calendar = .current) -> [String] {
        var facts: [String] = []
        if let examDate, !noExam {
            facts.append("Provprofil: prov\(subject.isEmpty ? "" : " i \(subject)") \(Self.dateText(examDate, calendar: calendar))")
        }
        if let grade { facts.append("Provprofil: \(Self.gradeName(grade))\(course.isEmpty ? "" : ", \(course)")") }
        return facts
    }
}

/// D83: the profile on this phone (UserDefaults).
@MainActor
@Observable
final class StudyProfileStore {
    static let key = "study.profile"
    var profile: StudyProfile {
        didSet { save() }
    }
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key), let stored = try? JSONDecoder().decode(StudyProfile.self, from: data) {
            profile = stored
        } else {
            profile = StudyProfile()
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(profile) { defaults.set(data, forKey: Self.key) }
    }
}

/// D83: "Lumen, korta förklaringar", "Lumen, inga kontrollfrågor", "Lumen, provet är på fredag", "Lumen, ämne
/// biologi", "Lumen, inget prov" change the profile by voice. Pure; unit-tested.
enum StudyProfileVoice {
    static func apply(_ command: String, to profile: inout StudyProfile, now: Date = Date(), calendar: Calendar = .current) -> Bool {
        let words = VoiceChannel.normalized(command)
        let compact = words.replacingOccurrences(of: " ", with: "")
        switch compact {
        case "kortaförklaringar": profile.explanations = .short; return true
        case "mellanlångaförklaringar", "mellanförklaringar": profile.explanations = .medium; return true
        case "utförligaförklaringar", "längreförklaringar": profile.explanations = .detailed; return true
        case "ingakontrollfrågor": profile.checkQuestions = CheckQuestionsAlias.none; return true
        case "janejfrågor", "jaochnejfrågor": profile.checkQuestions = .yesNo; return true
        case "kortafrågor", "kortakontrollfrågor": profile.checkQuestions = .short; return true
        case "svårafrågor", "svårakontrollfrågor": profile.checkQuestions = .hard; return true
        case "ingetprov", "ingetprovjustnu": profile.noExam = true; profile.examDate = nil; return true
        default: break
        }
        for prefix in ["ämne ", "ämnet är ", "ämnet ", "subject "] where words.hasPrefix(prefix) {
            let subject = command.split(separator: " ").dropFirst(prefix.split(separator: " ").count).joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
            guard !subject.isEmpty else { return false }
            profile.subject = subject.prefix(1).uppercased() + subject.dropFirst()
            return true
        }
        for prefix in ["provet är på ", "provet är ", "prov på ", "provet "] where words.hasPrefix(prefix) {
            let rest = String(words.dropFirst(prefix.count))
            if let date = date(from: rest, now: now, calendar: calendar) {
                profile.examDate = date
                profile.noExam = false
                return true
            }
        }
        return false
    }

    private enum CheckQuestionsAlias {
        static let none = StudyProfile.CheckQuestions.none
    }

    private static let weekdays = ["måndag": 2, "tisdag": 3, "onsdag": 4, "torsdag": 5, "fredag": 6, "lördag": 7, "söndag": 1]
    private static let months = ["januari": 1, "februari": 2, "mars": 3, "april": 4, "maj": 5, "juni": 6, "juli": 7,
                                 "augusti": 8, "september": 9, "oktober": 10, "november": 11, "december": 12,
                                 "jan": 1, "feb": 2, "mar": 3, "apr": 4, "jun": 6, "jul": 7, "aug": 8, "sep": 9,
                                 "okt": 10, "nov": 11, "dec": 12]

    /// "idag", "imorgon", "fredag" (the next one), "om 3 dagar", "14 november", "den 14 nov".
    static func date(from text: String, now: Date, calendar: Calendar = .current) -> Date? {
        let today = calendar.startOfDay(for: now)
        let words = text.split(separator: " ").map(String.init).filter { $0 != "den" && $0 != "på" }
        guard let first = words.first else { return nil }
        if first == "idag" { return today }
        if first == "imorgon" { return calendar.date(byAdding: .day, value: 1, to: today) }
        if first == "om", words.count >= 3, let days = Int(words[1]), words[2].hasPrefix("dag") {
            return calendar.date(byAdding: .day, value: days, to: today)
        }
        if let weekday = weekdays[first] {
            let current = calendar.component(.weekday, from: today)
            var ahead = (weekday - current + 7) % 7
            if ahead == 0 { ahead = 7 }
            return calendar.date(byAdding: .day, value: ahead, to: today)
        }
        if let day = Int(first), words.count >= 2, let month = months[words[1]] {
            var components = calendar.dateComponents([.year], from: today)
            components.month = month
            components.day = day
            guard var date = calendar.date(from: components) else { return nil }
            if date < today { date = calendar.date(byAdding: .year, value: 1, to: date) ?? date }
            return date
        }
        return nil
    }
}

/// D83: the subscription gate for Rizzläge and Socialt läge, prepared only. No purchase code until there is a paid
/// Apple Developer account; the flag is off, so every mode is open.
enum ModeAccess {
    static let liveModesNeedSubscription = false

    static func isOpen(_ mode: ConversationMode, subscribed: Bool = false) -> Bool {
        guard liveModesNeedSubscription, mode.isLive else { return true }
        return subscribed
    }
}
