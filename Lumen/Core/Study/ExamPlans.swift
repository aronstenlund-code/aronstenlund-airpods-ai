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
    /// T24-M1 (D189): the repetition exam (`Drill`) this plan mirrors. Nil for an exam said aloud in Provläge.
    var drillID: UUID?
    /// D189: the repetition exam's own name ("Vad är magma", "Biologi åk 8"), used as the plan's name.
    var title: String?
    /// D189: a repetition exam without a date (only a school's published exam has one). Nil = the date is real.
    var undated: Bool?

    var hasDate: Bool { undated != true }

    /// "Biologiprovet", "Matteprovet", "Provet i Filosofi"; a repetition exam's own name (D189).
    var name: String {
        if let title = title?.trimmingCharacters(in: .whitespaces), !title.isEmpty { return title }
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
        var line = hasDate ? Self.shortDate(date, calendar: calendar) : Self.noDateLine
        if let grade { line += ", " + StudyProfile.gradeName(grade).lowercased() }
        return line
    }

    /// "Ons 19 nov, om 10 dagar"
    func whenLine(now: Date = Date(), calendar: Calendar = .current) -> String {
        guard hasDate else { return Self.noDateLine }
        return Self.shortDate(date, calendar: calendar) + ", " + Self.inDays(daysLeft(now: now, calendar: calendar))
    }

    /// D189: a repetition exam without a date.
    static let noDateLine = "Inget datum"

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

    /// Exams from today on, nearest first; repetition exams without a date last, newest first (D189).
    func upcoming(now: Date = Date()) -> [ExamPlan] {
        let dated = plans.filter { $0.hasDate && $0.daysLeft(now: now) >= 0 }.sorted { $0.date < $1.date }
        return dated + plans.filter { !$0.hasDate }.reversed()
    }

    /// D189: only exams with a real date, for the countdown, the study plan, reminders and the widget.
    func upcomingDated(now: Date = Date()) -> [ExamPlan] { upcoming(now: now).filter(\.hasDate) }

    func nearest(now: Date = Date()) -> ExamPlan? { upcoming(now: now).first }

    /// T24-M1 (D189): the repetition exams are the user's exams. One plan per exam in `drills`, kept in step: a new
    /// exam adds one, a renamed or dated one updates it, a deleted one removes it (with its Mina svar left for the
    /// store to keep). Plans said aloud in Provläge (no `drillID`) are left as they are.
    func sync(with drills: [Drill], now: Date = Date()) {
        var changed = false
        let ids = Set(drills.map(\.id))
        let before = plans.count
        plans.removeAll { $0.drillID.map { !ids.contains($0) } ?? false }
        changed = changed || plans.count != before
        for drill in drills {
            let mirrored = Self.plan(for: drill, now: now)
            if let index = plans.firstIndex(where: { $0.drillID == drill.id }) {
                var plan = plans[index]
                if plan.title != mirrored.title || plan.subject != mirrored.subject || plan.undated != mirrored.undated
                    || (mirrored.hasDate && plan.date != mirrored.date) {
                    plan.title = mirrored.title
                    plan.subject = mirrored.subject
                    plan.area = mirrored.area
                    plan.undated = mirrored.undated
                    if mirrored.hasDate { plan.date = mirrored.date }
                    plans[index] = plan
                    changed = true
                }
            } else {
                plans.append(mirrored)
                changed = true
            }
        }
        if changed { persist() }
    }

    /// D189: a repetition exam as a plan: its name, subject and grade, and the school's date when it has one.
    static func plan(for drill: Drill, now: Date = Date()) -> ExamPlan {
        let subject = drill.summary.subject.trimmingCharacters(in: .whitespaces)
        let date = drill.publication?.examDate
        var plan = ExamPlan(grade: nil, area: .of(subject: subject),
                            subject: subject, date: date ?? now)
        plan.id = drill.id // the same id, so Mina svar recorded for it follow the exam
        plan.drillID = drill.id
        plan.title = drill.title
        plan.undated = date == nil ? true : nil
        return plan
    }

    /// A new exam, or the same subject on the same day updated (a voice statement said twice is one exam).
    func save(_ plan: ExamPlan) {
        if let index = plans.firstIndex(where: { $0.id == plan.id }) {
            plans[index] = plan
        } else if let index = plans.firstIndex(where: {
            $0.drillID == nil && plan.drillID == nil && $0.hasDate && plan.hasDate &&
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
