import Foundation

/// Picks the vocabulary of pasted/imported study material (item 9): frequent content words plus capitalised
/// names (and two-word names), minus stopwords. On device, no model. Pure; unit-tested.
struct KeyTermExtractor: Sendable {
    static let stopwordsSwedish: Set<String> = [
        "och", "att", "det", "som", "en", "ett", "är", "på", "för", "med", "av", "till", "i", "den", "de", "dem", "har", "inte",
        "om", "kan", "var", "vad", "man", "så", "men", "från", "eller", "vi", "du", "jag", "han", "hon", "hur", "när", "också",
        "där", "här", "ska", "skulle", "blir", "blev", "vara", "varit", "mycket", "mer", "mest", "alla", "andra", "under", "över",
        "efter", "före", "mellan", "genom", "utan", "sin", "sitt", "sina", "dess", "denna", "detta", "dessa", "vilket", "vilka",
        "vilken", "sedan", "bara", "även", "både", "någon", "något", "några", "ingen", "inget", "inga", "kommer", "finns", "får",
        "göra", "gör", "gjorde", "sade", "sa", "säger", "alltså", "därför", "eftersom", "medan", "hade", "hos", "mot", "än", "nu",
        "då", "ju", "väl", "ofta", "igen", "samma", "två", "tre", "första", "andra", "år", "kallas", "heter", "många", "stor",
        "stora", "liten", "små", "nya", "gamla", "hela", "varje", "mig", "dig", "oss", "er", "sig", "min", "din", "vår", "deras",
        "hans", "hennes", "upp", "ner", "in", "ut", "vid", "åt", "per", "ha", "bli", "vill", "måste", "kunde", "borde", "annat",
    ]
    static let stopwordsEnglish: Set<String> = [
        "the", "a", "an", "and", "or", "but", "of", "to", "in", "on", "at", "for", "with", "by", "from", "as", "is", "are",
        "was", "were", "be", "been", "being", "it", "its", "this", "that", "these", "those", "there", "here", "which", "who",
        "whom", "what", "when", "where", "why", "how", "not", "no", "yes", "we", "you", "they", "he", "she", "i", "me", "my",
        "our", "your", "their", "his", "her", "them", "us", "can", "could", "will", "would", "should", "may", "might", "must",
        "do", "does", "did", "have", "has", "had", "than", "then", "so", "if", "into", "about", "over", "under", "between",
        "through", "also", "very", "more", "most", "some", "any", "all", "each", "other", "such", "only", "just", "like",
        "because", "while", "after", "before", "during", "up", "down", "out", "off", "again", "one", "two", "three", "first",
        "new", "called", "many", "much", "often", "same", "own", "both", "either", "neither", "well",
    ]

    var minimumLength = 3

    init() {}

    /// Terms ordered by importance: score = frequency + 2 × capitalised occurrences (not sentence-initial);
    /// a capitalised word followed by another capitalised word is a two-word name scoring 4 per occurrence.
    func extract(from text: String, limit: Int = 100) -> [String] {
        struct Entry {
            var score = 0
            var display: String
            var capitalised = 0
        }
        var entries: [String: Entry] = [:]

        for sentence in Self.sentences(text) {
            let words = Self.words(sentence)
            var previousCapitalised: (lower: String, display: String)?
            for (index, word) in words.enumerated() {
                let lower = word.lowercased()
                let capitalised = word.first?.isUppercase == true
                let isName = index > 0 && capitalised
                let usable = lower.count >= minimumLength && !Self.isStopword(lower) && !lower.allSatisfy(\.isNumber)
                defer { previousCapitalised = (capitalised && usable) ? (lower, word) : nil }
                guard usable else { continue }

                var entry = entries[lower] ?? Entry(display: lower)
                entry.score += 1
                if isName {
                    entry.capitalised += 1
                    entry.score += 2
                    entry.display = word
                }
                entries[lower] = entry

                if isName, let previous = previousCapitalised {
                    let key = "\(previous.lower) \(lower)"
                    var pair = entries[key] ?? Entry(display: "\(previous.display) \(word)")
                    pair.score += 4
                    pair.capitalised += 1
                    entries[key] = pair
                }
            }
        }

        return entries
            .sorted { lhs, rhs in
                if lhs.value.score != rhs.value.score { return lhs.value.score > rhs.value.score }
                return lhs.key < rhs.key
            }
            .prefix(limit)
            .map(\.value.display)
    }

    static func isStopword(_ lower: String) -> Bool {
        stopwordsSwedish.contains(lower) || stopwordsEnglish.contains(lower)
    }

    static func sentences(_ text: String) -> [String] {
        text.split(whereSeparator: { ".!?\n\r".contains($0) }).map(String.init)
    }

    /// Words keep letters, digits and inner hyphens ("ph-värde"); everything else separates.
    static func words(_ sentence: String) -> [String] {
        sentence
            .split(whereSeparator: { !($0.isLetter || $0.isNumber || $0 == "-") })
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "-")) }
            .filter { !$0.isEmpty }
    }
}
