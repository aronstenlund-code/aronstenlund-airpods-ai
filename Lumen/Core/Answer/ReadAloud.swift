import Foundation

/// D84: "Lumen, läs upp dikten …", "Lumen, rappa texten om fotosyntes", "Lumen, läs med rytm". The backend
/// (`persona: "reader"`) decides what may be reproduced: its own or free texts in full, never protected song lyrics.
/// The app reads what comes back line by line, so the line breaks become the rhythm.
enum ReadAloud {
    static let persona = "reader"

    private static let starts = ["läs upp", "läs dikten", "läs texten", "läs låten", "läs den", "läs med rytm", "läs i rytm",
                                 "rappa", "sjung", "deklamera", "read aloud", "read the", "rap "]

    static func isRequest(_ text: String) -> Bool {
        let words = VoiceChannel.normalized(text)
        return starts.contains { words.hasPrefix($0) }
    }

    /// "Källa: runeberg.org": shown, never read (Kevin D84).
    static func isSourceLine(_ text: String) -> Bool {
        let lower = text.trimmingCharacters(in: .whitespaces).lowercased()
        return lower.hasPrefix("källa:") || lower.hasPrefix("källa ") || lower.hasPrefix("source:")
    }

    /// The text as spoken units: one per line, empty lines dropped (the queue's gap between units is the pause).
    /// Long lines are split at commas so no unit runs on.
    static func units(_ text: String, longest: Int = 120) -> [String] {
        text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .flatMap { line -> [String] in
                guard line.count > longest else { return [line] }
                return line.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            }
    }
}
