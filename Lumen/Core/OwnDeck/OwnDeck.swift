import Foundation

/// A164 (D263): "Spela in själv – helt gratis". The user's own collection: questions and answers they write, and for
/// each question and each answer an own recording if they want one. It lives on the phone only: no server, no model,
/// no ElevenLabs, no credits. It is practised through the same player as a saved exam.

/// The two things a card has.
enum OwnPart: String, Codable, Sendable, CaseIterable {
    case question, answer
}

/// A recording the user made: its file in the recordings folder (`OwnDeckStore.audioFolder`) and how long it is.
struct OwnRecordingFile: Codable, Equatable, Sendable {
    var name: String
    var seconds: Double
}

struct OwnCard: Codable, Identifiable, Equatable, Sendable {
    /// A question or an answer is a few sentences, not a chapter.
    static let textLimit = 1000

    var id: UUID = UUID()
    var question: String = ""
    var answer: String = ""
    /// Nil: the phone's own voice reads the text.
    var questionRecording: OwnRecordingFile?
    var answerRecording: OwnRecordingFile?

    func text(_ part: OwnPart) -> String {
        switch part {
        case .question: question
        case .answer: answer
        }
    }

    func recording(_ part: OwnPart) -> OwnRecordingFile? {
        switch part {
        case .question: questionRecording
        case .answer: answerRecording
        }
    }

    /// There is something to play for this part: a recording, or a text for the phone's voice.
    func has(_ part: OwnPart) -> Bool {
        recording(part) != nil || !text(part).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// A card can be practised when it has both a question and an answer.
    var isPlayable: Bool { has(.question) && has(.answer) }

    /// Kelly (Ke89 §2): a card counts as recorded when its question is.
    var isRecorded: Bool { questionRecording != nil }
}

struct OwnDeck: Codable, Identifiable, Equatable, Sendable {
    static let titleLimit = 60
    static let cardLimit = 200

    var id: UUID = UUID()
    var title: String
    var cards: [OwnCard] = []
    /// `sv` | `en`: the phone's voice for a text without a recording. The app's language when the deck was made.
    var language: String
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    /// What is kept of a typed name: no line breaks, no spaces at the ends, at most `titleLimit` characters.
    static func cleanedTitle(_ typed: String) -> String {
        let oneLine = typed.split(whereSeparator: \.isNewline).joined(separator: " ")
        return String(oneLine.trimmingCharacters(in: .whitespaces).prefix(titleLimit))
    }

    /// The name that is shown and that the lock screen gets: the user's, or "Egen inspelning" when there is none.
    var shownTitle: String {
        title.isEmpty ? String(localized: "Egen inspelning") : title
    }

    /// The cards that can be practised, in order. `onlyRecorded` (Kelly, Ke89 §2): only those whose question the
    /// user has recorded; otherwise the phone's voice reads what is not recorded.
    func playable(onlyRecorded: Bool = false) -> [OwnCard] {
        cards.filter { $0.isPlayable && (!onlyRecorded || $0.isRecorded) }
    }

    var playableCards: [OwnCard] { playable() }

    /// What the player gets: an exam that only exists while it plays. It has the deck's id, one item per playable
    /// card, and the answer as both the short and the long answer (there is one answer). It is never saved in the
    /// exam store, so nothing of it can be sent to the server.
    func drill(onlyRecorded: Bool = false) -> Drill {
        var drill = Drill(title: shownTitle, summary: DrillSummary(subject: "", grade: "", covers: ""),
                          items: playable(onlyRecorded: onlyRecorded).map { card in
                              DrillItem(id: card.id, question: card.question, short: card.answer, long: card.answer)
                          })
        drill.id = id
        drill.createdAt = createdAt
        return drill
    }
}
