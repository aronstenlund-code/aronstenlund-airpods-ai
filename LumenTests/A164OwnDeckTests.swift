import Foundation
import Testing
@testable import Lumen

/// A164 (D263): "Spela in själv – helt gratis". The user's own deck of questions and answers, with their own
/// recordings, kept on the phone only and practised through the same player as a saved exam.
/// A pretend recorder and a pretend phone voice: no microphone, no speech, no network, 0 ElevenLabs (D180).
@MainActor
@Suite struct A164OwnDeckTests {
    // MARK: Pretend parts

    /// Records nothing: writes a few bytes where the recording should be, and says it lasted `seconds`.
    @MainActor final class FakeRecorder: OwnRecording {
        var elapsed: TimeInterval = 0
        var levelDBFS: Double?
        var onLimit: (@MainActor () -> Void)?
        var denied = false
        var seconds: TimeInterval = 4
        private(set) var target: URL?
        private(set) var starts = 0

        func start(to url: URL) async throws(OwnRecordingError) {
            if denied { throw .microphoneDenied }
            starts += 1
            target = url
            try? Data([1, 2, 3]).write(to: url)
        }

        func stop() -> TimeInterval? {
            guard target != nil else { return nil }
            target = nil
            return seconds
        }

        func cancel() {
            if let target { try? FileManager.default.removeItem(at: target) }
            target = nil
        }

        func reachLimit() { onLimit?() }
    }

    /// Speaks nothing: writes one byte where the spoken file should be, and remembers what it was asked to say.
    @MainActor final class FakeVoice: PhoneVoicing {
        struct Said: Equatable { var text: String; var language: String }
        private(set) var said: [Said] = []
        var fails = false

        func write(_ text: String, language: String, to url: URL) async -> Bool {
            if fails { return false }
            said.append(Said(text: text, language: language))
            return (try? Data([0]).write(to: url)) != nil
        }
    }

    struct Rig {
        let folder: URL
        let store: OwnDeckStore
        let recorder: FakeRecorder
        let voice: FakeVoice
        let source: A78RepetitionTests.MockSource
        let model: OwnDeckModel
    }

    private func makeRig(folder: URL = temporaryDirectory(), language: String = "sv") -> Rig {
        let store = OwnDeckStore(folder: folder)
        let recorder = FakeRecorder()
        let voice = FakeVoice()
        let source = A78RepetitionTests.MockSource()
        let model = OwnDeckModel(store: store, audio: OwnDeckAudio(store: store, voice: voice), recorder: recorder,
                                 makeSource: { source }, activatePlayback: {}, language: { language })
        return Rig(folder: folder, store: store, recorder: recorder, voice: voice, source: source, model: model)
    }

    private func exists(_ url: URL) -> Bool { FileManager.default.fileExists(atPath: url.path) }

    /// A deck with one card, and the card.
    private func deckWithCard(_ rig: Rig, question: String = "Vad är en cell?", answer: String = "Livets minsta del.") throws -> (deck: UUID, card: UUID) {
        let deck = rig.model.addDeck(title: "Biologi")
        let card = try #require(rig.model.addCard(to: deck.id, question: question, answer: answer))
        return (deck.id, card.id)
    }

    private func card(_ rig: Rig, _ ids: (deck: UUID, card: UUID)) throws -> OwnCard {
        try #require(rig.model.deck(ids.deck)?.cards.first { $0.id == ids.card })
    }

    // MARK: The deck is kept on the phone

    @Test func aDeckWithItsCardsIsKeptBetweenStarts() throws {
        let rig = makeRig()
        let deck = rig.model.addDeck(title: "  Glosor\nvecka 12  ")
        #expect(deck.title == "Glosor vecka 12")
        #expect(deck.language == "sv", "the phone's voice follows the app's language when the deck is made")
        let first = try #require(rig.model.addCard(to: deck.id))
        rig.model.setText("Vad heter hund på engelska?", for: .question, card: first.id, in: deck.id)
        rig.model.setText("Dog.", for: .answer, card: first.id, in: deck.id)
        rig.model.addCard(to: deck.id, question: "Katt?", answer: "Cat.")
        rig.model.rename(deck.id, to: "Glosor")

        let again = OwnDeckStore(folder: rig.folder)
        #expect(again.decks.count == 1)
        #expect(again.decks.first?.title == "Glosor")
        #expect(again.decks.first?.cards.map(\.question) == ["Vad heter hund på engelska?", "Katt?"])
        #expect(again.decks.first?.cards.map(\.answer) == ["Dog.", "Cat."])
        #expect(exists(rig.folder.appending(path: "decks.json")), "in the app's own folder, nowhere else")
    }

    @Test func theNewestDeckIsFirstAndLongTextsAreCut() throws {
        let rig = makeRig(language: "en")
        let old = rig.model.addDeck(title: "Old")
        let new = rig.model.addDeck(title: String(repeating: "x", count: 200))
        #expect(rig.model.decks.map(\.id) == [new.id, old.id])
        #expect(new.title.count == OwnDeck.titleLimit)
        #expect(new.language == "en")
        let card = try #require(rig.model.addCard(to: new.id, question: String(repeating: "q", count: 5_000)))
        #expect(card.question.count == OwnCard.textLimit)
        #expect(OwnDeck(title: "", language: "sv").shownTitle == "Egen inspelning", "a deck without a name still has one to show")
    }

    @Test func aDeckIsFullAtItsLimit() throws {
        let rig = makeRig()
        let deck = rig.model.addDeck(title: "Full")
        var saved = try #require(rig.model.deck(deck.id))
        saved.cards = (0..<OwnDeck.cardLimit).map { OwnCard(question: "q\($0)", answer: "a") }
        rig.store.save(saved)
        #expect(rig.model.addCard(to: deck.id) == nil)
        #expect(rig.model.addCard(to: UUID()) == nil, "a deck that is gone takes no cards")
    }

    @Test func cardsCanBeMoved() throws {
        let rig = makeRig()
        let deck = rig.model.addDeck(title: "Ordning")
        for name in ["a", "b", "c", "d"] { rig.model.addCard(to: deck.id, question: name, answer: "x") }
        rig.model.moveCards(in: deck.id, from: IndexSet(integer: 0), to: 3) // "a" to before "d"
        #expect(rig.model.deck(deck.id)?.cards.map(\.question) == ["b", "c", "a", "d"])
        rig.model.moveCards(in: deck.id, from: IndexSet(integer: 3), to: 0) // "d" first
        #expect(rig.model.deck(deck.id)?.cards.map(\.question) == ["d", "b", "c", "a"])
    }

    @Test func theSoundStaysOutOfTheBackup() throws {
        let rig = makeRig()
        for folder in [rig.store.audioFolder, rig.model.audio.spokenFolder] {
            let values = try folder.resourceValues(forKeys: [.isExcludedFromBackupKey])
            #expect(values.isExcludedFromBackup == true, "\(folder.lastPathComponent)")
        }
    }

    // MARK: Recording

    @Test func aRecordingIsKeptForItsPart() async throws {
        let rig = makeRig()
        let ids = try deckWithCard(rig)
        await rig.model.record(.question, card: ids.card, in: ids.deck)
        #expect(rig.model.recording == OwnDeckModel.Target(deckID: ids.deck, cardID: ids.card, part: .question))
        #expect(try card(rig, ids).questionRecording == nil, "nothing is kept before it is stopped")
        rig.model.stopRecording()
        #expect(rig.model.recording == nil)
        let file = try #require(try card(rig, ids).questionRecording)
        #expect(file.seconds == 4)
        #expect(exists(rig.store.url(for: file)))
        #expect(rig.store.url(for: file).deletingLastPathComponent().lastPathComponent == "audio")
        #expect(try card(rig, ids).answerRecording == nil)
        #expect(try card(rig, ids).isRecorded)
        // It is still there after a restart.
        #expect(OwnDeckStore(folder: rig.folder).decks.first?.cards.first?.questionRecording == file)
    }

    @Test func recordingAgainTakesTheOldOnesPlace() async throws {
        let rig = makeRig()
        let ids = try deckWithCard(rig)
        await rig.model.record(.answer, card: ids.card, in: ids.deck)
        rig.model.stopRecording()
        let old = try #require(try card(rig, ids).answerRecording)
        rig.recorder.seconds = 7
        await rig.model.record(.answer, card: ids.card, in: ids.deck)
        #expect(try card(rig, ids).answerRecording == old, "the old one stays until the new one is kept")
        rig.model.stopRecording()
        let new = try #require(try card(rig, ids).answerRecording)
        #expect(new.name != old.name && new.seconds == 7)
        #expect(!exists(rig.store.url(for: old)), "the old file is removed")
        #expect(exists(rig.store.url(for: new)))
    }

    @Test func cancellingKeepsTheOlderRecording() async throws {
        let rig = makeRig()
        let ids = try deckWithCard(rig)
        await rig.model.record(.question, card: ids.card, in: ids.deck)
        rig.model.stopRecording()
        let kept = try #require(try card(rig, ids).questionRecording)
        await rig.model.record(.question, card: ids.card, in: ids.deck)
        rig.model.cancelRecording()
        #expect(rig.model.recording == nil)
        #expect(try card(rig, ids).questionRecording == kept)
        #expect(exists(rig.store.url(for: kept)))
        let files = try FileManager.default.contentsOfDirectory(atPath: rig.store.audioFolder.path)
        #expect(files == [kept.name], "the cancelled recording left no file")
    }

    @Test func aRecordingThatReachesTheLimitIsKept() async throws {
        let rig = makeRig()
        let ids = try deckWithCard(rig)
        await rig.model.record(.question, card: ids.card, in: ids.deck)
        rig.recorder.seconds = OwnDeckModel.recordingLimit
        rig.recorder.reachLimit()
        #expect(rig.model.recording == nil)
        #expect(try card(rig, ids).questionRecording?.seconds == OwnDeckModel.recordingLimit)
    }

    @Test func aTapByMistakeIsNotARecording() async throws {
        let rig = makeRig()
        let ids = try deckWithCard(rig)
        rig.recorder.seconds = 0.1
        await rig.model.record(.question, card: ids.card, in: ids.deck)
        rig.model.stopRecording()
        #expect(try card(rig, ids).questionRecording == nil)
        #expect(try FileManager.default.contentsOfDirectory(atPath: rig.store.audioFolder.path).isEmpty)
    }

    @Test func aRefusedMicrophoneSaysSoAndKeepsNothing() async throws {
        let rig = makeRig()
        let ids = try deckWithCard(rig)
        rig.recorder.denied = true
        await rig.model.record(.question, card: ids.card, in: ids.deck)
        #expect(rig.model.recording == nil)
        #expect(rig.model.problem?.contains("mikrofonen") == true)
        #expect(try card(rig, ids).questionRecording == nil)
        // It works once the microphone is allowed, and the line goes away.
        rig.recorder.denied = false
        await rig.model.record(.question, card: ids.card, in: ids.deck)
        #expect(rig.model.problem == nil && rig.model.recording != nil)
    }

    @Test func oneRecordingAtATimeAndTheRunningOneIsKept() async throws {
        let rig = makeRig()
        let ids = try deckWithCard(rig)
        var stopped = 0
        rig.model.onWillRecord = { stopped += 1 }
        await rig.model.record(.question, card: ids.card, in: ids.deck)
        await rig.model.record(.answer, card: ids.card, in: ids.deck)
        #expect(try card(rig, ids).questionRecording != nil, "the question was kept when the answer started")
        #expect(rig.model.recording?.part == .answer)
        #expect(stopped == 2, "whatever plays is stopped before each recording")
        await rig.model.record(.question, card: UUID(), in: ids.deck)
        #expect(rig.model.recording?.part == .answer, "a card that is gone starts nothing")
    }

    @Test func deletingRemovesTheFilesToo() async throws {
        let rig = makeRig()
        let ids = try deckWithCard(rig)
        for part in OwnPart.allCases {
            await rig.model.record(part, card: ids.card, in: ids.deck)
            rig.model.stopRecording()
        }
        let question = try #require(try card(rig, ids).questionRecording)
        let answer = try #require(try card(rig, ids).answerRecording)
        rig.model.deleteRecording(.question, card: ids.card, in: ids.deck)
        #expect(try card(rig, ids).questionRecording == nil && !exists(rig.store.url(for: question)))
        #expect(exists(rig.store.url(for: answer)))

        let second = try #require(rig.model.addCard(to: ids.deck, question: "Två?", answer: "Ja."))
        await rig.model.record(.question, card: second.id, in: ids.deck)
        rig.model.stopRecording()
        let other = try #require(rig.model.deck(ids.deck)?.cards.last?.questionRecording)
        rig.model.deleteCard(second.id, in: ids.deck)
        #expect(!exists(rig.store.url(for: other)) && rig.model.deck(ids.deck)?.cards.count == 1)

        rig.model.delete(ids.deck)
        #expect(rig.model.decks.isEmpty && !exists(rig.store.url(for: answer)))
        #expect(try FileManager.default.contentsOfDirectory(atPath: rig.store.audioFolder.path).isEmpty)
    }

    // MARK: The sound for the player

    @Test func theRecordingIsPlayedAndThePhonesVoiceReadsTheRest() async throws {
        let rig = makeRig()
        let ids = try deckWithCard(rig)
        await rig.model.record(.question, card: ids.card, in: ids.deck)
        rig.model.stopRecording()
        let recorded = try card(rig, ids)
        let file = try #require(recorded.questionRecording)
        #expect(rig.model.track(in: ids.deck, at: 0) == nil, "the answer has no sound yet: the player waits")

        await rig.model.audio.prepare([recorded], language: "sv")
        #expect(rig.voice.said == [FakeVoice.Said(text: "Livets minsta del.", language: "sv")], "only what has no recording is spoken")
        let track = try #require(rig.model.track(in: ids.deck, at: 0))
        #expect(track.question == rig.store.url(for: file))
        #expect(track.long == rig.model.audio.spokenURL(for: "Livets minsta del.", language: "sv"))
        #expect(track.short == .prefix(ofLongUntil: .infinity), "there is one answer: the short one is the whole of it")

        await rig.model.audio.prepare([recorded], language: "sv")
        #expect(rig.voice.said.count == 1, "the same text is spoken once")
        #expect(rig.model.track(in: ids.deck, at: 1) == nil)
    }

    @Test func aVoiceThatMakesNoSoundLeavesNoFile() async throws {
        let rig = makeRig()
        let ids = try deckWithCard(rig)
        rig.voice.fails = true
        await rig.model.audio.prepare([try card(rig, ids)], language: "sv")
        #expect(rig.model.track(in: ids.deck, at: 0) == nil)
        #expect(try FileManager.default.contentsOfDirectory(atPath: rig.model.audio.spokenFolder.path).isEmpty)
    }

    @Test func whatThePlayerGetsIsTheDeckAsAnExamThatIsNeverSaved() throws {
        let rig = makeRig()
        let ids = try deckWithCard(rig)
        rig.model.addCard(to: ids.deck, question: "Bara en fråga", answer: "  ")
        rig.model.addCard(to: ids.deck, question: "Två?", answer: "Ja.")
        let deck = try #require(rig.model.deck(ids.deck))
        #expect(deck.playableCards.map(\.question) == ["Vad är en cell?", "Två?"], "a card without an answer is not practised")
        #expect(rig.model.canStart(deck))
        let drill = deck.drill()
        #expect(drill.id == deck.id && drill.title == "Biologi")
        #expect(drill.items.map(\.id) == deck.playableCards.map(\.id))
        #expect(drill.items.first?.long == "Livets minsta del." && drill.items.first?.short == "Livets minsta del.")
        #expect(drill.serverID == nil && drill.needsUpload == nil)
        // Kelly (Ke89): only the cards whose question is recorded.
        #expect(deck.playable(onlyRecorded: true).isEmpty)
        #expect(!rig.model.canStart(OwnDeck(title: "Tom", language: "sv")))
    }

    // MARK: Listening to one part

    @Test func listeningToOnePartPlaysItsRecording() async throws {
        let rig = makeRig()
        let ids = try deckWithCard(rig)
        await rig.model.record(.question, card: ids.card, in: ids.deck)
        rig.model.stopRecording()
        let file = try #require(try card(rig, ids).questionRecording)
        await rig.model.preview(.question, card: ids.card, in: ids.deck)
        #expect(rig.model.previewing?.part == .question)
        #expect(rig.source.last.url == rig.store.url(for: file) && rig.source.last.isPlaying)
        rig.source.last.finish()
        #expect(rig.model.previewing == nil)
        // A part without a recording is read by the phone's voice.
        await rig.model.preview(.answer, card: ids.card, in: ids.deck)
        #expect(rig.voice.said.map(\.text) == ["Livets minsta del."])
        #expect(rig.source.last.url == rig.model.audio.spokenURL(for: "Livets minsta del.", language: "sv"))
        rig.model.stopPreview()
        #expect(rig.model.previewing == nil && rig.source.last.stopped)
    }

    // MARK: Practising: the same player, no server, no credits

    @Test func practisingGoesThroughTheExamPlayerAndNeverTouchesTheServerOrTheExamStore() async throws {
        let rig = makeRig()
        let ids = try deckWithCard(rig)
        for part in OwnPart.allCases {
            await rig.model.record(part, card: ids.card, in: ids.deck)
            rig.model.stopRecording()
        }
        let cloud = A79A81RepetitionTests.MockCloud()
        let store = DrillStore(url: temporaryDirectory().appending(path: "drills.json"))
        let source = A78RepetitionTests.MockSource()
        let session = RepetitionSession(inputs: [], makeSource: { source }, makeTimer: { A78RepetitionTests.MockTimer() },
                                        defaults: try #require(UserDefaults(suiteName: "a164-\(UUID())")),
                                        activatesAudioSession: false)
        let model = RepetitionModel(store: store, session: session, maker: MockDrillMaker(),
                                    audio: DeviceVoiceDrillAudio(folder: temporaryDirectory(), makesSound: false),
                                    sharing: DrillShareClient(cloud: cloud), remote: RemoteCommandHub(), cloud: cloud)
        model.ownDecks = rig.model
        let deck = try #require(rig.model.deck(ids.deck))
        let recorded = try #require(deck.cards.first)

        await model.start(own: deck)
        #expect(session.player != nil && model.showsPlayer, "the same player and the same screen as a saved exam")
        #expect(session.drill?.id == deck.id && session.drill?.items.count == 1)
        #expect(source.last.url == rig.store.url(for: try #require(recorded.questionRecording)), "the question is heard in the user's own voice")
        session.player?.handle(.long)
        #expect(source.last.url == rig.store.url(for: try #require(recorded.answerRecording)), "one press: the answer, in the user's own voice")

        #expect(cloud.saves.isEmpty && cloud.statusCalls == 0 && cloud.downloads.isEmpty, "nothing is asked of the server")
        #expect(store.drills.isEmpty, "the deck is never in the exam store, so nothing can upload it")
        #expect(rig.voice.said.isEmpty, "everything was recorded: the phone's voice is not needed")
        model.end()
        #expect(!model.showsPlayer)
    }

    @Test func aDeckWithNothingToPractiseStartsNothing() async throws {
        let rig = makeRig()
        let deck = rig.model.addDeck(title: "Tom")
        let session = RepetitionSession(inputs: [], makeSource: { A78RepetitionTests.MockSource() }, makeTimer: { A78RepetitionTests.MockTimer() },
                                        defaults: try #require(UserDefaults(suiteName: "a164-\(UUID())")),
                                        activatesAudioSession: false)
        let cloud = A79A81RepetitionTests.MockCloud()
        let model = RepetitionModel(store: DrillStore(url: temporaryDirectory().appending(path: "drills.json")), session: session,
                                    maker: MockDrillMaker(), audio: DeviceVoiceDrillAudio(folder: temporaryDirectory(), makesSound: false),
                                    sharing: DrillShareClient(cloud: cloud), remote: RemoteCommandHub(), cloud: cloud)
        model.ownDecks = rig.model
        await model.start(own: deck)
        #expect(session.player == nil && !model.showsPlayer)
    }

    #if LUMEN_TESTMODE
    // MARK: Toby's seed (T58)

    @Test func theSeedGivesOneDeckOnceAndASilentVoice() async throws {
        let store = OwnDeckStore(folder: temporaryDirectory())
        #expect(OwnDeckSeed.seed(into: store, language: "en"))
        #expect(store.decks.count == 1 && store.decks.first?.cards.count == 3 && store.decks.first?.language == "en")
        #expect(!OwnDeckSeed.seed(into: store, language: "en"), "only into an empty store")
        let audio = OwnDeckAudio(store: store, voice: SilentPhoneVoice())
        let cards = try #require(store.decks.first?.cards)
        await audio.prepare(cards, language: "en")
        #expect(cards.allSatisfy { audio.track(for: $0, language: "en") != nil })
    }
    #endif
}
