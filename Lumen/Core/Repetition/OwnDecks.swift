import Foundation
import Observation

// A165 (D263): "Spela in själv – helt gratis", what the views add to the core (A164, Angela Schrute's
// `Lumen/Core/OwnDeck/`): when the sheet that points there comes up, the words (Kelly's Ke89,
// `docs/design/spela-in-sjalv.md`), and what is tidied away when the deck's screen is closed.

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

// MARK: The deck's screen

extension OwnCard {
    /// Nothing written and nothing read in.
    var isBlank: Bool { !has(.question) && !has(.answer) }
}

/// The screen of a deck opens straight from the way in (Ke89 §2), so a deck and a first card exist before anything
/// is written. What was never filled in is taken away when the screen closes.
@MainActor
enum OwnDeckTidy {
    /// A new deck with its first, empty card, ready to be written in.
    static func newDeck(in decks: OwnDeckModel) -> OwnDeck {
        let deck = decks.addDeck(title: OwnDeckText.defaultTitle)
        decks.addCard(to: deck.id)
        return decks.deck(deck.id) ?? deck
    }

    /// The blank cards go. A deck that then has no card and was never named goes too. True when the deck is left.
    @discardableResult
    static func afterEditing(_ deckID: UUID, in decks: OwnDeckModel) -> Bool {
        guard let deck = decks.deck(deckID) else { return false }
        for card in deck.cards where card.isBlank { decks.deleteCard(card.id, in: deckID) }
        guard let left = decks.deck(deckID) else { return false }
        if left.cards.isEmpty, OwnDeckText.isDefaultTitle(left.title) {
            decks.delete(deckID)
            return false
        }
        return true
    }

    /// What the name field shows for a title: nothing for the name a deck is born with (the placeholder shows).
    static func shownName(_ title: String) -> String {
        OwnDeckText.isDefaultTitle(title) ? "" : title
    }

    /// The title that is saved for what stands in the name field.
    static func title(forName name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? OwnDeckText.defaultTitle : String(trimmed.prefix(OwnDeck.titleLimit))
    }
}

// MARK: The words (Ke89 §5)

enum OwnDeckText {
    static var title: String { String(localized: "Spela in själv") }
    static var free: String { String(localized: "Helt gratis") }
    /// The way in where it stands as one line (Start without a quiz), and for VoiceOver.
    static var entry: String { String(localized: "Spela in själv – helt gratis") }
    static var entryLine: String { String(localized: "Skriv frågor och svar och läs in dem med din röst.") }

    /// A deck's line among the quizzes on Start: "Egen inspelning · 5 frågor".
    static func deckLine(cards: Int) -> String { String(localized: "Egen inspelning · \(DrillText.questions(cards))") }
    static var ownRecording: String { String(localized: "Egen inspelning") }

    /// The name of a deck that has not been named. Both languages count as "not named".
    static var defaultTitle: String { String(localized: "Mina frågor") }
    static func isDefaultTitle(_ title: String) -> Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || trimmed == "Mina frågor" || trimmed == "My questions"
    }

    static var name: String { String(localized: "Namn") }
    static var namePrompt: String { String(localized: "T.ex. Glosor vecka 12") }
    static func field(_ part: OwnPart) -> String {
        part == .question ? String(localized: "Fråga") : String(localized: "Svar")
    }
    /// A167, VoiceOver: which card the field belongs to ("Fråga 2").
    static func field(_ part: OwnPart, number: Int) -> String {
        part == .question ? String(localized: "Fråga \(number)") : String(localized: "Svar \(number)")
    }
    static var record: String { String(localized: "Spela in") }
    static var recordAgain: String { String(localized: "Spela in igen") }
    static var notRecorded: String { String(localized: "Inte inspelad") }
    /// Kelly (2026-11-26): a text that is not read in is read by the phone's voice when practising, and the row
    /// says so before Öva. Without a text there is nothing to read.
    static func notRecorded(hasText: Bool) -> String {
        hasText ? String(localized: "Inte inspelad · läses av telefonen") : notRecorded
    }
    static var stop: String { String(localized: "Stoppa") }
    static var addCard: String { String(localized: "Lägg till fråga") }
    static var delete: String { String(localized: "Ta bort") }
    static var practise: String { String(localized: "Öva") }
    static var staysOnPhone: String { String(localized: "Helt gratis. Ljudet stannar på din telefon.") }
    static var micNote: String { String(localized: "Mikrofonen används bara medan du spelar in.") }

    // VoiceOver
    static func recordLabel(_ part: OwnPart) -> String {
        part == .question ? String(localized: "Spela in frågan") : String(localized: "Spela in svaret")
    }
    static func recordAgainLabel(_ part: OwnPart) -> String {
        part == .question ? String(localized: "Spela in frågan igen") : String(localized: "Spela in svaret igen")
    }
    static func playLabel(_ part: OwnPart, seconds: Double) -> String {
        let whole = max(1, Int(seconds.rounded()))
        return part == .question ? String(localized: "Spela upp frågan, \(whole) sekunder") : String(localized: "Spela upp svaret, \(whole) sekunder")
    }
    static var stopRecording: String { String(localized: "Stoppa inspelningen") }
    static func seconds(_ elapsed: TimeInterval) -> String {
        let whole = max(0, Int(elapsed.rounded()))
        return whole == 1 ? String(localized: "1 sekund") : String(localized: "\(whole) sekunder")
    }
    /// A167: the recording said, not only shown.
    static func nowRecording(_ part: OwnPart) -> String {
        part == .question ? String(localized: "Spelar in frågan") : String(localized: "Spelar in svaret")
    }
    static func doneRecording(_ part: OwnPart) -> String {
        part == .question ? String(localized: "Klar, frågan är inspelad") : String(localized: "Klar, svaret är inspelat")
    }

    static func clock(_ seconds: TimeInterval) -> String {
        let whole = max(0, Int(seconds.rounded()))
        return "\(whole / 60):" + String(format: "%02d", whole % 60)
    }

    // The sheet (Ke89 §4)
    static func offerTitle(_ reason: OwnDeckOffer.Reason) -> String {
        reason == .credits ? String(localized: "Slut på krediter?") : String(localized: "Kan inte skapa prov just nu?")
    }
    static var offerLine: String { String(localized: "Spela in dina egna frågor och svar – helt gratis.") }
    static var notNow: String { String(localized: "Inte nu") }
}
