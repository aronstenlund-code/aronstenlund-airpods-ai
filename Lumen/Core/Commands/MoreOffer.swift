import Foundation

/// A15: after a short answer, a 5 s window where "ja", "mer", "utveckla", "gärna", a nod or an AirPods press gets the
/// developed answer. Lumen does not ask "vill du ha mer?"; a soft tone and "Säg ja för mer" on the screen say the
/// window is open. "Nej", silence or a new question close it. Pure parts, unit-tested.
enum MoreOffer {
    static let window: TimeInterval = 5
    /// A56 (K13): how long the developed answer from the same call is kept for "ja" (COMMANDS.md: about 2 minutes).
    static let cacheLife: TimeInterval = 120
    /// What the long answer is asked for with until Kevin's K13 cache lands (`continue_more`, existing).
    static let instruction = "utveckla"

    private static let yes: Set<String> = [
        "ja", "jaa", "ja tack", "ja gärna", "gärna", "mer", "mer tack", "ja mer", "utveckla", "utveckla gärna", "berätta mer",
        "yes", "yes please", "more", "sure",
    ]
    private static let no: Set<String> = ["nej", "nej tack", "nä", "nää", "no", "no thanks", "det räcker", "räcker"]

    /// true: more; false: no; nil: something else (a new question closes the window too).
    static func verdict(_ text: String) -> Bool? {
        var words = VoiceChannel.normalized(text)
        let name = WakeWord.name.lowercased()
        if words.hasPrefix(name + " ") { words = String(words.dropFirst(name.count + 1)) }
        if yes.contains(words) { return true }
        if no.contains(words) { return false }
        return nil
    }

    /// Short enough to offer more: at most two sentences and 40 words, and not a question back to the user (a
    /// Provläge check question is answered with "ja" itself, D83).
    static func isShort(_ answer: String) -> Bool {
        let trimmed = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.hasSuffix("?") else { return false }
        let words = trimmed.split(whereSeparator: \.isWhitespace).count
        let sentences = trimmed.split(whereSeparator: { ".!?".contains($0) }).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count
        return words <= 40 && sentences <= 2
    }
}
