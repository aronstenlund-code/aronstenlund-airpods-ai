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
        let heard = Self.words(text)
        guard heard.count >= Self.minimumWords else { return nil }
        let recent = spoken.filter { now.timeIntervalSince($0.at) <= Self.window }
        guard !recent.isEmpty else { return nil }
        let said = recent.reduce(into: Set<String>()) { $0.formUnion($1.words) }
        let matching = heard.filter { said.contains($0) }.count
        return Double(matching) / Double(heard.count)
    }

    func isEcho(_ text: String, now: Date) -> Bool {
        (overlap(text, now: now) ?? 0) >= Self.overlap
    }

    static func words(_ text: String) -> [String] {
        text.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
    }
}
