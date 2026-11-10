import Foundation

/// A20.2 (owner-approved): "Tyst förhör" in Provläge, for the bus or the library. Lumen asks yes/no questions and the
/// student answers with a nod or a shake (D86 head tracking), without speaking. A clear start ("Tyst förhör. Nicka
/// för ja, skaka för nej.") and end ("Tyst förhör klart. 4 av 5 rätt."). The voice still works: "ja" / "nej" answer
/// too, and "Lumen, sluta" ends the quiz (a second one ends Provläge).
struct SilentQuiz: Equatable, Sendable {
    /// A full round, then the summary.
    static let questions = 10
    /// How long a nod or a shake is waited for after a question.
    static let answerWindow: TimeInterval = 10
    /// No gesture this many times in a row: the student has stopped; the quiz ends.
    static let missesToEnd = 2

    private(set) var asked = 0
    private(set) var correct = 0
    private(set) var graded = 0
    private(set) var missesInARow = 0
    /// A question was spoken and waits for a nod or a shake.
    private(set) var awaitingAnswer = false

    /// The request that asks the next question (a level-2 task in Provläge, `docs/COMMANDS.md`).
    static let questionRequest = "Tyst förhör: ställ en ja-eller-nej-fråga om det jag pluggar. Bara frågan. "
        + "När jag har svarat: säg först Rätt eller Fel och en kort mening om varför, sedan nästa ja-eller-nej-fråga."

    static let startLine = "Tyst förhör. Nicka för ja, skaka på huvudet för nej. Säg Lumen, sluta när du vill sluta."
    static let noHeadTrackingLine = "Dina AirPods känner inte av huvudrörelser. Svara ja eller nej med rösten."
    static let nudgeLine = "Nicka för ja eller skaka för nej."

    static func isStartCommand(_ text: String) -> Bool {
        let key = text.lowercased().split(whereSeparator: { !$0.isLetter }).filter { $0 != "lumen" }.joined(separator: " ")
        return ["tyst förhör", "tyst förhör mig", "förhör mig tyst", "starta tyst förhör", "förhör mig utan att jag pratar"].contains(key)
    }

    var isFinished: Bool { asked >= Self.questions || missesInARow >= Self.missesToEnd }

    /// An answer from Lumen arrived. A question ends with "?"; it now waits for a gesture. A line that starts with
    /// "Rätt" / "Fel" grades the last answer.
    mutating func lumenSaid(_ answer: String) {
        let text = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        if let verdict = Self.verdict(text) {
            graded += 1
            if verdict { correct += 1 }
        }
        if text.hasSuffix("?") {
            asked += 1
            awaitingAnswer = true
        }
    }

    /// A nod, a shake or a spoken ja/nej answered the waiting question.
    mutating func answered() {
        awaitingAnswer = false
        missesInARow = 0
    }

    /// No answer within the window.
    mutating func missed() {
        missesInARow += 1
    }

    /// True = correct, false = wrong, nil = not a grade.
    static func verdict(_ text: String) -> Bool? {
        let first = text.lowercased().split(whereSeparator: { !$0.isLetter }).prefix(2).map(String.init)
        guard let word = first.first else { return nil }
        if ["rätt", "precis", "korrekt", "exakt", "stämmer", "right", "correct"].contains(word) { return true }
        if ["fel", "wrong", "incorrect"].contains(word) { return false }
        if first == ["inte", "riktigt"] || first == ["tyvärr", "inte"] || first == ["not", "quite"] { return false }
        return nil
    }

    /// "Tyst förhör klart. 4 av 5 rätt." (or without a score when nothing was graded).
    var summary: String {
        guard graded > 0 else { return "Tyst förhör klart." }
        return "Tyst förhör klart. \(correct) av \(graded) rätt."
    }
}
