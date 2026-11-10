import Foundation
import Testing
@testable import Lumen

/// A16: the practice exam by voice. The navigation mirrors Kevin's `practice_test.ts` (K15).
@Suite struct PracticeNavTests {
    private let nos = ["1", "2", "3a", "3b", "4", "5", "6", "7", "8", "9", "10", "11"]

    @Test func navigationLikeKevins() {
        #expect(PracticeNav.decide("nästa", current: 0, nos: nos) == .next(1))
        #expect(PracticeNav.decide("Lumen, nästa fråga tack", current: 4, nos: nos) == .next(5))
        #expect(PracticeNav.decide("förra", current: 4, nos: nos) == .previous(3))
        #expect(PracticeNav.decide("fråga 7", current: 0, nos: nos) == .go(7))
        #expect(PracticeNav.decide("kan vi ta fråga sju", current: 0, nos: nos) == .go(7))
        #expect(PracticeNav.decide("uppgift 3b", current: 0, nos: nos) == .go(3))
        #expect(PracticeNav.decide("fråga tre b", current: 0, nos: nos) == .go(3))
        #expect(PracticeNav.decide("fråga tre", current: 0, nos: nos) == .go(2), "3 is the first of 3a, 3b")
        #expect(PracticeNav.decide("hoppa över den", current: 2, nos: nos) == .skip(3))
        #expect(PracticeNav.decide("kan du upprepa frågan", current: 2, nos: nos) == .repeatQuestion(2))
        #expect(PracticeNav.decide("avsluta provet", current: 2, nos: nos) == .stop)
        #expect(PracticeNav.decide("hur gick det", current: 2, nos: nos) == .results)
        for answer in ["sju", "126 kronor", "det är fyrtio procent", "nästan hälften", "fotosyntesen behöver ljus"] {
            #expect(PracticeNav.decide(answer, current: 0, nos: nos) == .answer, "\(answer)")
        }
        #expect(PracticeNav.decide("nästa", current: 11, nos: nos) == .next(11), "never past the last task")
    }

    @Test func theStartCommand() {
        #expect(PracticeRun.isStartCommand("Kör övningsprovet"))
        #expect(PracticeRun.isStartCommand("Lumen, starta övningsprovet."))
        #expect(!PracticeRun.isStartCommand("vad är ett övningsprov för något"))
    }
}

@Suite struct PracticeRunTests {
    private func task(_ no: String, _ points: Double, topic: String? = nil, spoken: String? = nil) -> ExamTask {
        ExamTask(no: no, text: "Fråga \(no) text", points: .init(E: points, C: 0, A: 0), answer: "", assessment: "",
                 topic: topic, spoken: spoken)
    }

    private var paper: ExamPaper {
        ExamPaper(tasks: [task("1", 1, topic: "procent", spoken: "Fråga ett. Beräkna femton procent. Den ger en poäng."),
                          task("2", 2, topic: "ekvationer"), task("3", 0, topic: "Sarajevo 1914")],
                  boundaries: [], name: "Övningsprov")
    }

    @Test func readsKevinsSpokenFormAndShowsProgress() throws {
        let run = try #require(PracticeRun(paper: paper))
        #expect(run.spokenQuestion == "Fråga ett. Beräkna femton procent. Den ger en poäng.")
        #expect(run.progress == "Fråga 1 av 3")
        #expect(PracticeRun(paper: ExamPaper()) == nil, "no questions, no run")
    }

    @Test func gradesMovesOnAndSums() throws {
        var run = try #require(PracticeRun(paper: paper))
        run.graded(points: 1, max: 1)
        #expect(run.nextOpenIndex == 1)
        run.move(to: 1)
        run.graded(points: 1, max: 2) // partly
        run.move(to: 2)
        run.graded(points: 0, max: 1) // a question without points is right or wrong
        #expect(run.nextOpenIndex == nil)
        let summary = run.summary
        #expect(summary.right == 1 && summary.partly == 1 && summary.wrong == 1 && summary.answered == 3)
        #expect(summary.practise == ["ekvationer", "Sarajevo 1914"])
        #expect(run.spokenSummary == "Du hade 1 rätt av 3. 1 delvis rätt och 1 fel. Öva på ekvationer och Sarajevo 1914.")
        #expect(run.conceptResults.map(\.concept) == ["procent", "ekvationer", "Sarajevo 1914"])
    }

    @Test func skippedQuestionsComeBackLast() throws {
        var run = try #require(PracticeRun(paper: paper))
        run.skip()
        run.move(to: 1)
        run.graded(points: 2, max: 2)
        #expect(run.nextOpenIndex == 2)
        #expect(run.summary.skipped == 1)
        #expect(run.summary.practise == ["procent"])
    }

    @Test func conceptStatsKeepTheBackendsLimits() {
        var stats = ConceptStats()
        let start = Date(timeIntervalSince1970: 1_000)
        for i in 0..<70 { stats.record("begrepp \(i)", right: i % 2 == 0, at: start.addingTimeInterval(Double(i))) }
        stats.record("begrepp 69", right: false, at: start.addingTimeInterval(100))
        let items = stats.backendItems
        #expect(items.count == ConceptStats.limit)
        #expect(items.first == AnswerContext.ConceptStat(concept: "begrepp 69", right: 0, wrong: 2), "the most recent first")
    }

    @Test func oldStoredTasksStillDecode() throws {
        let json = #"{"tasks":[{"no":"1","text":"t","points":{"E":1,"C":0,"A":0},"answer":"","assessment":""}],"boundaries":[],"name":""}"#
        let paper = try JSONDecoder().decode(ExamPaper.self, from: Data(json.utf8))
        #expect(paper.tasks.first?.topic == nil)
        let k15 = #"{"no":"2","text":"t","points":{"E":1,"C":0,"A":0},"answer":"x","assessment":"","topic":"procent","spoken":"Fråga två.","answer_source":"eget svar"}"#
        let task = try JSONDecoder().decode(ExamTask.self, from: Data(k15.utf8))
        #expect(task.isOwnAnswer && task.topic == "procent" && task.spoken == "Fråga två.")
    }
}
