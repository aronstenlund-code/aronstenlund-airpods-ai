import Foundation

/// D82: the app heard itself on the iPhone. Its own previous answer ("Du sätter in ett i formeln, gångrar med fem…")
/// came back as input and was answered. A transcript is Lumen's own echo when most of its words (≥ 60 %) are in
/// something Lumen said in the last 30 s. Pure; unit-tested.
struct EchoFilter: Sendable {
    static let window: TimeInterval = 30
    static let overlap = 0.6
    /// Fewer words than this are too short to judge ("ja", "okej").
    static let minimumWords = 3

    private var spoken: [(words: Set<String>, at: Date)] = []

    mutating func record(_ text: String, at date: Date) {
        let words = Set(Self.words(text))
        guard !words.isEmpty else { return }
        spoken.append((words, date))
        spoken.removeAll { date.timeIntervalSince($0.at) > Self.window }
    }

    /// Share of the transcript's words that Lumen just said, or nil when there is nothing to compare.
    func overlap(_ text: String, now: Date) -> Double? {
        let all = Self.words(text)
        guard all.count >= Self.minimumWords else { return nil }
        // Toby 1 T17 finding 4: "Och en bakterie." was 100 % Lumen's words because the answer had said "och", "en"
        // and "bakterie". Only content words count, and one content word is too little to judge.
        let heard = all.filter { !Self.functionWords.contains($0) }
        guard heard.count >= Self.minimumContentWords else { return nil }
        let recent = spoken.filter { now.timeIntervalSince($0.at) <= Self.window }
        guard !recent.isEmpty else { return nil }
        let said = recent.reduce(into: Set<String>()) { $0.formUnion($1.words) }
        let matching = heard.filter { said.contains($0) }.count
        return Double(matching) / Double(heard.count)
    }

    static let minimumContentWords = 2

    /// Small words every Swedish sentence has; they say nothing about whose voice it was.
    static let functionWords: Set<String> = [
        "och", "eller", "men", "så", "att", "som", "en", "ett", "den", "det", "de", "dem", "i", "på", "av", "till",
        "för", "med", "om", "från", "är", "var", "har", "hade", "kan", "ska", "jag", "du", "han", "hon", "vi", "ni",
        "sig", "sin", "sitt", "sina", "inte", "också", "när", "då", "där", "vad", "hur", "vilka", "vilken", "vilket",
        "the", "a", "an", "and", "of", "is",
    ]

    /// A28 (Oscar O30): Lumen's own voice can only come back while it speaks or just after (the room's tail and the
    /// recogniser's last words). What the wearer starts saying later is the wearer, even when it quotes the answer
    /// ("så fotosyntesen omvandlar ljusenergi till kemisk energi?", "vad menar du med i form av glukos").
    static let tail: TimeInterval = 1.5

    static func mayBeEcho(startedAt: Date, speaking: Bool, overlapsPlayback: Bool, lastSpeechEnd: Date?) -> Bool {
        if speaking || overlapsPlayback { return true }
        guard let lastSpeechEnd else { return false }
        return startedAt <= lastSpeechEnd.addingTimeInterval(tail)
    }

    func isEcho(_ text: String, now: Date) -> Bool {
        (overlap(text, now: now) ?? 0) >= Self.overlap
    }

    static func words(_ text: String) -> [String] {
        text.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
    }
}
