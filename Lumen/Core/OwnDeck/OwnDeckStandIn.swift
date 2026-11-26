import Foundation
import Observation

// A165 STAND-IN, ONLY ON ANGELA FABLE'S BRANCH, NEVER ON MAIN.
// The signatures of Angela Schrute's core for "Spela in själv" (A164, D263) as she wrote them in
// `prompts/queue/angela-fable.md` on 2026-11-26 09:05, kept in memory, so the views can be built, tested and
// photographed before the core is on main. When the core is on main this file is deleted and nothing else changes.

struct OwnRecordingFile: Codable, Equatable, Sendable {
    var name: String
    var seconds: Double
}

enum OwnPart: String, Codable, Sendable, CaseIterable {
    case question, answer
}

struct OwnCard: Codable, Identifiable, Equatable, Sendable {
    var id = UUID()
    var question = ""
    var answer = ""
    var questionRecording: OwnRecordingFile?
    var answerRecording: OwnRecordingFile?
    static let textLimit = 1000

    func has(_ part: OwnPart) -> Bool {
        let text = part == .question ? question : answer
        let recording = part == .question ? questionRecording : answerRecording
        return recording != nil || !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var isPlayable: Bool { has(.question) && has(.answer) }
}

struct OwnDeck: Codable, Identifiable, Equatable, Sendable {
    var id = UUID()
    var title: String
    var cards: [OwnCard] = []
    var language = "sv"
    var createdAt = Date()
    var updatedAt = Date()
    static let titleLimit = 60
    static let cardLimit = 200

    var playableCards: [OwnCard] { cards.filter(\.isPlayable) }
}

@MainActor
@Observable
final class OwnDeckModel {
    private(set) var decks: [OwnDeck]

    struct Target: Equatable, Sendable {
        var deckID: UUID
        var cardID: UUID
        var part: OwnPart
    }

    private(set) var recording: Target?
    private(set) var elapsed: TimeInterval = 0
    private(set) var levelDBFS: Double?
    private(set) var problem: String?
    static let recordingLimit: TimeInterval = 300
    private(set) var previewing: Target?

    /// Stand-in only: decks to begin with.
    init(decks: [OwnDeck] = []) {
        self.decks = decks
    }

    func deck(_ id: UUID) -> OwnDeck? { decks.first { $0.id == id } }

    @discardableResult
    func addDeck(title: String) -> OwnDeck {
        let deck = OwnDeck(title: String(title.prefix(OwnDeck.titleLimit)), language: AppLanguage.current == .sv ? "sv" : "en")
        decks.insert(deck, at: 0)
        return deck
    }

    func rename(_ deckID: UUID, to title: String) {
        change(deckID) { $0.title = String(title.prefix(OwnDeck.titleLimit)) }
    }

    func delete(_ deckID: UUID) {
        decks.removeAll { $0.id == deckID }
    }

    @discardableResult
    func addCard(to deckID: UUID, question: String = "", answer: String = "") -> OwnCard? {
        guard let deck = deck(deckID), deck.cards.count < OwnDeck.cardLimit else { return nil }
        let card = OwnCard(question: question, answer: answer)
        change(deckID) { $0.cards.append(card) }
        return card
    }

    func setText(_ text: String, for part: OwnPart, card: UUID, in deckID: UUID) {
        change(deckID) { deck in
            guard let index = deck.cards.firstIndex(where: { $0.id == card }) else { return }
            let kept = String(text.prefix(OwnCard.textLimit))
            if part == .question { deck.cards[index].question = kept } else { deck.cards[index].answer = kept }
        }
    }

    func deleteCard(_ cardID: UUID, in deckID: UUID) {
        change(deckID) { $0.cards.removeAll { $0.id == cardID } }
    }

    func moveCards(in deckID: UUID, from: IndexSet, to: Int) {
        change(deckID) { deck in
            let moved = from.sorted().filter { deck.cards.indices.contains($0) }.map { deck.cards[$0] }
            let before = from.filter { $0 < to }.count
            deck.cards.removeAll { card in moved.contains { $0.id == card.id } }
            deck.cards.insert(contentsOf: moved, at: min(max(0, to - before), deck.cards.count))
        }
    }

    func record(_ part: OwnPart, card: UUID, in deckID: UUID) async {
        previewing = nil
        problem = nil
        recording = Target(deckID: deckID, cardID: card, part: part)
        elapsed = 0
    }

    func stopRecording() {
        guard let target = recording else { return }
        set(OwnRecordingFile(name: "\(target.cardID)-\(target.part.rawValue).m4a", seconds: max(elapsed, 1)), for: target)
        recording = nil
    }

    func cancelRecording() {
        recording = nil
    }

    func deleteRecording(_ part: OwnPart, card: UUID, in deckID: UUID) {
        set(nil, for: Target(deckID: deckID, cardID: card, part: part))
    }

    func preview(_ part: OwnPart, card: UUID, in deckID: UUID) async {
        previewing = Target(deckID: deckID, cardID: card, part: part)
    }

    func stopPreview() {
        previewing = nil
    }

    func canStart(_ deck: OwnDeck) -> Bool { !deck.playableCards.isEmpty }

    private func change(_ deckID: UUID, _ edit: (inout OwnDeck) -> Void) {
        guard let index = decks.firstIndex(where: { $0.id == deckID }) else { return }
        edit(&decks[index])
        decks[index].updatedAt = Date()
    }

    private func set(_ file: OwnRecordingFile?, for target: Target) {
        change(target.deckID) { deck in
            guard let index = deck.cards.firstIndex(where: { $0.id == target.cardID }) else { return }
            if target.part == .question { deck.cards[index].questionRecording = file } else { deck.cards[index].answerRecording = file }
        }
    }

    // Stand-in only, for the pictures and the tests: a recording that is going on, and what was practised.
    func stage(recording target: Target?, elapsed: TimeInterval = 0, levelDBFS: Double? = nil, problem: String? = nil) {
        recording = target
        self.elapsed = elapsed
        self.levelDBFS = levelDBFS
        self.problem = problem
    }

    fileprivate(set) var started: [UUID] = []
}

extension RepetitionModel {
    /// Stand-in: the core plays the deck through the same player as a saved quiz. Here it is only noted.
    func start(own deck: OwnDeck, at index: Int = 0) async {
        ownDecks?.started.append(deck.id)
    }
}
