import AVFoundation
import Foundation
import Observation

/// A164 (D263): everything the screens of "Spela in själv" need (Angela Fable's A165): the decks and their cards,
/// recording one part at a time, listening to one part, and what can be practised. Practising itself is
/// `RepetitionModel.start(own:)`: the same player and the same screen as a saved exam.
/// No network and no credits: this type has no way to reach the server.
@MainActor
@Observable
final class OwnDeckModel {
    /// One part of one card: what is being recorded, or listened to.
    struct Target: Equatable, Sendable {
        var deckID: UUID
        var cardID: UUID
        var part: OwnPart
    }

    /// A recording stops by itself here and is kept.
    nonisolated static let recordingLimit: TimeInterval = 300
    /// A tap by mistake is not a recording.
    nonisolated static let shortestRecording: TimeInterval = 0.3

    /// What is being recorded right now.
    private(set) var recording: Target?
    /// What is being listened to right now (the ▶ in the editor).
    private(set) var previewing: Target?
    /// Why the last recording did not start, in the app's language (the microphone was refused, …).
    private(set) var problem: String?
    /// Set by the app: a recording starts, so whatever plays is stopped first (the exam player).
    @ObservationIgnored var onWillRecord: (@MainActor () -> Void)?

    @ObservationIgnored let store: OwnDeckStore
    @ObservationIgnored let audio: OwnDeckAudio
    @ObservationIgnored private let recorder: any OwnRecording
    @ObservationIgnored private let makeSource: @MainActor () -> any RepetitionAudioSource
    @ObservationIgnored private let activatePlayback: @MainActor () -> Void
    @ObservationIgnored private let language: @MainActor () -> String
    @ObservationIgnored private var pendingURL: URL?
    @ObservationIgnored private var previewPlayer: (any RepetitionAudioPlayer)?

    init(store: OwnDeckStore, audio: OwnDeckAudio, recorder: (any OwnRecording)? = nil,
         makeSource: @escaping @MainActor () -> any RepetitionAudioSource = { FileRepetitionAudioSource() },
         activatePlayback: @escaping @MainActor () -> Void = { OwnDeckModel.activatePlaybackSession() },
         language: @escaping @MainActor () -> String = { AppLanguage.current.code }) {
        self.store = store
        self.audio = audio
        self.recorder = recorder ?? OwnRecorder()
        self.makeSource = makeSource
        self.activatePlayback = activatePlayback
        self.language = language
        self.recorder.onLimit = { [weak self] in self?.stopRecording() }
    }

    // MARK: Decks and cards

    /// Newest first.
    var decks: [OwnDeck] { store.decks }

    func deck(_ id: UUID) -> OwnDeck? {
        store.deck(id)
    }

    @discardableResult
    func addDeck(title: String) -> OwnDeck {
        let deck = OwnDeck(title: OwnDeck.cleanedTitle(title), language: language() == "sv" ? "sv" : "en")
        store.save(deck)
        return store.deck(deck.id) ?? deck
    }

    func rename(_ deckID: UUID, to title: String) {
        change(deckID) { $0.title = OwnDeck.cleanedTitle(title) }
    }

    /// The deck, its texts and its recordings.
    func delete(_ deckID: UUID) {
        if recording?.deckID == deckID { cancelRecording() }
        if previewing?.deckID == deckID { stopPreview() }
        store.delete(deckID)
    }

    /// A new card last in the deck; nil when the deck is gone or full (`OwnDeck.cardLimit`).
    @discardableResult
    func addCard(to deckID: UUID, question: String = "", answer: String = "") -> OwnCard? {
        guard let deck = store.deck(deckID), deck.cards.count < OwnDeck.cardLimit else { return nil }
        let card = OwnCard(question: Self.cleanedText(question), answer: Self.cleanedText(answer))
        change(deckID) { $0.cards.append(card) }
        return card
    }

    func setText(_ text: String, for part: OwnPart, card cardID: UUID, in deckID: UUID) {
        let text = Self.cleanedText(text)
        change(deckID) { deck in
            guard let index = deck.cards.firstIndex(where: { $0.id == cardID }) else { return }
            switch part {
            case .question: deck.cards[index].question = text
            case .answer: deck.cards[index].answer = text
            }
        }
    }

    func deleteCard(_ cardID: UUID, in deckID: UUID) {
        if recording?.cardID == cardID { cancelRecording() }
        if previewing?.cardID == cardID { stopPreview() }
        guard let card = store.deck(deckID)?.cards.first(where: { $0.id == cardID }) else { return }
        store.remove(card.questionRecording)
        store.remove(card.answerRecording)
        change(deckID) { $0.cards.removeAll { $0.id == cardID } }
    }

    /// As a list's `onMove`: the cards at `from` end up before what was at `to`.
    func moveCards(in deckID: UUID, from: IndexSet, to: Int) {
        change(deckID) { deck in
            let moving = from.sorted().compactMap { deck.cards.indices.contains($0) ? deck.cards[$0] : nil }
            var rest = deck.cards.enumerated().filter { !from.contains($0.offset) }.map(\.element)
            let before = from.filter { $0 < to }.count
            rest.insert(contentsOf: moving, at: max(0, min(rest.count, to - before)))
            deck.cards = rest
        }
    }

    /// At least one card with a question and an answer.
    func canStart(_ deck: OwnDeck) -> Bool {
        !deck.playableCards.isEmpty
    }

    static func cleanedText(_ typed: String) -> String {
        String(typed.prefix(OwnCard.textLimit))
    }

    private func change(_ deckID: UUID, _ edit: (inout OwnDeck) -> Void) {
        guard var deck = store.deck(deckID) else { return }
        edit(&deck)
        store.save(deck)
    }

    // MARK: Recording, one part at a time

    /// While it records: for the timer and the level mark on the screen.
    var elapsed: TimeInterval { recorder.elapsed }
    var levelDBFS: Double? { recorder.levelDBFS }

    /// Starts recording this part. The first time, iOS asks for the microphone. A recording that was running is
    /// stopped and kept first. An older recording of the same part stays until the new one is stopped and kept.
    func record(_ part: OwnPart, card cardID: UUID, in deckID: UUID) async {
        guard store.deck(deckID)?.cards.contains(where: { $0.id == cardID }) == true else { return }
        stopPreview()
        if recording != nil { stopRecording() }
        onWillRecord?()
        problem = nil
        let url = store.newRecordingURL()
        do throws(OwnRecordingError) {
            try await recorder.start(to: url)
        } catch {
            problem = Self.words(for: error)
            return
        }
        pendingURL = url
        recording = Target(deckID: deckID, cardID: cardID, part: part)
    }

    /// Stops and keeps the recording; it takes the place of an older recording of the same part.
    func stopRecording() {
        guard let target = recording, let url = pendingURL else { return }
        recording = nil
        pendingURL = nil
        guard let seconds = recorder.stop(), seconds >= Self.shortestRecording,
              FileManager.default.fileExists(atPath: url.path),
              let old = store.deck(target.deckID)?.cards.first(where: { $0.id == target.cardID }) else {
            try? FileManager.default.removeItem(at: url)
            return
        }
        let file = OwnRecordingFile(name: url.lastPathComponent, seconds: seconds)
        store.remove(old.recording(target.part))
        setRecording(file, for: target)
    }

    /// Stops and throws the recording away; an older recording of the same part stays.
    func cancelRecording() {
        guard recording != nil else { return }
        recording = nil
        recorder.cancel()
        if let url = pendingURL { try? FileManager.default.removeItem(at: url) }
        pendingURL = nil
    }

    func deleteRecording(_ part: OwnPart, card cardID: UUID, in deckID: UUID) {
        let target = Target(deckID: deckID, cardID: cardID, part: part)
        if recording == target { cancelRecording() }
        if previewing == target { stopPreview() }
        guard let card = store.deck(deckID)?.cards.first(where: { $0.id == cardID }) else { return }
        store.remove(card.recording(part))
        setRecording(nil, for: target)
    }

    private func setRecording(_ file: OwnRecordingFile?, for target: Target) {
        change(target.deckID) { deck in
            guard let index = deck.cards.firstIndex(where: { $0.id == target.cardID }) else { return }
            switch target.part {
            case .question: deck.cards[index].questionRecording = file
            case .answer: deck.cards[index].answerRecording = file
            }
        }
    }

    private static func words(for error: OwnRecordingError) -> String {
        switch error {
        case .microphoneDenied:
            String(localized: "EarMind får inte använda mikrofonen. Slå på den i Inställningar › EarMind › Mikrofon.")
        case .failed:
            String(localized: "Det gick inte att spela in just nu. Försök igen.")
        }
    }

    // MARK: Listening to one part

    /// Plays this part once: the recording, otherwise the phone's own voice reading the text.
    func preview(_ part: OwnPart, card cardID: UUID, in deckID: UUID) async {
        stopPreview()
        if recording != nil { stopRecording() }
        guard let deck = store.deck(deckID), let card = deck.cards.first(where: { $0.id == cardID }), card.has(part) else { return }
        let target = Target(deckID: deckID, cardID: cardID, part: part)
        previewing = target
        if audio.url(part, of: card, language: deck.language) == nil {
            await audio.prepare([card], language: deck.language)
        }
        // Something else was asked for while the voice was made.
        guard previewing == target, let url = audio.url(part, of: card, language: deck.language),
              let player = try? makeSource().player(for: url) else {
            if previewing == target { previewing = nil }
            return
        }
        activatePlayback()
        player.onFinish = { [weak self] in
            guard let self, self.previewing == target else { return }
            self.previewPlayer = nil
            self.previewing = nil
        }
        previewPlayer = player
        player.play(until: nil)
    }

    func stopPreview() {
        previewPlayer?.stop()
        previewPlayer = nil
        previewing = nil
    }

    /// Practising starts: nothing is recorded or listened to meanwhile. A running recording is kept.
    func stopForPractice() {
        stopPreview()
        if recording != nil { stopRecording() }
    }

    // MARK: For the player

    /// The sound of the card at `index` among the deck's playable cards, as the deck is now.
    func track(in deckID: UUID, at index: Int, onlyRecorded: Bool = false) -> RepetitionTrack? {
        guard let deck = store.deck(deckID) else { return nil }
        let cards = deck.playable(onlyRecorded: onlyRecorded)
        guard cards.indices.contains(index) else { return nil }
        return audio.track(for: cards[index], language: deck.language)
    }

    nonisolated static func activatePlaybackSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [])
        try? session.setActive(true)
    }
}
