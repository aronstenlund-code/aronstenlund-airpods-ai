import Foundation
import Testing
@testable import Lumen

/// Historik (Deangelo 2026-11-27 01:52): easy to find an answer again – search, the newest first, days as headings –
/// and one tap plays it again in the AirPods. Works without a network and without credits: the history is on the
/// phone, and the phone's own voice reads when the chosen voice cannot. 0 ElevenLabs (fake voices).
@MainActor
@Suite struct HistoryReplayTests {
    private let premiumVoice = VoiceChoice(kind: .elevenLabs, voiceID: "v1", name: "Astrid")

    private func model(premium: FakeTTSProvider?, apple: FakeTTSProvider) -> (ListeningModel, ControllerHarness) {
        let h = ControllerHarness()
        let model = ListeningModel(controller: h.controller, consent: FakeConsentStore(granted: true),
                                   transcription: makeTestCoordinator(h.controller), activation: makeTestActivation(),
                                   answers: makeTestAnswerEngine(FakeAnswerProvider()),
                                   speaker: makeTestSpeaker(h.playback, apple: apple, premium: premium),
                                   voices: makeTestVoiceCatalog(), notes: makeTestNotes(), prep: makeTestPrep(),
                                   history: makeTestHistory())
        return (model, h)
    }

    private let photosynthesis = HistoryEntry(question: nil, answer: "Fotosyntesen är när växter gör socker av ljus.", summary: nil)

    // MARK: One tap plays it again

    @Test func oneTapReadsTheAnswerAgain() async {
        let apple = FakeTTSProvider(name: "apple")
        let (model, _) = model(premium: nil, apple: apple)
        model.readAgain(photosynthesis)
        #expect(model.readingAgain == photosynthesis.id)
        #expect(await waitUntil { apple.calls.map(\.text) == [self.photosynthesis.answer] })
        #expect(apple.calls.first?.language == .swedish)
        #expect(await waitUntil { model.readingAgain == nil }, "the row's button goes back to ▶ when it is read")
    }

    @Test func itIsReadWithTheChosenVoice() async {
        let apple = FakeTTSProvider(name: "apple")
        let premium = FakeTTSProvider(name: "elevenlabs")
        let (model, _) = model(premium: premium, apple: apple)
        model.speaker.settings.voice = premiumVoice
        model.readAgain(photosynthesis)
        #expect(await waitUntil { premium.calls.count == 1 })
        #expect(premium.calls.first?.voice == premiumVoice)
        #expect(apple.calls.isEmpty)
    }

    @Test func withoutANetworkThePhoneReadsIt() async {
        let apple = FakeTTSProvider(name: "apple")
        let premium = FakeTTSProvider(name: "elevenlabs")
        premium.error = .network(.offline)
        let (model, _) = model(premium: premium, apple: apple)
        model.speaker.settings.voice = premiumVoice
        model.readAgain(photosynthesis)
        #expect(await waitUntil { apple.calls.map(\.text) == [self.photosynthesis.answer] })
    }

    @Test func withoutCreditsThePhoneReadsIt() async {
        let apple = FakeTTSProvider(name: "apple")
        let premium = FakeTTSProvider(name: "elevenlabs")
        premium.error = .network(.backend(status: 402, failure: AnswerFailure(code: "quota_exceeded", message: nil, fallback: nil)))
        let (model, _) = model(premium: premium, apple: apple)
        model.speaker.settings.voice = premiumVoice
        model.readAgain(photosynthesis)
        #expect(await waitUntil { apple.calls.map(\.text) == [self.photosynthesis.answer] })
    }

    @Test func itIsReadAlsoWhenSpokenAnswersAreOff() async {
        // Tyst läge (answers only on the screen) is about answers; this is the user's own tap.
        let apple = FakeTTSProvider(name: "apple")
        let (model, _) = model(premium: nil, apple: apple)
        model.speaker.settings.speakAnswers = false
        model.readAgain(photosynthesis)
        #expect(await waitUntil { apple.calls.count == 1 })
    }

    @Test func anotherRowOrStopEndsTheOneBeingRead() async {
        let apple = FakeTTSProvider(name: "apple")
        apple.delay = .seconds(2)
        let (model, _) = model(premium: nil, apple: apple)
        let pi = HistoryEntry(question: "Vad är pi?", answer: "Ungefär 3,14.", summary: nil)
        model.readAgain(photosynthesis)
        #expect(await waitUntil { apple.calls.count == 1 })
        model.readAgain(pi)
        #expect(model.readingAgain == pi.id)
        #expect(await waitUntil { apple.calls.map(\.text).last == "Ungefär 3,14." })
        model.stopReadingAgain()
        #expect(model.readingAgain == nil)
        #expect(!model.speaker.isSpeaking)
    }

    @Test func anEnglishAnswerIsReadInEnglish() async {
        let apple = FakeTTSProvider(name: "apple")
        let (model, _) = model(premium: nil, apple: apple)
        model.readAgain(HistoryEntry(question: nil, answer: "Photosynthesis is how plants make sugar from light and water.", summary: nil))
        #expect(await waitUntil { apple.calls.count == 1 })
        #expect(apple.calls.first?.language == .english)
    }

    // MARK: The newest first, under its day

    @Test func theNewestIsFirstUnderTodayAndYesterday() throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 27, hour: 14)))
        let today = HistoryEntry(createdAt: now.addingTimeInterval(-600), question: nil, answer: "a", summary: nil)
        let earlierToday = HistoryEntry(createdAt: now.addingTimeInterval(-7_200), question: nil, answer: "b", summary: nil)
        let yesterday = HistoryEntry(createdAt: now.addingTimeInterval(-86_400), question: nil, answer: "c", summary: nil)
        let lastWeek = HistoryEntry(createdAt: now.addingTimeInterval(-6 * 86_400), question: nil, answer: "d", summary: nil)
        let days = HistoryEntry.days([earlierToday, lastWeek, today, yesterday], now: now, calendar: calendar)
        #expect(days.map(\.entries.count) == [2, 1, 1])
        #expect(days[0].title == "I dag" && days[1].title == "I går")
        #expect(days[0].entries.map(\.answer) == ["a", "b"], "the newest first within the day")
        #expect(days[2].entries.first?.answer == "d")
    }

    @Test func theHistoryIsThereWithoutANetworkAfterARestart() throws {
        // On the phone only: a store opened again (the app restarted, flight mode) has the same rows, newest first.
        let folder = temporaryDirectory()
        let store = HistoryStore(directory: folder)
        store.record(HistoryEntry(createdAt: Date().addingTimeInterval(-120), question: nil, answer: "äldre", summary: nil))
        store.record(HistoryEntry(createdAt: Date().addingTimeInterval(-60), question: nil, answer: "nyare", summary: nil))
        let again = HistoryStore(directory: folder)
        #expect(again.entries.map(\.answer) == ["nyare", "äldre"])
        #expect(HistoryEntry.matching(again.entries, "nyare").count == 1)
    }
}
