import Foundation

/// A21.2 (Toby T5 finding 2): a short utterance that stops in the middle of a thought ("Vilka är de största?",
/// "Vad är skillnaden mellan ett virus") is not answered ahead and waits a little longer than the pause, so that the
/// rest of the question ("… bergen i världen?") can still come. Scribe often puts a "?" after the first half.
///
/// Deliberately narrow: a complete question that matches only waits `hold` longer, but a half question that is
/// answered loses the question (D82 closes the recogniser while Lumen speaks). Swedish questions often end on a
/// stranded preposition ("Vad handlar boken om?", "Var kommer du från?"), so prepositions never count.
enum UnfinishedQuestion {
    /// Extra wait after the pause (Frågor: from the final; Provläge: added to the turn's endpoint silence).
    static let hold: TimeInterval = 3.0
    /// Longer utterances are rarely cut in half by a breath; they are never held.
    static let maxWords = 8

    /// Words a finished sentence practically never ends on: articles and conjunctions.
    static let dangling: Set<String> = [
        "en", "ett", "och", "eller", "men", "att", "som", "samt", "både",
        "a", "an", "the", "and", "or", "but", "between",
    ]

    static func looksUnfinished(_ text: String) -> Bool {
        let words = text.lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
        guard words.count >= 2, words.count <= maxWords, let last = words.last else { return false }
        if dangling.contains(last) { return true }
        // "skillnaden mellan ett virus" (… "och en bakterie"): "mellan" without "och" after it.
        if let index = words.lastIndex(where: { $0 == "mellan" || $0 == "between" }) {
            let rest = words[(index + 1)...]
            if !rest.contains("och"), !rest.contains("and") { return true }
        }
        // "de största", "den bästa", "the biggest": a determiner and a superlative with no noun after it.
        let determiner = words[words.count - 2]
        if ["de", "den", "det", "the"].contains(determiner), isSuperlative(last) { return true }
        return false
    }

    static func isSuperlative(_ word: String) -> Bool {
        guard word.count >= 4 else { return false }
        if ["bästa", "största", "minsta", "högsta", "längsta", "äldsta", "yngsta", "sämsta",
            "most", "best", "worst", "oldest"].contains(word) {
            return true
        }
        // "biggest", "largest"; not "forest" or "interest" (too short / not after "the" in a question).
        return word.hasSuffix("aste") || word.hasSuffix("asta") || (word.hasSuffix("gest") && word.count >= 7)
    }
}
