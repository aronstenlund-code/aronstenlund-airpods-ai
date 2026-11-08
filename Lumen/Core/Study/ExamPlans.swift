import Foundation
import Observation

/// D86: one upcoming exam the user added ("Biologiprovet, fre 14 nov, åk 9"). Several are kept; the nearest one is
/// the card on the start screen and the profile Provläge uses unless another is picked.
struct ExamPlan: Codable, Equatable, Identifiable, Sendable {
    enum Area: String, Codable, CaseIterable, Sendable {
        case matte, no, so, sprak, praktiskt, annat

        var title: String {
            switch self {
            case .matte: "Matte"
            case .no: "NO"
            case .so: "SO"
            case .sprak: "Språk"
            case .praktiskt: "Praktiskt"
            case .annat: "Annat"
            }
        }

        var subjects: [String] {
            switch self {
            case .matte: []
            case .no: ["Biologi", "Fysik", "Kemi", "Teknik"]
            case .so: ["Historia", "Geografi", "Religion", "Samhällskunskap"]
            case .sprak: ["Svenska", "Engelska", "Spanska", "Tyska", "Franska"]
            case .praktiskt: ["Bild", "Musik", "Idrott", "Hemkunskap", "Slöjd"]
            case .annat: []
            }
        }

        static func of(subject: String) -> Area {
            if subject.lowercased().hasPrefix("mat") { return .matte }
            return allCases.first { $0.subjects.contains { $0.caseInsensitiveCompare(subject) == .orderedSame } } ?? .annat
        }
    }

    var id = UUID()
    var grade: StudyProfile.Grade?
    var course = ""
    var area: Area
    var subject: String
    var date: Date
    var topics = ""

    /// "Biologiprovet", "Matteprovet", "Provet i Filosofi".
    var name: String {
        let s = subject.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty else { return "Provet" }
        if area == .matte { return "Matteprovet" }
        if area == .annat, !StudyProfile.subjects.contains(s) { return "Provet i \(s)" }
        return s.prefix(1).uppercased() + s.dropFirst().lowercased() + "provet"
    }

    func daysLeft(now: Date = Date(), calendar: Calendar = .current) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: date)).day ?? 0
    }

    /// "Fre 14 nov, åk 9"
    func dateLine(calendar: Calendar = .current) -> String {
        var line = Self.shortDate(date, calendar: calendar)
        if let grade { line += ", " + StudyProfile.gradeName(grade).lowercased() }
        return line
    }

    /// "Ons 19 nov, om 10 dagar"
    func whenLine(now: Date = Date(), calendar: Calendar = .current) -> String {
        Self.shortDate(date, calendar: calendar) + ", " + Self.inDays(daysLeft(now: now, calendar: calendar))
    }

    static func inDays(_ days: Int) -> String {
        switch days {
        case ..<0: "har varit"
        case 0: "idag"
        case 1: "imorgon"
        default: "om \(days) dagar"
        }
    }

    /// "5 dagar kvar", "1 dag kvar", "Idag".
    static func daysLeftText(_ days: Int) -> String {
        switch days {
        case ..<1: "Idag"
        case 1: "1 dag kvar"
        default: "\(days) dagar kvar"
        }
    }

    static func shortDate(_ date: Date, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "sv_SE")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "EEE d MMM"
        let text = formatter.string(from: date).replacingOccurrences(of: ".", with: "")
        return text.prefix(1).uppercased() + text.dropFirst()
    }

    /// Into the D83/D84 profile that Provläge sends: grade, course, subject, date, what is on the exam.
    func apply(to profile: inout StudyProfile) {
        if let grade { profile.grade = grade }
        profile.course = course
        profile.subject = area == .matte ? "Matematik" : subject
        profile.examDate = date
        profile.noExam = false
        profile.topics = topics.isEmpty ? nil : topics
    }
}

/// D87: Provläge's Scribe keyterms come from the active exam first: the subject, the course, what is on the exam,
/// then Kevin's subject terms from `/study-profile`. Scribe takes 20, so these always win. Pure.
enum ExamKeyterms {
    static func terms(profile: StudyProfile) -> [String] {
        var out: [String] = []
        func add(_ raw: String) {
            let term = raw.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
            guard term.count >= 2, term.count <= 40, !out.contains(where: { $0.caseInsensitiveCompare(term) == .orderedSame }) else { return }
            out.append(term)
        }
        add(profile.subject)
        add(profile.course)
        for part in (profile.topics ?? "").components(separatedBy: CharacterSet(charactersIn: ",;\n")) {
            for piece in part.components(separatedBy: " och ") {
                let word = piece.trimmingCharacters(in: .whitespacesAndNewlines)
                if !word.lowercased().hasPrefix("kapitel") { add(word) } // "kapitel 4" is no word to hear
            }
        }
        (profile.terms ?? []).forEach(add)
        return out
    }

    /// The exam's terms first, then everything else, each once.
    static func merged(exam: [String], rest: [String]) -> [String] {
        var out = exam
        for term in rest where !out.contains(where: { $0.caseInsensitiveCompare(term) == .orderedSame }) { out.append(term) }
        return out
    }
}

@MainActor
@Observable
final class ExamPlanStore {
    private(set) var plans: [ExamPlan] = []
    private let file: LocalJSONFile

    init(directory: URL = NotesStore.defaultDirectory) {
        file = LocalJSONFile(url: directory.appendingPathComponent("exam-plans.json"))
        plans = (try? file.load([ExamPlan].self)) ?? []
    }

    /// Exams from today on, nearest first.
    func upcoming(now: Date = Date()) -> [ExamPlan] {
        plans.filter { $0.daysLeft(now: now) >= 0 }.sorted { $0.date < $1.date }
    }

    func nearest(now: Date = Date()) -> ExamPlan? { upcoming(now: now).first }

    /// A new exam, or the same subject on the same day updated (a voice statement said twice is one exam).
    func save(_ plan: ExamPlan) {
        if let index = plans.firstIndex(where: { $0.id == plan.id }) {
            plans[index] = plan
        } else if let index = plans.firstIndex(where: {
            $0.subject.caseInsensitiveCompare(plan.subject) == .orderedSame && Calendar.current.isDate($0.date, inSameDayAs: plan.date)
        }) {
            var merged = plan
            merged.id = plans[index].id
            plans[index] = merged
        } else {
            plans.append(plan)
        }
        persist()
    }

    func delete(_ id: UUID) {
        plans.removeAll { $0.id == id }
        persist()
    }

    private func persist() {
        do { try file.save(plans) } catch {
            Log.session.error("Exams not saved: \(error.localizedDescription, privacy: .public)")
        }
    }
}
