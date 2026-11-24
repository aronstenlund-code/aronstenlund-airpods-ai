import Foundation

/// A162 (D259): the user's own activation words. The screen says "Fråga du inte är beredd på? Säg [ … ] så aktiveras
/// vår AI." with a field where the user writes one or more words. When those words are heard while the app listens,
/// the question that was just asked is answered as usual; the words themselves are never sent as a question. An
/// empty field is off. Pure: nothing here listens or sends, it only reads text that was already heard.
enum ActivationPhrase {
    /// A few words, not a sentence.
    static let limit = 40

    /// What is kept of what was typed: no line breaks, single spaces, no spaces at the ends, at most `limit` characters.
    static func cleaned(_ typed: String) -> String {
        let words = typed.split(whereSeparator: { $0.isWhitespace || $0.isNewline })
        return String(words.joined(separator: " ").prefix(limit)).trimmingCharacters(in: .whitespaces)
    }

    /// The words of a text as they are compared: letters and digits only, lower case. "Banan!" and "banan" are the
    /// same word; "banan" and "bananer" are not.
    static func words(_ text: String) -> [String] {
        pieces(text).map(\.word)
    }

    /// A turn with the user's words in it: what was said before them and after them.
    struct Match: Equatable, Sendable {
        var before: String
        var after: String
    }

    /// Where the words are heard in a turn, as whole words in the same order next to each other, whatever the case
    /// and the punctuation. The last place counts: the words come after the question. Nil when they are not there,
    /// or when the field is empty.
    static func match(_ phrase: String, in heard: String) -> Match? {
        let wanted = words(phrase)
        let spoken = pieces(heard)
        guard !wanted.isEmpty, spoken.count >= wanted.count else { return nil }
        for start in stride(from: spoken.count - wanted.count, through: 0, by: -1)
        where zip(wanted, spoken[start...]).allSatisfy({ $0 == $1.word }) {
            let first = spoken[start].range.lowerBound
            let last = spoken[start + wanted.count - 1].range.upperBound
            let edge = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ",;:-–—"))
            return Match(before: heard[..<first].trimmingCharacters(in: edge),
                         after: heard[last...].trimmingCharacters(in: edge.union(CharacterSet(charactersIn: ".!"))))
        }
        return nil
    }

    /// The question the words ask for: what was said just before them in the same turn; else what follows them;
    /// else the last thing heard before this turn (`earlier`, oldest first). One word alone is no question.
    static func question(for match: Match, earlier: [String]) -> String? {
        if words(match.before).count >= 2 { return match.before }
        if words(match.after).count >= 2 { return match.after }
        return earlier.last { words($0).count >= 2 }
    }

    private static func pieces(_ text: String) -> [(word: String, range: Range<String.Index>)] {
        var found: [(word: String, range: Range<String.Index>)] = []
        var start: String.Index?
        var index = text.startIndex
        while index < text.endIndex {
            let character = text[index]
            let inWord = character.isLetter || character.isNumber
            if inWord, start == nil { start = index }
            if !inWord, let from = start {
                found.append((text[from..<index].lowercased(), from..<index))
                start = nil
            }
            index = text.index(after: index)
        }
        if let from = start { found.append((text[from...].lowercased(), from..<text.endIndex)) }
        return found
    }
}
