import Foundation
import Testing
@testable import Lumen

/// A165 (D263, Aron 2026-11-26): "Spela in själv – helt gratis", the views' side. The user's own decks are shown
/// and edited through `OwnDecking` (the core is A164); a sheet points there when the server says no for credits
/// (402) or because its model is down (`provider_*`), once per occasion.
/// Pretend decks, a pretend server: nothing is recorded, played or sent, 0 ElevenLabs characters (D180).
@MainActor
@Suite struct A165OwnDeckTests {
    static let down = #"{"error":{"code":"provider_quota","message":"LLM credits exhausted","fallback":true}}"#
    static let short = #"{"error":{"code":"quota_exceeded","message":"Det räcker till 5 frågor."},"remaining":3000,"fits":5,"per_question":492}"#

    /// The server's answer to a new quiz: a no (the body and its status), or a quiz.
    @MainActor final class Maker: DrillMaking {
        var no: (status: Int, body: String)?
        let mock = MockDrillMaker()

        private func refuse() throws(DrillMakingError) {
            if let no { throw DrillClient.refusal(status: no.status, data: Data(no.body.utf8)) }
        }
        func make(_ material: DrillMaterial, subject: String?, grade: String?, correction: String?,
                  questions: Int, longWords: Int) async throws(DrillMakingError) -> DrillDraft {
            try refuse()
            return try await mock.make(material, subject: subject, grade: grade, correction: correction, questions: questions, longWords: longWords)
        }
        func answers(for items: [DrillItem], summary: DrillSummary, notes: String, longWords: Int) async throws(DrillMakingError) -> [DrillItem] {
            try await mock.answers(for: items, summary: summary, notes: notes, longWords: longWords)
        }
        func answer(_ question: String, summary: DrillSummary, notes: String, longWords: Int) async throws(DrillMakingError) -> DrillItem {
            try await mock.answer(question, summary: summary, notes: notes, longWords: longWords)
        }
        func documentText(docx: Data) async throws(DrillMakingError) -> String { try await mock.documentText(docx: docx) }
        func readText(_ material: DrillMaterial, subject: String?, grade: String?, title: String?) async throws(DrillMakingError) -> DrillTextDraft {
            try refuse()
            return try await mock.readText(material, subject: subject, grade: grade, title: title)
        }
        func fetchPage(_ address: String) async throws(DrillMakingError) -> FetchedPage { try await mock.fetchPage(address) }
    }

    private func model(_ name: String, maker: Maker, cloud given: A107StartAudioTests.DeferredCloud? = nil) throws
        -> (RepetitionModel, DrillStore, CloudDrillAudio) {
        let cloud = given ?? A107StartAudioTests.DeferredCloud()
        let folder = try A79A81RepetitionTests.folder(name)
        let store = DrillStore(url: folder.appendingPathComponent("drills.json"))
        let audio = CloudDrillAudio(cloud: cloud, store: store, folder: folder, pollInterval: .milliseconds(1), maxPolls: 20)
        let defaults = try #require(UserDefaults(suiteName: "\(name)-\(UUID())"))
        let session = RepetitionSession(inputs: [], makeSource: { A78RepetitionTests.MockSource() }, makeTimer: { A78RepetitionTests.MockTimer() },
                                        defaults: defaults, activatesAudioSession: false)
        let model = RepetitionModel(store: store, session: session, maker: maker, audio: audio,
                                    sharing: DrillShareClient(cloud: cloud), remote: RemoteCommandHub(), cloud: cloud, defaults: defaults)
        return (model, store, audio)
    }

    private func tryToMake(_ model: RepetitionModel) async {
        _ = try? await model.make(DrillMaterial(text: "Fotosyntes."), settings: model.newDrillSettings)
    }

    // MARK: The sheet: once per occasion

    @Test func theSheetComesOncePerOccasion() {
        let offer = OwnDeckOffer()
        #expect(offer.showing == nil && !offer.opensDecks)
        offer.serverRefused(.credits)
        #expect(offer.showing == .credits)
        // Closed with a tap. The same no again (the user tries once more) does not bring it back.
        offer.close()
        offer.serverRefused(.credits)
        #expect(offer.showing == nil)
        // Another reason is another occasion.
        offer.serverRefused(.modelDown)
        #expect(offer.showing == .modelDown)
        offer.close()
        // The server said yes in between (a top-up, a new month): the next no is a new occasion.
        offer.serverAnswered(.credits)
        offer.serverRefused(.credits)
        #expect(offer.showing == .credits)
        // The button: the sheet goes away and Start is told to open "Spela in själv".
        offer.open()
        #expect(offer.showing == nil && offer.opensDecks)
    }

    @Test func aSecondNoWhileTheSheetIsUpDoesNotReplaceIt() {
        let offer = OwnDeckOffer()
        offer.serverRefused(.modelDown)
        offer.serverRefused(.credits)
        #expect(offer.showing == .modelDown)
        // The credits' no was not said, so it can still be: it comes at the next one.
        offer.close()
        offer.serverRefused(.credits)
        #expect(offer.showing == .credits)
    }

    @Test func theModelBeingDownBringsTheSheetOnlyWithTheFeatureInTheApp() async throws {
        let maker = Maker()
        maker.no = (503, Self.down)
        let (model, _, _) = try model("a165-down", maker: maker)
        // Without "Spela in själv" in the app (the core is not there yet) nothing points to it.
        await tryToMake(model)
        #expect(model.modelIsDown() && model.ownOffer.showing == nil)
        // With it: the server's no brings the sheet, once.
        model.ownDecks = PretendOwnDecks()
        await tryToMake(model)
        #expect(model.ownOffer.showing == .modelDown)
        model.ownOffer.close()
        await tryToMake(model)
        #expect(model.ownOffer.showing == nil, "the same occasion: not again")
        // The model answers, and later it is down again: a new occasion.
        maker.no = nil
        await tryToMake(model)
        #expect(!model.modelIsDown() && model.ownOffer.showing == nil)
        maker.no = (503, Self.down)
        await tryToMake(model)
        #expect(model.ownOffer.showing == .modelDown)
    }

    @Test func aTextToReadAloudThatTheModelCannotCleanBringsTheSheetToo() async throws {
        let maker = Maker()
        maker.no = (503, Self.down)
        let (model, _, _) = try model("a165-read", maker: maker)
        model.ownDecks = PretendOwnDecks()
        _ = try? await model.readText(DrillMaterial(text: "Fotosyntes."))
        #expect(model.ownOffer.showing == .modelDown)
    }

    @Test func theServersNoForCreditsToANewQuizBringsTheSheet() async throws {
        let maker = Maker()
        maker.no = (402, Self.short)
        let (model, _, _) = try model("a165-credits", maker: maker)
        model.ownDecks = PretendOwnDecks()
        await tryToMake(model)
        #expect(model.ownOffer.showing == .credits)
        #expect(OwnDeckText.offerTitle(.credits) == "Slut på krediter?")
        #expect(OwnDeckText.offerLine == "Spela in dina egna frågor och svar – helt gratis.")
        // Another refusal of the server's (a limit in its own words) is not about credits: no sheet.
        model.ownOffer.close()
        model.ownOffer.serverAnswered(.credits)
        maker.no = (429, #"{"error":{"code":"rate_limited","message":"Vänta."}}"#)
        await tryToMake(model)
        #expect(model.ownOffer.showing == nil)
    }

    @Test func aStartTheCreditsDoNotCoverBringsTheSheetAndAStartThatWorksEndsTheOccasion() async throws {
        let cloud = A107StartAudioTests.DeferredCloud()
        let (model, store, audio) = try model("a165-start", maker: Maker(), cloud: cloud)
        model.ownDecks = PretendOwnDecks()
        var drill = A79A81RepetitionTests.bio(2)
        drill.needsUpload = true
        store.save(drill)
        await audio.prepare(drill)
        let saved = try #require(store.drill(drill.id))
        cloud.quotaLeft = false
        #expect(await model.startAudio(saved) == false)
        #expect(model.quotaExceeded(saved) && model.ownOffer.showing == .credits)
        model.ownOffer.close()
        #expect(await model.startAudio(saved) == false)
        #expect(model.ownOffer.showing == nil, "the same occasion: not again")
        // A top-up: the start works. The next time the credits run out the sheet may come again.
        cloud.quotaLeft = true
        #expect(await model.startAudio(saved))
        model.serverRefused(.credits)
        #expect(model.ownOffer.showing == .credits)
    }

    // MARK: The decks, as the views use them

    @Test func aDeckIsMadeFilledAndCountedAndWhatIsDeletedTakesItsRecordingsAlong() async {
        let decks = PretendOwnDecks()
        let deck = decks.addDeck(title: "Biologi kapitel 3")
        #expect(decks.decks.map(\.title) == ["Biologi kapitel 3"])
        #expect(OwnDeckText.facts(cards: 0, recorded: decks.recorded(in: deck)) == "Inga frågor än")

        let first = OwnCard(question: "Vad gör mitokondrien?", answer: "Den omvandlar näring till energi.")
        let second = OwnCard(question: "Vad är fotosyntes?", answer: "")
        decks.save(first, in: deck.id)
        decks.save(second, in: deck.id)
        var now = decks.deck(deck.id) ?? deck
        #expect(now.cards.map(\.id) == [first.id, second.id])
        // Two questions and one written answer: three things to read in.
        #expect(decks.recorded(in: now).done == 0 && decks.recorded(in: now).of == 3)
        #expect(OwnDeckText.facts(cards: 2, recorded: decks.recorded(in: now)) == "2 frågor")

        // The question is read in: record, stop.
        let take = OwnTake(deck: deck.id, card: first.id, side: .question)
        await decks.record(take)
        #expect(decks.recording == take)
        decks.elapsed = 3
        decks.stopRecording()
        #expect(decks.recording == nil && decks.seconds(of: take) == 3)
        #expect(OwnDeckText.facts(cards: 2, recorded: decks.recorded(in: now)) == "2 frågor · 1 av 3 inspelade")

        // The text is changed: the same card, its recording kept.
        var changed = first
        changed.question = "Vad gör mitokondrierna?"
        decks.save(changed, in: deck.id)
        now = decks.deck(deck.id) ?? deck
        #expect(now.cards.count == 2 && now.cards.first?.question == "Vad gör mitokondrierna?")
        #expect(decks.seconds(of: take) == 3)

        // The card is deleted: its recording goes with it.
        decks.deleteCard(first.id, in: deck.id)
        #expect(decks.deck(deck.id)?.cards.map(\.id) == [second.id] && decks.seconds(of: take) == nil)

        // A new card that was read in but never added leaves nothing behind.
        let never = OwnTake(deck: deck.id, card: UUID(), side: .answer)
        await decks.record(never)
        decks.stopRecording()
        #expect(decks.seconds(of: never) != nil)
        decks.deleteCard(never.card, in: deck.id)
        #expect(decks.seconds(of: never) == nil)

        await decks.practise(deck.id)
        #expect(decks.practised == [deck.id])
        decks.deleteDeck(deck.id)
        #expect(decks.decks.isEmpty)
    }

    @Test func aSpokenAnswerWithoutTextCountsAsRecorded() {
        let card = OwnCard(question: "Vad är fotosyntes?", answer: "")
        let deck = OwnDeck(title: "Bio", cards: [card])
        let decks = PretendOwnDecks(decks: [deck])
        decks.takes[OwnTake(deck: deck.id, card: card.id, side: .question)] = 2
        #expect(decks.recorded(in: deck).done == 1 && decks.recorded(in: deck).of == 1)
        decks.takes[OwnTake(deck: deck.id, card: card.id, side: .answer)] = 4
        #expect(decks.recorded(in: deck).done == 2 && decks.recorded(in: deck).of == 2)
        #expect(OwnDeckText.facts(cards: 1, recorded: decks.recorded(in: deck)) == "1 fråga · allt inspelat")
    }

    @Test func aCardNeedsAQuestionAndIsSavedWithoutBlanksAround() {
        var draft = OwnCardDraft(editing: nil)
        #expect(draft.isNew && !draft.canSave)
        draft.card.question = "   "
        #expect(!draft.canSave)
        draft.card.question = "  Vad är fotosyntes?\n"
        draft.card.answer = " Växter gör socker av ljus. "
        #expect(draft.canSave)
        #expect(draft.cleaned.question == "Vad är fotosyntes?" && draft.cleaned.answer == "Växter gör socker av ljus.")
        #expect(draft.cleaned.id == draft.card.id)
        let existing = OwnCardDraft(editing: draft.cleaned)
        #expect(!existing.isNew && existing.canSave && existing.card == draft.cleaned)
    }

    // MARK: The words

    @Test func theWordsSayWhatIsRecorded() {
        #expect(OwnDeckText.cardLine(question: true, answer: true, hasAnswer: true) == "Inspelad")
        #expect(OwnDeckText.cardLine(question: true, answer: false, hasAnswer: false) == "Inspelad")
        #expect(OwnDeckText.cardLine(question: true, answer: false, hasAnswer: true) == "Frågan inspelad")
        #expect(OwnDeckText.cardLine(question: false, answer: true, hasAnswer: true) == "Svaret inspelat")
        #expect(OwnDeckText.cardLine(question: false, answer: false, hasAnswer: true) == "Inte inspelad än")
        #expect(OwnDeckText.clock(0) == "0:00" && OwnDeckText.clock(4.4) == "0:04" && OwnDeckText.clock(75) == "1:15")
        #expect(OwnDeckText.recording(4) == "Spelar in · 0:04" && OwnDeckText.listen(6) == "Spela upp · 0:06")
        #expect(OwnDeckText.record(.question) == "Spela in frågan" && OwnDeckText.record(.answer) == "Spela in svaret")
        #expect(OwnDeckText.entry == "Spela in själv – helt gratis" && OwnDeckText.free == "Helt gratis")
        #expect(OwnDeckText.offerTitle(.modelDown) == "EarMind kan inte svara just nu")
    }

    @Test func theWordsAreInBothLanguages() {
        func text(_ key: String, _ language: AppLanguage) -> String {
            language.bundle.localizedString(forKey: key, value: "(missing)", table: nil)
        }
        #expect(text("Spela in själv – helt gratis", .en) == "Record it yourself – completely free")
        #expect(text("Spela in själv", .en) == "Record it yourself")
        #expect(text("Helt gratis", .en) == "Completely free")
        #expect(text("Slut på krediter?", .en) == "Out of credits?")
        #expect(text("Spela in dina egna frågor och svar – helt gratis.", .en) == "Record your own questions and answers – completely free.")
        #expect(text("Spela in själv – helt gratis", .sv) == "Spela in själv – helt gratis")
        #expect(text("Slut på krediter?", .sv) == "Slut på krediter?")
        for key in ["Ny samling", "Ny fråga", "Öva", "Lägg till en fråga först.", "Spela in frågan", "Spela in svaret", "Spela in igen",
                    "Inte inspelad än", "Inspelad", "Helt gratis. Ljudet stannar på telefonen.", "EarMind kan inte svara just nu"] {
            #expect(text(key, .en) != "(missing)" && text(key, .en) != key, "\(key)")
        }
    }
}
