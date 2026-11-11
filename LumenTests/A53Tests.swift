import Foundation
import Testing
@testable import Lumen

/// A53 (D126, K37): "Mina svar". The answers stay on the phone with versions, go to `/answer` as `saved_answers` in
/// Provläge only when "Säg mina svar" is on, and `done.saved_answer` marks the turn ("Ditt svar").
@MainActor
@Suite struct A53Tests {
    private static func store() -> (MyAnswerStore, UserDefaults) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("a53-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let defaults = UserDefaults(suiteName: "a53-\(UUID().uuidString)")!
        return (MyAnswerStore(directory: directory, defaults: defaults), defaults)
    }

    @Test func everySaveIsAVersionAndAnUnchangedTextIsNot() throws {
        let (store, _) = Self.store()
        let exam = UUID()
        let first = try #require(store.save(examID: exam, question: "Vad är fotosyntes?", answer: "Växter gör socker av ljus.", author: .lumen))
        #expect(first.versions.count == 1)
        let same = store.save(id: first.id, examID: exam, question: "Vad är fotosyntes?", answer: "Växter gör socker av ljus.", author: .mine)
        #expect(same?.versions.count == 1, "the same text is not a new version")
        let edited = try #require(store.save(id: first.id, examID: exam, question: "Vad är fotosyntes?",
                                             answer: "Växter gör glukos av koldioxid, vatten och ljus.", author: .mine))
        #expect(edited.versions.count == 2)
        #expect(edited.versions.last?.author == .mine)
        #expect(store.answers.count == 1)
    }

    @Test func restoringMakesANewVersionAndLosesNothing() throws {
        let (store, _) = Self.store()
        let item = try #require(store.save(examID: nil, question: "Q", answer: "Gammalt svar", author: .lumen))
        let oldVersion = try #require(item.versions.first)
        _ = store.save(id: item.id, examID: nil, question: "Q", answer: "Nytt svar", author: .mine)
        let restored = try #require(store.restore(oldVersion.id, of: item.id))
        #expect(restored.answer == "Gammalt svar")
        #expect(restored.versions.count == 3)
    }

    @Test func atMostTenVersions() throws {
        let (store, _) = Self.store()
        let item = try #require(store.save(examID: nil, question: "Q", answer: "0", author: .mine))
        for n in 1...14 { _ = store.save(id: item.id, examID: nil, question: "Q", answer: "\(n)", author: .mine) }
        let last = try #require(store.answer(item.id))
        #expect(last.versions.count == MyAnswerStore.versionLimit)
        #expect(last.answer == "14" && last.versions.last?.answer == "14")
    }

    @Test func emptyTextIsNotSaved() {
        let (store, _) = Self.store()
        #expect(store.save(examID: nil, question: "  ", answer: "svar", author: .mine) == nil)
        #expect(store.save(examID: nil, question: "fråga", answer: "\n", author: .mine) == nil)
        #expect(store.answers.isEmpty)
    }

    @Test func thePayloadIsTheExamsAnswersAndNothingWhenOff() throws {
        let (store, defaults) = Self.store()
        let biology = UUID(), history = UUID()
        _ = store.save(examID: biology, question: "Vad är en cell?", answer: "Livets minsta byggsten.", author: .mine)
        _ = store.save(examID: history, question: "När började första världskriget?", answer: "1914.", author: .mine)
        _ = store.save(examID: nil, question: "Vad heter jag?", answer: "Aron.", author: .mine)
        let sent = store.payload(for: biology)
        #expect(sent.count == 2, "the exam's own and the ones for every exam")
        #expect(!sent.contains { $0.q.contains("världskriget") })
        #expect(sent.allSatisfy { UUID(uuidString: $0.id) != nil })
        store.isEnabled = false
        #expect(store.payload(for: biology).isEmpty, "Säg mina svar off: Lumen answers itself")
        #expect(defaults.bool(forKey: MyAnswerStore.enabledKey) == false)
        #expect(store.answers.count == 3, "nothing is deleted")
    }

    @Test func savedAnswersSurviveClampedAndGoInTheBody() throws {
        var context = AnswerContext()
        context.savedAnswers = [SavedAnswerPayload(id: "A", q: String(repeating: "q", count: 400), a: "Svaret.")]
        let clamped = context.clamped
        #expect(clamped.savedAnswers.count == 1, "A48's lesson: a new field must be in `clamped`")
        #expect(clamped.savedAnswers.first?.q.count == SavedAnswerPayload.questionLimit)
        let data = CloudAnswerProvider.encodeBody(AnswerRequest(fragment: "vad är fotosyntes", mode: "tutor", language: "sv", context: clamped))
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let saved = try #require(json["saved_answers"] as? [[String: Any]])
        #expect(saved.first?["id"] as? String == "A" && saved.first?["a"] as? String == "Svaret.")
        let plain = try #require(try JSONSerialization.jsonObject(with: CloudAnswerProvider.encodeBody(
            AnswerRequest(fragment: "x", mode: "auto", language: "sv"))) as? [String: Any])
        #expect(plain["saved_answers"] == nil)
    }

    @Test func doneSaysWhichSavedAnswerWasSaid() throws {
        let done = #"{"answered":true,"saved_answer":{"id":"5D8E","text":"Växter gör socker av ljus.","via":"code"}}"#
        guard case .done(let decoded)? = try AnswerSSEDecoder.decode(SSEEvent(name: "done", data: done)) else {
            Issue.record("not a done event")
            return
        }
        let hit = try #require(decoded.savedAnswer)
        #expect(hit.id == "5D8E" && hit.via == "code")
    }

    @Test func theTurnIsMarkedAsTheStudentsOwn() {
        var conversation = Conversation()
        conversation.beginAnswer(question: "Vad är fotosyntes?", source: "cloud")
        conversation.appendAnswerText("Växter gör socker av ljus.")
        let turn = conversation.completeAnswer(latencyMs: nil)
        #expect(turn != nil)
        if let turn { conversation.markSaved("5D8E", text: "Växter gör socker av ljus (1 g).", on: turn.id) }
        #expect(conversation.answers.last?.savedAnswerID == "5D8E")
        #expect(conversation.answers.last?.answer == "Växter gör socker av ljus (1 g).", "the exact text, not the spoken form")
    }

    @Test func theSpellingLineShowsTheFixedWords() {
        #expect(MyAnswerText.changedWords(from: "Ett kraftvrek gör el", to: "Ett kraftverk gör el") == ["kraftverk"])
        #expect(MyAnswerText.changedWords(from: "samma text", to: "samma text").isEmpty)
    }

    @Test func theClockAndTheExcerpt() {
        #expect(MyAnswerText.clock(134.9) == "02:14")
        #expect(MyAnswerText.clock(600) == "10:00")
        let long = String(repeating: "ord ", count: 100)
        let excerpt = MyAnswerText.excerpt(long, limit: 40)
        #expect(excerpt.hasSuffix(" …") && excerpt.count <= 42)
        #expect(MyAnswerText.excerpt("kort") == "kort")
    }

    @Test func theSuggestionKnowsTheExam() {
        let body = MyAnswersClient.suggestBody(question: "Vad är fotosyntes?",
                                               context: .init(subject: "Biologi", grade: "9", exam: "Biologiprovet", goals: nil, terms: ["klorofyll"]))
        #expect(body["action"]?.string == "suggest")
        #expect(body["subject"]?.string == "Biologi" && body["exam"]?.string == "Biologiprovet")
        #expect(body["goals"] == nil)
        if case .array(let terms)? = body["terms"] { #expect(terms.count == 1) } else { Issue.record("no terms") }
    }
}
