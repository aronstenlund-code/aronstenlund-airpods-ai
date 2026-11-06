import Foundation
import Testing
@testable import Lumen

@MainActor
func makeTestHistory() -> HistoryStore { HistoryStore(directory: temporaryDirectory()) }

@MainActor
func makeTestMemory() -> MemoryStore { MemoryStore(directory: temporaryDirectory()) }

@MainActor
@Suite struct HistoryStoreTests {
    private let t0 = Date(timeIntervalSince1970: 1_762_300_000)

    private func years(_ count: Int, after date: Date) -> Date {
        Calendar(identifier: .gregorian).date(byAdding: .year, value: count, to: date)!
    }

    @Test func recordsReloadsAndDeletes() {
        let directory = temporaryDirectory()
        let store = HistoryStore(directory: directory, now: t0)
        let older = HistoryEntry(createdAt: t0, question: "Fråga?", answer: "Svar.", summary: "Kort.")
        let newer = HistoryEntry(createdAt: t0.addingTimeInterval(60), question: nil, answer: "Svar två.", summary: nil)
        store.record(older, now: t0)
        store.record(newer, now: t0)

        let reloaded = HistoryStore(directory: directory, now: t0)
        #expect(reloaded.entries == [newer, older])
        reloaded.delete(newer)
        #expect(HistoryStore(directory: directory, now: t0).entries == [older])
        reloaded.deleteAll()
        #expect(HistoryStore(directory: directory, now: t0).entries.isEmpty)
    }

    @Test func entriesAreDeletedAfterTwoYears() {
        let directory = temporaryDirectory()
        let store = HistoryStore(directory: directory, now: t0)
        store.record(HistoryEntry(createdAt: t0, question: "Fråga?", answer: "Svar.", summary: nil), now: t0)

        #expect(HistoryStore(directory: directory, now: years(2, after: t0).addingTimeInterval(-60)).entries.count == 1)
        #expect(HistoryStore(directory: directory, now: years(2, after: t0)).entries.isEmpty)
        #expect(HistoryStore(directory: directory, now: t0).entries.isEmpty, "gone from disk, not only hidden")
    }

    @Test func theTitlePrefersTheSummary() {
        #expect(HistoryEntry(question: "Fråga?", answer: "Svar.", summary: "Kort.").title == "Kort.")
        #expect(HistoryEntry(question: "Fråga?", answer: "Svar.", summary: nil).title == "Fråga?")
        #expect(HistoryEntry(question: nil, answer: "Svar.", summary: nil).title == "Svar.")
    }
}

@MainActor
@Suite struct MemoryStoreTests {
    private let t0 = Date(timeIntervalSince1970: 1_762_300_000)

    @Test func addsEditsAndDeletesAcrossReloads() {
        let directory = temporaryDirectory()
        let store = MemoryStore(directory: directory, now: t0)
        let item = store.add("  Jag går tvåan på gymnasiet ", at: t0)
        #expect(item?.text == "Jag går tvåan på gymnasiet")
        #expect(store.add("   ", at: t0) == nil)

        store.update(item!, text: "Jag går trean", at: t0)
        #expect(MemoryStore(directory: directory, now: t0).items.map(\.text) == ["Jag går trean"])

        store.delete(store.items[0])
        #expect(MemoryStore(directory: directory, now: t0).items.isEmpty)
        store.add("Något", at: t0)
        store.deleteAll()
        #expect(MemoryStore(directory: directory, now: t0).items.isEmpty)
    }

    @Test func sayingItAgainRestartsTheTwoYears() {
        let directory = temporaryDirectory()
        let store = MemoryStore(directory: directory, now: t0)
        let calendar = Calendar(identifier: .gregorian)
        let oneYear = calendar.date(byAdding: .year, value: 1, to: t0)!
        let threeYears = calendar.date(byAdding: .year, value: 3, to: t0)!
        store.add("Jag heter Aron", at: t0)
        store.add("jag heter aron.", at: oneYear)

        #expect(store.items.count == 1, "the same fact is confirmed, not duplicated")
        #expect(MemoryStore(directory: directory, now: calendar.date(byAdding: .month, value: 35, to: t0)!).items.count == 1)
        #expect(MemoryStore(directory: directory, now: threeYears).items.isEmpty)
    }

    @Test func sendsAtMostThirtyWithinTheBackendLimit() {
        let store = makeTestMemory()
        for index in 0..<35 {
            store.add("Minne \(index)", at: t0.addingTimeInterval(TimeInterval(index)))
        }
        store.add(String(repeating: "x", count: 500), at: t0.addingTimeInterval(100))

        let sent = store.backendItems(now: t0)
        #expect(sent.count == MemoryStore.maxSent)
        #expect(sent.first?.count == MemoryStore.textLimit, "newest first, clamped")
    }
}

@MainActor
@Suite struct HistoryAndMemoryFlowTests {
    private func makeModel(_ provider: FakeAnswerProvider, history: HistoryStore, memory: MemoryStore,
                           notes: NotesStore? = nil) -> ListeningModel {
        let h = ControllerHarness()
        return ListeningModel(controller: h.controller, consent: FakeConsentStore(granted: true), transcription: makeTestCoordinator(h.controller),
                              activation: makeTestActivation(), answers: makeTestAnswerEngine(provider), speaker: makeTestSpeaker(h.playback),
                              voices: makeTestVoiceCatalog(), notes: notes ?? makeTestNotes(), prep: makeTestPrep(), history: history, memory: memory)
    }

    @Test func ownQuestionsAreSavedWordForWordWithTheSummary() async {
        let provider = FakeAnswerProvider(name: "cloud", events: [.delta("Tio."), .done(AnswerDone(answered: true, summary: "Roten ur hundra."))])
        let history = makeTestHistory()
        let model = makeModel(provider, history: history, memory: makeTestMemory())

        model.submitText("roten ur hundra")

        #expect(await waitUntil { history.entries.count == 1 })
        #expect(history.entries[0].question == "roten ur hundra")
        #expect(history.entries[0].answer == "Tio.")
        #expect(history.entries[0].summary == "Roten ur hundra.")
    }

    @Test func anotherPersonsWordsAreNotSaved() async {
        let provider = FakeAnswerProvider(name: "cloud", events: [.delta("Tio."), .done(AnswerDone(answered: true, summary: "Om kvadratrötter."))])
        let directory = temporaryDirectory()
        let history = HistoryStore(directory: directory)
        let notes = NotesStore(directory: directory)
        let model = makeModel(provider, history: history, memory: makeTestMemory(), notes: notes)
        let secret = "Läraren frågade vad roten ur hundra är"

        model.receiveFinalTranscript(secret, at: Date())
        model.askAboutLast()
        #expect(await waitUntil { history.entries.count == 1 })
        model.saveNote()

        #expect(history.entries[0].question == nil)
        #expect(history.entries[0].answer == "Tio.")
        for file in [HistoryStore.fileName, NotesStore.fileName] {
            let onDisk = (try? String(contentsOf: directory.appending(path: file), encoding: .utf8)) ?? ""
            #expect(onDisk.contains("Tio."), "the file was written")
            #expect(!onDisk.contains(secret), "nothing from the room reaches \(file)")
        }
    }

    @Test func rememberIsStoredAndSentWithTheNextQuestion() async {
        let provider = FakeAnswerProvider(name: "cloud", events: [.delta("Okej."), .done(AnswerDone(answered: true, memoryAdd: "Jag går trean"))])
        let memory = makeTestMemory()
        let model = makeModel(provider, history: makeTestHistory(), memory: memory)

        model.submitText("kom ihåg att jag går trean")
        #expect(await waitUntil { memory.items.count == 1 })
        #expect(provider.requests[0].context.memories.isEmpty)

        model.submitText("vad ska jag läsa")
        #expect(await waitUntil { provider.requests.count == 2 })
        #expect(provider.requests[1].context.memories == ["Jag går trean"])
    }

    @Test func memoriesGoToTheTopLevelOfTheRequest() throws {
        let context = AnswerContext(memories: ["Jag går trean"])
        let body = CloudAnswerProvider.encodeBody(AnswerRequest(fragment: "x", mode: "text", language: "sv", context: context))
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["memories"] as? [String] == ["Jag går trean"])
    }

    @Test func doneCarriesSummaryAndMemory() throws {
        let event = SSEEvent(name: "done", data: "{\"answered\":true,\"summary\":\"Kort.\",\"memory_add\":\"Jag går trean\",\"relation\":\"refines\"}")
        guard case .done(let done) = try AnswerSSEDecoder.decode(event) else {
            Issue.record("expected done")
            return
        }
        #expect(done.summary == "Kort.")
        #expect(done.memoryAdd == "Jag går trean")
    }
}
