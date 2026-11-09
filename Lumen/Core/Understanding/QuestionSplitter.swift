import Foundation

/// A8.4: one utterance can hold several questions and an instruction when the speaker pauses only briefly between
/// them ("vilka är de största bergen i världen fortsätt att du i framtiden bara ska ge korta svar vad är 250 gånger
/// 250"). Each part becomes its own turn with its own answer. Pure and unit-tested.
///
/// A new part starts at a sentence end (`?`, `!`, `.`), before a question word that opens a new question, or before
/// a cue that opens a standing request ("i framtiden", "från och med nu", "kom ihåg att", …). A question word right
/// after a verb that takes an indirect question ("förklara hur", "vet du vad", "undrar varför") or a conjunction
/// does not split, and no part shorter than `minimumWords` is cut off.
enum QuestionSplitter {
    static let minimumWords = 3

    /// Words after which a question word belongs to the same sentence.
    private static let embedding: Set<String> = [
        "förklara", "berätta", "beskriv", "visa", "säg", "säger", "sa", "sade", "vet", "veta", "visste", "undrar", "undra",
        "fråga", "frågar", "frågade", "förstår", "förstå", "förstod", "tänker", "tänk", "minns", "kolla", "spelar", "oavsett",
        "och", "eller", "att", "om", "men", "så", "då", "för", "precis", "ungefär", "exakt", "typ", "ser", "se", "hör",
        "explain", "tell", "describe", "show", "know", "knew", "wonder", "ask", "asked", "understand", "see", "remember",
        "and", "or", "that", "if", "but", "so", "me", "mig", "dig", "du", "ni", "you", "matter", "exactly", "just", "som",
    ]
    /// Question words that are as often a conjunction or a relative ("var" = was, "när" = when, "vilket" = which)
    /// never open a new part in the middle of an utterance.
    private static let ambiguous: Set<String> = ["var", "när", "vilket", "when", "where", "which", "whose", "whom"]
    /// A question word followed by one of these is not the start of a question ("vad som helst", "när som helst").
    private static let notAStartAfter: Set<String> = ["som", "ever"]

    /// Cue phrases that open a standing request or an instruction (K9 makes them rules in Frågor and Provläge).
    private static let requestCues: [[String]] = [
        ["i", "framtiden"], ["från", "och", "med", "nu"], ["kom", "ihåg", "att"], ["svara", "alltid"],
        ["fortsätt", "att"], ["från", "nu", "på"], ["in", "the", "future"], ["from", "now", "on"], ["always", "answer"],
    ]

    static func split(_ text: String) -> [String] {
        let words = text.split(whereSeparator: \.isWhitespace).map(String.init)
        guard words.count >= minimumWords * 2 else { return [text.trimmingCharacters(in: .whitespacesAndNewlines)] }
        var parts: [[String]] = []
        var current: [String] = []
        /// The current part is a standing request: a second cue inside it ("fortsätt att du i framtiden") stays.
        var currentIsRequest = false

        func normalized(_ word: String) -> String {
            word.lowercased().trimmingCharacters(in: .punctuationCharacters)
        }

        var index = 0
        while index < words.count {
            let word = words[index]
            let remaining = words.count - index
            if current.count >= minimumWords, remaining >= minimumWords - 1,
               let start = startsAPart(at: index, words: words, normalized: normalized),
               !(start == .request && currentIsRequest) {
                parts.append(current)
                current = []
                currentIsRequest = start == .request
            } else if current.isEmpty, isRequestCue(at: index, words: words, normalized: normalized) {
                currentIsRequest = true
            }
            current.append(word)
            // A sentence end closes the part, if what follows is long enough to be a part of its own.
            if let last = word.last, "?!.".contains(last), current.count >= minimumWords - 1, words.count - index - 1 >= minimumWords - 1 {
                parts.append(current)
                current = []
                currentIsRequest = false
            }
            index += 1
        }
        if !current.isEmpty {
            if current.count < minimumWords - 1, !parts.isEmpty {
                parts[parts.count - 1] += current
            } else {
                parts.append(current)
            }
        }
        return parts.map { $0.joined(separator: " ") }.filter { !$0.isEmpty }
    }

    private enum Start { case question, request }

    private static func isRequestCue(at index: Int, words: [String], normalized: (String) -> String) -> Bool {
        requestCues.contains { cue in
            index + cue.count <= words.count && (0..<cue.count).allSatisfy { normalized(words[index + $0]) == cue[$0] }
        }
    }

    private static func startsAPart(at index: Int, words: [String], normalized: (String) -> String) -> Start? {
        guard index > 0 else { return nil }
        let word = normalized(words[index])
        let previous = normalized(words[index - 1])
        if isRequestCue(at: index, words: words, normalized: normalized) { return .request }
        guard QuestionGate.interrogativeWords.contains(word), !ambiguous.contains(word), !embedding.contains(previous) else { return nil }
        if index + 1 < words.count, notAStartAfter.contains(normalized(words[index + 1])) { return nil }
        // A question word right after another ("vad vem") is one opening, not two.
        if QuestionGate.interrogativeWords.contains(previous) { return nil }
        // The new part must look like a question on its own.
        let rest = words[index...].joined(separator: " ")
        return QuestionGate().evaluate(rest).signals.contains(.interrogativeStart) ? .question : nil
    }
}
