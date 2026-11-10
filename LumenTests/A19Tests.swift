import Foundation
import Testing
@testable import Lumen

/// A19: the study plan (K17), the session's summary call and links (K19).
@MainActor
@Suite struct A19Tests {
    private let exam = UUID()

    @Test func historyIsPerExamAndConceptAndCapped() {
        var history = StudyHistory()
        let day = Date(timeIntervalSince1970: 1_762_000_000)
        for i in 0..<40 { history.record("cellandning", ok: i % 2 == 0, exam: exam, at: day.addingTimeInterval(Double(i) * 86_400)) }
        history.record("  ", ok: true, exam: exam, at: day)
        let concepts = history.history(for: exam)
        #expect(concepts.count == 1)
        #expect(concepts["cellandning"]?.count == StudyHistory.perConcept)
        #expect(history.history(for: UUID()).isEmpty)
    }

    @Test func conceptsWithHistoryFirstThenTheExamsTopics() {
        let history = ["mitos": [StudyHistory.Entry(date: "2026-11-09", ok: false)]]
        let concepts = StudyPlanAPI.concepts(history: history, topics: StudyPlanAPI.topics("cellandning, Mitos och klorofyll"))
        #expect(concepts.map(\.concept) == ["mitos", "cellandning", "klorofyll"], "Mitos is already there")
        #expect(concepts.first?.history.count == 1 && concepts.last?.history.isEmpty == true)
    }

    @Test func theTodayLineAndTheRequest() throws {
        let day = StudyPlanAPI.Day(date: "2026-11-10", minutes: 10, concepts: ["cellandning", "klorofyll", "mitos", "osmos"], note: nil)
        #expect(StudyPlanAPI.todayLine(subject: "Biologi", day: day) == "I dag: 10 min Biologi (cellandning, klorofyll, mitos)")
        let body = StudyPlanAPI.Request(today: "2026-11-10", exams: [.init(name: "Biologiprovet", date: "2026-11-13",
                                                                          concepts: [.init(concept: "mitos", history: [.init(date: "2026-11-09", ok: false)])])])
        let json = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(body)) as? [String: Any])
        let first = try #require((json["exams"] as? [[String: Any]])?.first)
        #expect(first["date"] as? String == "2026-11-13")
        #expect(((first["concepts"] as? [[String: Any]])?.first?["history"] as? [[String: Any]])?.first?["ok"] as? Bool == false)
    }

    @Test func theReplyDecodes() throws {
        let json = #"{"today":"2026-11-10","exams":[{"name":"Biologiprovet","date":"2026-11-13","days_left":3,"due":[],"prompt":"I går missade du cellandning. Ska vi ta den nu?","plan":[{"date":"2026-11-10","minutes":10,"concepts":["cellandning"],"note":"Det du missade först."}]}]}"#
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let reply = try decoder.decode(StudyPlanAPI.Reply.self, from: Data(json.utf8))
        #expect(reply.exams.first?.daysLeft == 3)
        #expect(reply.exams.first?.plan.first?.minutes == 10)
        #expect(reply.exams.first?.prompt?.hasPrefix("I går") == true)
    }

    @Test func remindersAreAtFourAndNeverInThePast() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Stockholm"))
        let morning = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 10, hour: 9)))
        let fire = try #require(LumenNotifications.fireDate("2026-11-10", now: morning, calendar: calendar))
        #expect(calendar.component(.hour, from: fire) == 16)
        let evening = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 10, hour: 18)))
        #expect(LumenNotifications.fireDate("2026-11-10", now: evening, calendar: calendar) == nil)
        #expect(LumenNotifications.fireDate("nonsense", now: morning, calendar: calendar) == nil)
    }

    @Test func theSessionEndAndConceptStatsAreSent() throws {
        var context = AnswerContext()
        context.sessionEnd = true
        context.conceptStats = [AnswerContext.ConceptStat(concept: "procent", right: 1, wrong: 2)]
        let data = CloudAnswerProvider.encodeBody(AnswerRequest(fragment: "avsluta", mode: "tutor", language: "sv", context: context))
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["session_end"] as? Bool == true)
        let stats = try #require((json["context"] as? [String: Any])?["concept_stats"] as? [[String: Any]])
        #expect(stats.first?["concept"] as? String == "procent" && stats.first?["wrong"] as? Int == 2)
        let plain = try #require(try JSONSerialization.jsonObject(with: CloudAnswerProvider.encodeBody(
            AnswerRequest(fragment: "x", mode: "tutor", language: "sv"))) as? [String: Any])
        #expect(plain["session_end"] == nil)
    }

    @Test func aLinkComesWithTheAnswer() throws {
        let done = #"{"answered":true,"resource":{"url":"https://urplay.se/program/123-fotosyntes","title":"NO naturligtvis: Fotosyntes","source":"urplay.se","login_likely":false}}"#
        guard case .done(let decoded)? = try AnswerSSEDecoder.decode(SSEEvent(name: "done", data: done)) else {
            Issue.record("not a done event")
            return
        }
        let link = try #require(decoded.resource)
        #expect(link.title == "NO naturligtvis: Fotosyntes" && link.sourceName == "UR Play" && link.loginLikely == false)

        var conversation = Conversation()
        conversation.beginAnswer(question: "har du en film om fotosyntes", source: "cloud")
        conversation.appendAnswerText("Jag skickade en länk.")
        let turn = try #require(conversation.completeAnswer())
        conversation.attach(link, to: turn.id)
        #expect(conversation.answers.last?.link == link)
    }
}
