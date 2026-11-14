import Foundation

/// A17 (owner 2026-11-09): "igen" gives exactly the same answer again, but only when it is meant for Lumen.
/// - Only the wearer's voice counts (D81). Someone else saying "igen" does nothing.
/// - "Igen" as the whole utterance (also "en gång till", "va?", "hörde inte"), with or without "Lumen": repeat if
///   Lumen answered at most 15 minutes ago.
/// - "Igen" inside an utterance with noise or other words (on the underground): repeat only if Lumen answered at most
///   45 s ago and "igen" is the last clear word. Otherwise it is not about Lumen.
/// Pure and unit-tested.
enum AgainRule {
    static let wholeWindow: TimeInterval = 15 * 60
    static let insideWindow: TimeInterval = 45

    private static let whole: Set<String> = [
        "igen", "en gång till", "en gång till tack", "igen tack", "säg igen", "säg det igen", "va", "vad", "förlåt",
        "hörde inte", "jag hörde inte", "jag hörde inte det", "hörde inte vad du sa", "kan du ta det igen", "ta det igen",
        "again", "say again", "pardon", "what", "sorry", "i didnt hear",
    ]
    /// Words Scribe writes for noise or fillers, skipped when looking for the last clear word.
    private static let fillers: Set<String> = ["eh", "äh", "öh", "hm", "mm", "ja", "nej", "okej", "alltså", "typ", "liksom", "asså"]

    enum Verdict: Equatable, Sendable {
        case repeatAnswer
        case notForLumen
    }

    /// `isOtherVoice`: the voice profile says someone else spoke (nil: unknown, counts as the wearer).
    static func judge(_ text: String, lastAnswerAt: Date?, now: Date, isOtherVoice: Bool?) -> Verdict? {
        var words = VoiceChannel.normalized(text)
        // A97: either name.
        for name in WakeWord.names.map({ $0.lowercased() }) {
            if words == name { return nil }
            if words.hasPrefix(name + " ") { words = String(words.dropFirst(name.count + 1)) }
        }
        let tokens = words.split(separator: " ").map(String.init)
        let isWhole = whole.contains(words)
        let lastClear = tokens.last { !fillers.contains($0) }
        let endsWithAgain = lastClear == "igen" || lastClear == "again"
        guard isWhole || endsWithAgain else { return nil }
        if isOtherVoice == true { return .notForLumen }
        guard let lastAnswerAt else { return .notForLumen }
        let age = now.timeIntervalSince(lastAnswerAt)
        if isWhole { return age <= wholeWindow ? .repeatAnswer : .notForLumen }
        return age <= insideWindow ? .repeatAnswer : .notForLumen
    }
}
