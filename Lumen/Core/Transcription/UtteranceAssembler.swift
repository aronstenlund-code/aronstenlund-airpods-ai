import Foundation

/// Joins speech-to-text finals into whole utterances before the question gate and the backend see them (D78).
/// Scribe commits at every short pause, so one sentence arrived as "Det är en annan ." and "Ja, obrutet." on the
/// iPhone. A question or exclamation mark ends an utterance at once, a period only before a new sentence inside the
/// text, and otherwise the coordinator flushes after a short hold with no new speech. Pure; unit-tested.
struct UtteranceAssembler: Sendable {
    private var buffer = SentenceBuffer()

    /// Text heard but not yet passed on.
    var pending: String? {
        let text = buffer.buffer.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    /// A final result. Returns the utterances it completed, in order.
    mutating func final(_ text: String) -> [String] {
        let cleaned = Self.clean(text)
        guard !cleaned.isEmpty else { return [] }
        // The trailing space lets "?" and "!" at the end close the utterance now.
        return buffer.append(cleaned + " ")
    }

    /// What to show while someone is still talking: the pending words plus the live partial.
    func display(partial: String) -> String {
        [pending, partial.trimmingCharacters(in: .whitespacesAndNewlines)]
            .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
    }

    /// The speaker stopped: whatever is pending is one utterance.
    mutating func flush() -> String? {
        buffer.flush()
    }

    mutating func reset() {
        buffer.reset()
    }

    /// Scribe puts a lone period after a commit ("en annan ."): that is a pause, not the end of a sentence.
    static func clean(_ text: String) -> String {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        while cleaned.hasSuffix(" .") { cleaned = String(cleaned.dropLast(2)) }
        cleaned = cleaned.replacingOccurrences(of: " . ", with: " ")
        if cleaned == "." { return "" }
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
