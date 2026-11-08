import Foundation
import Testing
@testable import Lumen

/// D86: the logic behind the new screens (the look itself is checked on device).
@Suite struct ExamPlanTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Stockholm")!
        return calendar
    }
    /// Sunday 8 November 2026, noon.
    private var now: Date { calendar.date(from: DateComponents(year: 2026, month: 11, day: 8, hour: 12))! }
    private func day(_ d: Int) -> Date { calendar.date(from: DateComponents(year: 2026, month: 11, day: d))! }

    @Test func namesAndDays() {
        let biology = ExamPlan(grade: .y9, area: .no, subject: "Biologi", date: day(13))
        #expect(biology.name == "Biologiprovet")
        #expect(biology.daysLeft(now: now, calendar: calendar) == 5)
        #expect(ExamPlan.daysLeftText(5) == "5 dagar kvar")
        #expect(ExamPlan.daysLeftText(1) == "1 dag kvar")
        #expect(ExamPlan.daysLeftText(0) == "Idag")
        #expect(ExamPlan.shortDate(day(13), calendar: calendar) == "Fre 13 nov")
        #expect(biology.dateLine(calendar: calendar) == "Fre 13 nov, åk 9")
        #expect(biology.whenLine(now: now, calendar: calendar) == "Fre 13 nov, om 5 dagar")
        #expect(ExamPlan(area: .matte, subject: "Matematik", date: day(13)).name == "Matteprovet")
        #expect(ExamPlan(area: .annat, subject: "Filosofi", date: day(13)).name == "Provet i Filosofi")
        #expect(!biology.name.contains("·"), "no middle dots")
    }

    @Test func areasFoldOutTheirSubjects() {
        #expect(ExamPlan.Area.no.subjects == ["Biologi", "Fysik", "Kemi", "Teknik"])
        #expect(ExamPlan.Area.so.subjects == ["Historia", "Geografi", "Religion", "Samhällskunskap"])
        #expect(ExamPlan.Area.sprak.subjects == ["Svenska", "Engelska", "Spanska", "Tyska", "Franska"])
        #expect(ExamPlan.Area.praktiskt.subjects == ["Bild", "Musik", "Idrott", "Hemkunskap", "Slöjd"])
        #expect(ExamPlan.Area.of(subject: "kemi") == .no)
        #expect(ExamPlan.Area.of(subject: "Matematik") == .matte)
    }

    @Test func theExamBecomesTheProfile() {
        var plan = ExamPlan(grade: .gy2, course: "Biologi 1", area: .no, subject: "Biologi", date: day(13))
        plan.topics = "fotosyntes, cellandning"
        var profile = StudyProfile()
        profile.explanations = .short
        plan.apply(to: &profile)
        #expect(profile.grade == .gy2)
        #expect(profile.course == "Biologi 1")
        #expect(profile.subject == "Biologi")
        #expect(profile.explanations == .short, "the user's own settings stay")
        #expect(profile.setupText(now: now, calendar: calendar)?.contains("På provet: fotosyntes, cellandning.") == true)
    }

    @MainActor @Test func severalExamsNearestFirst() {
        let directory = tempDirectory("plans")
        let store = ExamPlanStore(directory: directory)
        let today = Calendar.current.startOfDay(for: Date())
        let soon = Calendar.current.date(byAdding: .day, value: 5, to: today)!
        let later = Calendar.current.date(byAdding: .day, value: 10, to: today)!
        let past = Calendar.current.date(byAdding: .day, value: -3, to: today)!
        store.save(ExamPlan(area: .sprak, subject: "Engelska", date: later))
        store.save(ExamPlan(area: .no, subject: "Biologi", date: soon))
        store.save(ExamPlan(area: .so, subject: "Historia", date: past))
        #expect(store.upcoming().map(\.subject) == ["Biologi", "Engelska"], "nearest first, past exams hidden")
        store.save(ExamPlan(area: .no, subject: "biologi", date: soon, topics: "celler"))
        #expect(store.plans.count == 3, "the same subject on the same day is one exam")
        #expect(ExamPlanStore(directory: directory).plans.count == 3, "saved on the phone")
    }
}

@MainActor
@Suite struct AppearanceTests {
    @Test func followsTheIPhoneByDefault() {
        let settings = AppearanceSettings(defaults: freshTestDefaults())
        #expect(settings.appearance == .system)
        #expect(settings.colorScheme == nil)
        #expect(settings.handwriting, "handwriting for questions is on by default")
        settings.appearance = .dark
        #expect(settings.colorScheme == .dark)
    }
}

@Suite struct ProblemTests {
    @Test func failuresBecomeSwedishProblems() {
        #expect(ListeningModel.problem(for: .offline) == .offline)
        #expect(ListeningModel.problem(for: .transport(detail: "x")) == .offline)
        #expect(ListeningModel.problem(for: .backend(status: 529, failure: AnswerFailure(code: "overloaded"))) == .overloaded)
        #expect(ListeningModel.problem(for: .cancelled) == nil)
        for problem in [LumenProblem.microphoneDenied, .offline, .airPodsDisconnected, .overloaded] {
            #expect(!problem.title.contains("HTTP") && !problem.text.contains("HTTP"), "never a code")
        }
        #expect(LumenProblem.offline.spoken == "Ingen internetanslutning.")
        #expect(LumenProblem.overloaded.spoken == "Försök igen om en minut.")
        #expect(LumenProblem.microphoneDenied.actionTitle == "Öppna Inställningar")
    }

    @Test func quizMeIsOneCheckQuestion() {
        #expect(MiniTest.isCheckQuestionRequest("förhör mig"))
        #expect(!MiniTest.isStartCommand("förhör mig"))
        #expect(MiniTest.isStartCommand("minitest"))
    }
}
