import Foundation

/// A74 (Aron's phone test 18:58): the same question was answered twice, sent again when Scribe handed over late words.
/// A question that is the same or nearly the same as one asked in the last `window` is not sent again, unless the user
/// asks for it ("igen", "upprepa", "en gång till"). Pure, unit-tested.
struct RepeatGuard: Sendable {
    static let window: TimeInterval = 60
    /// Share of content words in common (Jaccard) from which two questions count as the same.
    static let sameShare = 0.8

    private(set) var recent: [(key: Set<String>, text: String, at: Date)] = []

    mutating func record(_ query: String, at date: Date) {
        let key = Self.contentWords(query)
        guard !key.isEmpty else { return }
        recent.removeAll { date.timeIntervalSince($0.at) > Self.window }
        recent.append((key, query, date))
    }

    /// The earlier question this one repeats, or nil.
    func repeats(_ query: String, at date: Date) -> String? {
        let lowered = query.lowercased()
        if ["igen", "upprepa", "en gång till", "again", "repeat"].contains(where: { lowered.contains($0) }) { return nil }
        let key = Self.contentWords(query)
        guard key.count >= 2 else { return nil } // "ja", "Nilen": short answers may well come twice
        for earlier in recent.reversed() where date.timeIntervalSince(earlier.at) <= Self.window {
            // Toby 1 T17 finding 3: a half question cut in a word ("… Barnen är-") is replaced by its longer version,
            // which is the question at last, not a copy.
            if Self.isCut(earlier.text), earlier.key.isSubset(of: key) { continue }
            let shared = Double(key.intersection(earlier.key).count)
            let all = Double(key.union(earlier.key).count)
            if all > 0, shared / all >= Self.sameShare { return earlier.text }
        }
        return nil
    }

    private static let stop: Set<String> = [
        "lumen", "vad", "vilka", "vilken", "vilket", "hur", "när", "var", "vem", "varför", "är", "var", "den", "det", "de",
        "en", "ett", "i", "på", "av", "till", "för", "med", "om", "och", "som", "att", "har", "kan", "du", "jag", "mig",
        "säg", "berätta", "förklara", "the", "a", "an", "is", "what", "how", "of",
    ]

    /// A question that stopped in the middle of a word or a sentence ("är-", "…").
    static func isCut(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return ["-", "–", "…", "..."].contains { trimmed.hasSuffix($0) }
    }

    static func contentWords(_ text: String) -> Set<String> {
        let words = text.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
        return Set(words.filter { !stop.contains($0) })
    }
}
