import Foundation
import Observation

// A165 (D263): "Spela in själv – helt gratis". The user writes their own questions and answers, reads them in with
// their own voice, and practises them like a saved quiz. No server, no model, no credits; the sound stays on the
// phone. This file is what the views need: the types they show, the protocol they talk to (`OwnDecking`, the
// core's side of it is Angela Schrute's A164), the words, and when the sheet that points here comes up.

/// One question with its answer, as the user wrote them.
struct OwnCard: Identifiable, Equatable, Sendable {
    var id = UUID()
    var question: String
    var answer: String

    var hasQuestion: Bool { !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}

/// A collection of the user's own questions.
struct OwnDeck: Identifiable, Equatable, Sendable {
    var id = UUID()
    var title: String
    var cards: [OwnCard] = []
}

/// Which of a card's two recordings.
enum OwnSide: String, Sendable, CaseIterable {
    case question, answer
}

/// One recording: a side of a card in a deck. The card need not be saved yet (a new card is recorded before Klar);
/// `OwnDecking.deleteCard` removes its recordings whether it was saved or not.
struct OwnTake: Hashable, Sendable {
    var deck: UUID
    var card: UUID
    var side: OwnSide
}

/// What the views of "Spela in själv" need from the core (A164): the decks, one recording at a time with the
/// phone's or the AirPods' microphone, listening to a recording, and practising a deck through the same player as
/// a saved quiz. Everything is on the phone; nothing here reaches the network.
@MainActor
protocol OwnDecking: AnyObject, Observable {
    var decks: [OwnDeck] { get }
    @discardableResult func addDeck(title: String) -> OwnDeck
    func rename(deck id: UUID, to title: String)
    /// The deck, its cards and their recordings.
    func deleteDeck(_ id: UUID)
    /// Adds the card, or replaces the one with the same id (its recordings are kept).
    func save(_ card: OwnCard, in deck: UUID)
    /// The card and its recordings (also the recordings of a card that was never saved).
    func deleteCard(_ id: UUID, in deck: UUID)

    /// How long the recording is; nil when there is none (the phone's own voice reads that side when practising).
    func seconds(of take: OwnTake) -> TimeInterval?
    /// What records now, how long it has recorded and how loud it is (dBFS, nil when unknown).
    var recording: OwnTake? { get }
    var elapsed: TimeInterval { get }
    var levelDBFS: Double? { get }
    /// The longest one recording can be; the core stops there by itself.
    var takeLimit: TimeInterval { get }
    /// Why recording or playing could not start ("Tillåt mikrofonen …"), until the next attempt.
    var problem: String? { get }
    /// Starts recording (asks for the microphone the first time). A recording that was there is replaced when
    /// this one is stopped.
    func record(_ take: OwnTake) async
    func stopRecording()
    func deleteTake(_ take: OwnTake)

    /// What is being listened to now.
    var playing: OwnTake? { get }
    func play(_ take: OwnTake)
    func stopPlaying()

    /// Practises the deck as a saved quiz: the own recordings in the AirPods, the phone's voice for what has none.
    func practise(_ deck: UUID) async
}

extension OwnDecking {
    func deck(_ id: UUID) -> OwnDeck? { decks.first { $0.id == id } }

    /// How many of the deck's sides (questions and answers that have a text) have an own recording.
    func recorded(in deck: OwnDeck) -> (done: Int, of: Int) {
        var done = 0
        var total = 0
        for card in deck.cards {
            for side in OwnSide.allCases {
                let isRecorded = seconds(of: OwnTake(deck: deck.id, card: card.id, side: side)) != nil
                // An answer that is neither written nor read in is not something to record.
                let counts = side == .question || isRecorded || !card.answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                if counts { total += 1 }
                if isRecorded { done += 1 }
            }
        }
        return (done, total)
    }
}

// MARK: The sheet that points here

/// When the server says no for credits (402) or because its model is down (`provider_*`), a sheet says that one
/// can record one's own questions and answers for free, with a button there. Once per occasion: after it has been
/// shown for a reason it is not shown for that reason again until the server has said yes in between.
@MainActor
@Observable
final class OwnDeckOffer {
    enum Reason: String, Sendable {
        case credits, modelDown
    }

    /// The sheet to show now.
    private(set) var showing: Reason?
    /// The sheet's button was pressed: Start opens "Spela in själv" (and sets this back).
    var opensDecks = false
    @ObservationIgnored private var said: Set<Reason> = []

    func serverRefused(_ reason: Reason) {
        guard showing == nil, said.insert(reason).inserted else { return }
        showing = reason
    }

    /// The server did what it refused before: the occasion is over, and the next no is a new one.
    func serverAnswered(_ reason: Reason) {
        said.remove(reason)
    }

    /// Closed with a tap or a pull.
    func close() {
        showing = nil
    }

    /// The sheet's button.
    func open() {
        showing = nil
        opensDecks = true
    }
}

// MARK: The words

enum OwnDeckText {
    static var title: String { String(localized: "Spela in själv") }
    static var free: String { String(localized: "Helt gratis") }
    /// The way in, where it stands as one line.
    static var entry: String { String(localized: "Spela in själv – helt gratis") }

    static var emptyTitle: String { String(localized: "Egna frågor med din röst") }
    static var emptyLine: String {
        String(localized: "Skriv dina frågor och svar och läs in dem. Sedan övar du på dem i dina AirPods. Helt gratis – inga krediter.")
    }
    static var newDeck: String { String(localized: "Ny samling") }
    static var deckNamePrompt: String { String(localized: "Namn, till exempel Biologi kapitel 3") }
    static var create: String { String(localized: "Skapa") }
    static var newCard: String { String(localized: "Ny fråga") }
    static var practise: String { String(localized: "Öva") }
    static var addFirst: String { String(localized: "Lägg till en fråga först.") }
    static var practiseNote: String {
        String(localized: "Dina inspelningar spelas i AirPods. Det som inte är inspelat läses av telefonens röst.")
    }
    static var staysOnPhone: String { String(localized: "Helt gratis. Ljudet stannar på telefonen.") }

    static func cards(_ count: Int) -> String {
        count == 1 ? String(localized: "1 fråga") : String(localized: "\(count) frågor")
    }

    /// "3 frågor · 4 av 6 inspelade", "3 frågor · allt inspelat", "3 frågor"; "Inga frågor än".
    static func facts(cards: Int, recorded: (done: Int, of: Int)) -> String {
        guard cards > 0 else { return String(localized: "Inga frågor än") }
        if recorded.done == 0 { return OwnDeckText.cards(cards) }
        if recorded.done >= recorded.of { return String(localized: "\(OwnDeckText.cards(cards)) · allt inspelat") }
        return String(localized: "\(OwnDeckText.cards(cards)) · \(recorded.done) av \(recorded.of) inspelade")
    }

    /// Under a card's question in the deck: what is recorded.
    static func cardLine(question: Bool, answer: Bool, hasAnswer: Bool) -> String {
        if question, answer || !hasAnswer { return String(localized: "Inspelad") }
        if question { return String(localized: "Frågan inspelad") }
        if answer { return String(localized: "Svaret inspelat") }
        return String(localized: "Inte inspelad än")
    }

    static func sideTitle(_ side: OwnSide) -> String {
        side == .question ? String(localized: "Fråga") : String(localized: "Svar")
    }
    static func prompt(_ side: OwnSide) -> String {
        side == .question ? String(localized: "Skriv frågan") : String(localized: "Skriv svaret")
    }
    static func record(_ side: OwnSide) -> String {
        side == .question ? String(localized: "Spela in frågan") : String(localized: "Spela in svaret")
    }
    static var recordAgain: String { String(localized: "Spela in igen") }
    static var stop: String { String(localized: "Stoppa") }
    static func recording(_ elapsed: TimeInterval) -> String { String(localized: "Spelar in · \(clock(elapsed))") }
    static func listen(_ seconds: TimeInterval) -> String { String(localized: "Spela upp · \(clock(seconds))") }
    static var editorNote: String {
        String(localized: "Läs som du vill höra det. Utan inspelning läser telefonens röst texten.")
    }

    static func clock(_ seconds: TimeInterval) -> String {
        let whole = max(0, Int(seconds.rounded()))
        return "\(whole / 60):" + String(format: "%02d", whole % 60)
    }

    // The sheet
    static func offerTitle(_ reason: OwnDeckOffer.Reason) -> String {
        reason == .credits ? String(localized: "Slut på krediter?") : String(localized: "EarMind kan inte svara just nu")
    }
    static var offerLine: String { String(localized: "Spela in dina egna frågor och svar – helt gratis.") }
    static var notNow: String { String(localized: "Inte nu") }
}

/// The editor's card while it is written: Klar needs a question.
struct OwnCardDraft: Equatable {
    var card: OwnCard
    let isNew: Bool

    init(editing card: OwnCard?) {
        self.card = card ?? OwnCard(question: "", answer: "")
        isNew = card == nil
    }

    var canSave: Bool { card.hasQuestion }

    /// The card as it is saved: without blanks around the texts.
    var cleaned: OwnCard {
        var copy = card
        copy.question = card.question.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.answer = card.answer.trimmingCharacters(in: .whitespacesAndNewlines)
        return copy
    }
}

#if DEBUG
/// The pictures and the tests: decks in memory, recordings that are only lengths, nothing recorded or played.
@MainActor
@Observable
final class PretendOwnDecks: OwnDecking {
    var decks: [OwnDeck]
    var takes: [OwnTake: TimeInterval] = [:]
    var recording: OwnTake?
    var elapsed: TimeInterval = 0
    var levelDBFS: Double?
    let takeLimit: TimeInterval = 120
    var problem: String?
    var playing: OwnTake?
    private(set) var practised: [UUID] = []

    init(decks: [OwnDeck] = []) {
        self.decks = decks
    }

    @discardableResult
    func addDeck(title: String) -> OwnDeck {
        let deck = OwnDeck(title: title)
        decks.insert(deck, at: 0)
        return deck
    }

    func rename(deck id: UUID, to title: String) {
        guard let index = decks.firstIndex(where: { $0.id == id }) else { return }
        decks[index].title = title
    }

    func deleteDeck(_ id: UUID) {
        decks.removeAll { $0.id == id }
        takes = takes.filter { $0.key.deck != id }
    }

    func save(_ card: OwnCard, in deck: UUID) {
        guard let index = decks.firstIndex(where: { $0.id == deck }) else { return }
        if let at = decks[index].cards.firstIndex(where: { $0.id == card.id }) {
            decks[index].cards[at] = card
        } else {
            decks[index].cards.append(card)
        }
    }

    func deleteCard(_ id: UUID, in deck: UUID) {
        if let index = decks.firstIndex(where: { $0.id == deck }) { decks[index].cards.removeAll { $0.id == id } }
        takes = takes.filter { $0.key.card != id }
    }

    func seconds(of take: OwnTake) -> TimeInterval? { takes[take] }

    func record(_ take: OwnTake) async {
        playing = nil
        recording = take
        elapsed = 0
    }

    func stopRecording() {
        guard let take = recording else { return }
        takes[take] = max(elapsed, 1)
        recording = nil
    }

    func deleteTake(_ take: OwnTake) { takes[take] = nil }
    func play(_ take: OwnTake) { if takes[take] != nil { playing = take } }
    func stopPlaying() { playing = nil }
    func practise(_ deck: UUID) async { practised.append(deck) }
}
#endif
