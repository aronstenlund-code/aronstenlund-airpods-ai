import Foundation
import Testing
@testable import Lumen

/// D84: "Lumen, jag går i åk … och ska snart ha prov i …".
@Suite struct ProfileStatementTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Stockholm")!
        return calendar
    }
    /// Sunday 8 November 2026, noon.
    private var now: Date { calendar.date(from: DateComponents(year: 2026, month: 11, day: 8, hour: 12))! }

    @Test func gradeSubjectAndDate() throws {
        let statement = try #require(ProfileStatement.parse("jag går i åk 9 och ska snart ha prov i biologi på fredag", now: now, calendar: calendar))
        #expect(statement.grade == .y9)
        #expect(statement.subject == "Biologi")
        #expect(calendar.component(.day, from: try #require(statement.examDate)) == 13)
        #expect(statement.confirmation().hasPrefix("Biologi åk 9 prov "))
        #expect(statement.confirmation().hasSuffix(", sparat."))
    }

    @Test func gymnasiumWithCourse() throws {
        let statement = try #require(ProfileStatement.parse("jag går tvåan på gymnasiet och har prov i Matematik 2c imorgon", now: now, calendar: calendar))
        #expect(statement.grade == .gy2)
        #expect(statement.course == "Matematik 2c")
        #expect(calendar.component(.day, from: try #require(statement.examDate)) == 9)
    }

    @Test func spokenYears() {
        #expect(ProfileStatement.parse("jag går i nian", now: now, calendar: calendar)?.grade == .y9)
        #expect(ProfileStatement.parse("jag går i sjuan och har prov i engelska", now: now, calendar: calendar)?.subject == "Engelska")
    }

    @Test func notAStatement() {
        #expect(ProfileStatement.parse("vad är fotosyntes", now: now, calendar: calendar) == nil)
        #expect(ProfileStatement.parse("byt till provläge", now: now, calendar: calendar) == nil)
    }

    @Test func onlyWhatWasSaidChanges() {
        var profile = StudyProfile()
        profile.subject = "Kemi"
        profile.explanations = .short
        ProfileStatement(grade: .y8).apply(to: &profile)
        #expect(profile.grade == .y8)
        #expect(profile.subject == "Kemi")
        #expect(profile.explanations == .short)
    }
}

/// D84: the practice exam inside Provläge, on Kevin's `/exam` task format.
@Suite struct ExamSessionTests {
    private func task(_ no: String, _ text: String, E: Double = 1, C: Double = 0, A: Double = 0) -> ExamTask {
        ExamTask(no: no, text: text, points: .init(E: E, C: C, A: A), answer: "", assessment: "")
    }

    private var paper: ExamPaper {
        var paper = ExamPaper()
        paper.merge(tasks: [task("1", "Vad är fotosyntes?"), task("2", "Förklara cellandning.", E: 1, C: 1), task("7a", "Rita en växtcell.")],
                    boundaries: [])
        return paper
    }

    @Test func theExamAndTheInstructionsMergeByTaskNumber() {
        var paper = paper
        var marked = task("2", "Förklara cellandning.", E: 1, C: 1)
        marked.answer = "Socker bryts ned med syre."
        marked.assessment = "+E för socker och syre, +C för energi."
        paper.merge(tasks: [marked], boundaries: [ExamBoundary(grade: "E", total: 3, minCa: nil, minA: nil)])
        #expect(paper.tasks.count == 3)
        #expect(paper.tasks[1].assessment.contains("+C"))
        #expect(paper.boundaries.count == 1)
    }

    @Test func voiceCommands() {
        #expect(ExamSession.command("uppgift 7") == .task("7"))
        #expect(ExamSession.command("uppgift sju a") == .task("7a"))
        #expect(ExamSession.command("ledtråd") == .hint)
        #expect(ExamSession.command("rätta, jag fick 42") == .grade("42"))
        #expect(ExamSession.command("nästa") == .next)
        #expect(ExamSession.command("starta provtid 90 minuter") == .startTimer(minutes: 90))
        #expect(ExamSession.command("hur gick det?") == .howDidItGo)
        #expect(ExamSession.command("avsluta provet") == .end)
        #expect(ExamSession.command("vad är fotosyntes") == nil, "not a command: nothing is answered in the exam")
    }

    @Test func tasksHintsAndResults() {
        var session = ExamSession(paper: paper)
        #expect(session.go(to: "7")?.no == "7a", "uppgift 7 finds 7a")
        #expect(session.next() == nil, "the last task")
        _ = session.go(to: "2")
        #expect(session.nextHintLevel() == 1)
        #expect(session.nextHintLevel() == 2)
        #expect(session.nextHintLevel() == 3)
        #expect(session.nextHintLevel() == 3, "never past Kevin's level 3")
        session.graded(.init(E: 1, C: 0, A: 0))
        #expect(session.resultList.map { $0.no } == ["2"])
        #expect(session.weakTaskTypes().first?.contains("Förklara cellandning") == true, "1 of 2 points")
        #expect(ExamSession.spoken(paper.tasks[1]) == "Uppgift 2, 1 E, 1 C poäng. Förklara cellandning.")
    }

    @Test func timeWarningsComeOnceEach() {
        var session = ExamSession(paper: paper)
        let start = Date(timeIntervalSince1970: 0)
        session.startTimer(minutes: 90, at: start)
        #expect(session.warning(at: start.addingTimeInterval(10 * 60)) == nil)
        #expect(session.warning(at: start.addingTimeInterval(61 * 60)) == "30 minuter kvar.")
        #expect(session.warning(at: start.addingTimeInterval(62 * 60)) == nil)
        #expect(session.warning(at: start.addingTimeInterval(85 * 60)) == "5 minuter kvar.", "10 was missed: the nearest one")
        #expect(session.warning(at: start.addingTimeInterval(86 * 60)) == nil, "never 10 after 5")
        #expect(session.warning(at: start.addingTimeInterval(90 * 60)) == "Tiden är slut.")
        #expect(session.warning(at: start.addingTimeInterval(91 * 60)) == nil)
    }

    @Test func theParseReplyDecodes() throws {
        let json = #"{"tasks":[{"no":"3b","text":"Beräkna","points":{"E":1,"C":1,"A":0},"answer":"600 kr","assessment":"+E"}],"boundaries":[{"grade":"C","total":6,"min_ca":2}]}"#
        let parsed = try JSONDecoder().decode(ExamClient.Parsed.self, from: Data(json.utf8))
        #expect(parsed.tasks.first?.points.total == 2)
        #expect(parsed.boundaries.first?.minCa == 2)
    }
}

/// D84: texts read line by line, the source line never.
@Suite struct ReadAloudTests {
    @Test func linesAreTheRhythm() {
        let units = ReadAloud.units("Helan går,\nsjung hopp faderallan lej.\n\nKälla: runeberg.org")
        #expect(units == ["Helan går,", "sjung hopp faderallan lej.", "Källa: runeberg.org"])
        #expect(ReadAloud.isSourceLine("Källa: runeberg.org"))
        #expect(ReadAloud.isRequest("sjung helan går"))
    }
}

@Suite struct StudyProfileReplyTests {
    @Test func theServersReadingFillsTheProfile() throws {
        let json = #"{"profile":{"grade":"gy2","course":"Kemi 2","subject":"Kemi","exam_date":"2026-11-13","no_exam":false},"terms":["jonbindning","elektronegativitet"]}"#
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let reply = try decoder.decode(StudyProfileReply.self, from: Data(json.utf8))
        var profile = StudyProfile()
        profile.explanations = .short
        reply.apply(to: &profile)
        #expect(profile.grade == .gy2)
        #expect(profile.course == "Kemi 2")
        #expect(profile.terms == ["jonbindning", "elektronegativitet"])
        #expect(profile.examDate != nil)
        #expect(profile.explanations == .short, "nothing else changes")
    }

    @Test func goingToBedIsNoProfile() {
        #expect(!ProfileStatement.isAboutSchool("jag går och lägger mig nu"))
        #expect(ProfileStatement.isAboutSchool("jag går i åk 9"))
        #expect(!ProfileStatement.isAboutSchool("när är provet i biologi"), "a question")
    }
}
