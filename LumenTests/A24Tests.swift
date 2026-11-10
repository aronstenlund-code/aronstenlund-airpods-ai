import Foundation
import Testing
@testable import Lumen

/// A24: an exam that is only an area asks for its subject once.
@Suite struct SubjectQuestionTests {
    private func plan(_ area: ExamPlan.Area, _ subject: String) -> ExamPlan {
        ExamPlan(area: area, subject: subject, date: Date(timeIntervalSince1970: 6_000_000))
    }

    @Test func onlyAnAreaIsAsked() {
        #expect(SubjectQuestion.area(of: plan(.no, "NO")) == .no)
        #expect(SubjectQuestion.area(of: plan(.sprak, "Språk")) == .sprak)
        #expect(SubjectQuestion.area(of: plan(.no, "Biologi")) == nil)
        #expect(SubjectQuestion.area(of: plan(.matte, "Matematik")) == nil, "Matte has no sub-subjects")
    }

    @Test func thePromptNamesExamples() {
        #expect(SubjectQuestion.prompt(for: .no) == "Vilket ämne i NO är provet i? Säg till exempel biologi eller fysik.")
    }

    @Test func shortAnswersFindTheSubject() {
        #expect(SubjectQuestion.subject(in: "Biologi", area: .no) == "Biologi")
        #expect(SubjectQuestion.subject(in: "det är fysik", area: .no) == "Fysik")
        #expect(SubjectQuestion.subject(in: "kemi tror jag", area: .no) == "Kemi")
        #expect(SubjectQuestion.subject(in: "historia", area: .no) == nil, "not an NO subject")
        #expect(SubjectQuestion.subject(in: "vad är fotosyntesen i biologi egentligen för något", area: .no) == nil,
                "a question, not an answer")
    }
}
