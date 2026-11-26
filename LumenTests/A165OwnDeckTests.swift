import Foundation
import Testing
@testable import Lumen

/// A165 (D263, Aron 2026-11-26): "Spela in själv – helt gratis", the views' side (the core is A164): a sheet points
/// there when the server says no for credits (402) or because its model is down (`provider_*`), once per occasion;
/// the screen of a deck opens at once and what was never filled in is tidied away; the words are Kelly's (Ke89).
/// A pretend server and texts only: nothing is recorded, played or sent, 0 ElevenLabs characters (D180).
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
        model.ownDecks = OwnDeckModel()
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
        model.ownDecks = OwnDeckModel()
        _ = try? await model.readText(DrillMaterial(text: "Fotosyntes."))
        #expect(model.ownOffer.showing == .modelDown)
    }

    @Test func theServersNoForCreditsToANewQuizBringsTheSheet() async throws {
        let maker = Maker()
        maker.no = (402, Self.short)
        let (model, _, _) = try model("a165-credits", maker: maker)
        model.ownDecks = OwnDeckModel()
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
        model.ownDecks = OwnDeckModel()
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

    // MARK: The deck's screen opens at once, and what was never filled in is tidied away (Ke89 §2)

    @Test func aNewDeckIsReadyToWriteInAndGoesAwayWhenNothingWasWritten() {
        let decks = OwnDeckModel()
        let deck = OwnDeckTidy.newDeck(in: decks)
        #expect(decks.decks.count == 1 && deck.cards.count == 1, "a first card to write in")
        #expect(OwnDeckText.isDefaultTitle(deck.title) && OwnDeckTidy.shownName(deck.title) == "", "the name field is empty: the placeholder shows")
        #expect(!decks.canStart(deck))
        // Klar without having written anything: nothing is left behind.
        #expect(OwnDeckTidy.afterEditing(deck.id, in: decks) == false)
        #expect(decks.decks.isEmpty)
    }

    @Test func aDeckThatWasWrittenInIsKeptWithoutItsBlankCards() throws {
        let decks = OwnDeckModel()
        let deck = OwnDeckTidy.newDeck(in: decks)
        let first = try #require(deck.cards.first)
        decks.setText("Vad gör mitokondrien?", for: .question, card: first.id, in: deck.id)
        decks.setText("Den omvandlar näring till energi.", for: .answer, card: first.id, in: deck.id)
        decks.addCard(to: deck.id) // Lägg till fråga, and then nothing written in it
        #expect(decks.deck(deck.id)?.cards.count == 2)
        #expect(OwnDeckTidy.afterEditing(deck.id, in: decks))
        let kept = try #require(decks.deck(deck.id))
        #expect(kept.cards.map(\.question) == ["Vad gör mitokondrien?"])
        #expect(decks.canStart(kept), "a question and its answer: it can be practised (the phone's voice reads what is not read in)")
        // Never named: it keeps the name a deck is born with, and its line on Start says what it is.
        #expect(kept.title == "Mina frågor" && OwnDeckText.deckLine(cards: kept.cards.count) == "Egen inspelning · 1 fråga")
    }

    @Test func aNamedDeckIsKeptEvenWithoutCardsAndTheNameIsCutAtTheLimit() throws {
        let decks = OwnDeckModel()
        let deck = OwnDeckTidy.newDeck(in: decks)
        decks.rename(deck.id, to: OwnDeckTidy.title(forName: "  Glosor vecka 12 "))
        #expect(decks.deck(deck.id)?.title == "Glosor vecka 12")
        #expect(OwnDeckTidy.afterEditing(deck.id, in: decks))
        #expect(decks.deck(deck.id)?.cards.isEmpty == true, "the blank first card is gone, the named deck stays")
        #expect(OwnDeckTidy.shownName("Glosor vecka 12") == "Glosor vecka 12")
        // The field emptied again: the deck is not left without a name.
        #expect(OwnDeckTidy.title(forName: "   ") == "Mina frågor")
        #expect(OwnDeckTidy.title(forName: String(repeating: "a", count: 200)).count == OwnDeck.titleLimit)
        // A deck that was named in English and is opened in Swedish is still "not named".
        #expect(OwnDeckText.isDefaultTitle("My questions") && !OwnDeckText.isDefaultTitle("Biologi"))
    }

    @Test func aCardKnowsWhatIsWrittenAndReadIn() {
        var card = OwnCard()
        #expect(card.isBlank && card.take(.question) == nil && card.text(.answer) == "")
        card.answer = "Although."
        #expect(!card.isBlank && card.text(.answer) == "Although.")
        card.questionRecording = OwnRecordingFile(name: "q.m4a", seconds: 3.4)
        #expect(card.take(.question)?.seconds == 3.4 && card.take(.answer) == nil)
    }

    // MARK: The words (Ke89 §5)

    @Test func theWordsAreKellys() {
        #expect(OwnDeckText.title == "Spela in själv" && OwnDeckText.free == "Helt gratis")
        #expect(OwnDeckText.entry == "Spela in själv – helt gratis")
        #expect(OwnDeckText.entryLine == "Skriv frågor och svar och läs in dem med din röst.")
        #expect(OwnDeckText.deckLine(cards: 5) == "Egen inspelning · 5 frågor")
        #expect(OwnDeckText.namePrompt == "T.ex. Glosor vecka 12")
        #expect(OwnDeckText.field(.question) == "Fråga" && OwnDeckText.field(.answer) == "Svar")
        #expect(OwnDeckText.record == "Spela in" && OwnDeckText.recordAgain == "Spela in igen" && OwnDeckText.notRecorded == "Inte inspelad")
        #expect(OwnDeckText.addCard == "Lägg till fråga" && OwnDeckText.delete == "Ta bort" && OwnDeckText.practise == "Öva")
        #expect(OwnDeckText.staysOnPhone == "Helt gratis. Ljudet stannar på din telefon.")
        #expect(OwnDeckText.micNote == "Mikrofonen används bara medan du spelar in.")
        #expect(OwnDeckText.recordLabel(.question) == "Spela in frågan" && OwnDeckText.recordLabel(.answer) == "Spela in svaret")
        #expect(OwnDeckText.playLabel(.question, seconds: 4.2) == "Spela upp frågan, 4 sekunder")
        #expect(OwnDeckText.clock(0) == "0:00" && OwnDeckText.clock(4.4) == "0:04" && OwnDeckText.clock(75) == "1:15")
        #expect(OwnDeckText.offerTitle(.credits) == "Slut på krediter?")
        #expect(OwnDeckText.offerTitle(.modelDown) == "Kan inte skapa prov just nu?")
        #expect(OwnDeckText.offerLine == "Spela in dina egna frågor och svar – helt gratis.")
    }

    @Test func theWordsAreInBothLanguages() {
        func text(_ key: String, _ language: AppLanguage) -> String {
            language.bundle.localizedString(forKey: key, value: "(missing)", table: nil)
        }
        let english = ["Spela in själv": "Record it yourself", "Helt gratis": "Completely free",
                       "Spela in själv – helt gratis": "Record it yourself – completely free",
                       "Skriv frågor och svar och läs in dem med din röst.": "Write questions and answers and record them in your own voice.",
                       "T.ex. Glosor vecka 12": "e.g. Vocabulary week 12", "Inte inspelad": "Not recorded",
                       "Lägg till fråga": "Add question", "Ta bort": "Delete", "Öva": "Practice",
                       "Helt gratis. Ljudet stannar på din telefon.": "Completely free. The sound stays on your phone.",
                       "Mikrofonen används bara medan du spelar in.": "The microphone is only used while you record.",
                       "Egen inspelning": "Your recording", "Slut på krediter?": "Out of credits?",
                       "Kan inte skapa prov just nu?": "Can't create quizzes right now?",
                       "Spela in dina egna frågor och svar – helt gratis.": "Record your own questions and answers – completely free.",
                       "Mina frågor": "My questions"]
        for (key, value) in english {
            #expect(text(key, .en) == value, "\(key)")
            #expect(text(key, .sv) == key, "\(key)")
        }
    }
}
