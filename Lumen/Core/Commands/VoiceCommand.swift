import Foundation

/// Spoken commands the phone handles itself: a whole utterance, never part of a sentence.
enum VoiceCommand {
    private static let musicHandOff: Set<String> = ["pausa", "pausa lumen", "spela musik", "pause", "pause lumen", "play music"]
    /// The server recognises these in `/answer` (D57). Rizzläge sends no question, so the phone listens there.
    private static let report: Set<String> = ["rapportera", "rapportera det där", "det där var fel", "skicka till utvecklarna", "report this"]

    private static func normalized(_ text: String) -> String {
        text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.union(.whitespaces).inverted).joined()
            .split(separator: " ").joined(separator: " ")
    }

    /// "pausa" / "spela musik" (D58): the session lets go of the audio so Spotify carries on.
    static func isMusicHandOff(_ text: String) -> Bool {
        musicHandOff.contains(normalized(text))
    }

    static func isReport(_ text: String) -> Bool {
        report.contains(normalized(text))
    }

    /// Intervjuläge (D72): what the wearer may ask for out loud. Everything else they say is their own answer and
    /// gets nothing back. The backend answers these: "klar"/"avsluta" a good-luck line, "sammanfatta" a summary,
    /// "ge mig feedback" / "hur var mitt svar" feedback.
    private static let interviewRequests = ["klar", "avsluta", "sammanfatta", "ge mig en sammanfattning", "ge mig feedback",
                                            "hur var mitt svar", "vad tyckte du om mitt svar"]

    static func isInterviewRequest(_ text: String) -> Bool {
        let words = normalized(text)
        return interviewRequests.contains { words == $0 || words.hasPrefix($0 + " ") }
    }
}
