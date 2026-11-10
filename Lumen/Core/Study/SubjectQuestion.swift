import Foundation

/// A24 (PLAN 2b standing task, Kelly Ke9): the first start lets an exam be just an area ("NO"). The first time
/// Provläge starts for such an exam, Lumen asks once which subject it is, and the answer ("biologi", "det är fysik")
/// makes it a real subject, so the exam gets its own words and the right name ("Biologiprovet").
enum SubjectQuestion {
    /// The area an exam stands for when its subject is only the area's name ("NO", "SO", "Språk", "Praktiskt").
    static func area(of plan: ExamPlan) -> ExamPlan.Area? {
        let subject = plan.subject.trimmingCharacters(in: .whitespaces)
        return ExamPlan.Area.allCases.first {
            !$0.subjects.isEmpty && $0.title.caseInsensitiveCompare(subject) == .orderedSame
        }
    }

    static func prompt(for area: ExamPlan.Area) -> String {
        let examples = area.subjects.prefix(2).map { $0.lowercased() }.joined(separator: " eller ")
        return "Vilket ämne i \(area.title) är provet i? Säg till exempel \(examples)."
    }

    /// The subject in a short answer ("biologi", "det är fysik", "Kemi tror jag"). Nil: the words were something else.
    static func subject(in text: String, area: ExamPlan.Area) -> String? {
        let words = text.lowercased().split(whereSeparator: { !$0.isLetter }).map(String.init)
        guard !words.isEmpty, words.count <= 5 else { return nil }
        return area.subjects.first { subject in words.contains(subject.lowercased()) }
    }
}
