import Foundation

/// The name the wearer says to talk to the app (D74). One constant, so a new app name changes one line.
enum WakeWord {
    static let name = "Lumen"
}

/// What the wearer asked for after the name (D74).
enum VoiceIntent: Equatable, Sendable {
    case switchTo(ConversationMode)
    /// "pausa": let go of the microphone so music can play.
    case pause
    /// "sluta lyssna": stop completely.
    case stopListening
    /// Anything else. In Socialt läge and Rizzläge an instruction to the AI (D69 calibration, "ge mig tre"),
    /// in the other modes a question to Lumen. Never a line of the conversation.
    case instruction(String)
}

/// A recognised turn split at the name: the words before it stay conversation, the rest is for Lumen.
struct VoiceUtterance: Equatable, Sendable {
    var before: String?
    var intent: VoiceIntent?
}

/// The one voice path for every mode (D74; D69 uses it for calibration and "ge mig tre"). Pure; unit-tested.
enum VoiceChannel {
    /// The backend keeps an instruction at most this long (D69).
    static let instructionLimit = 300

    private static let switchPrefixes = ["byt till ", "byta till ", "växla till ", "gå till ", "starta ", "switch to "]
    private static let modeNames: [ConversationMode: Set<String>] = [
        .standard: ["frågor", "frågeläge", "frågorläge", "frågläge", "auto", "questions"],
        .prov: ["provläge", "provläget", "prov"],
        .interview: ["intervjuläge", "intervjuläget", "intervju"],
        .social: ["socialtläge", "socialtläget", "socialläge", "socialaläget", "socialt", "social", "socialmode"],
        .rizz: ["rizzläge", "rizzläget", "rizläge", "risläge", "rissläge", "ritsläge", "rizz", "rizzmode"],
    ]
    private static let pausePhrases: Set<String> = ["pausa", "paus", "pausa dig", "spela musik", "pause"]
    private static let stopPhrases: Set<String> = ["sluta lyssna", "sluta", "avsluta", "stäng av", "stop listening"]

    /// A turn without the name has no intent and is unchanged. The name alone is neither.
    static func parse(_ text: String) -> VoiceUtterance {
        guard let name = wakeWord(in: text) else {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return VoiceUtterance(before: trimmed.isEmpty ? nil : trimmed, intent: nil)
        }
        let before = text[..<name.lowerBound]
            .trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ",;:-–")))
        let after = text[name.upperBound...]
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        return VoiceUtterance(before: before.isEmpty ? nil : before, intent: after.isEmpty ? nil : intent(for: after))
    }

    /// The words after the name.
    static func intent(for command: String) -> VoiceIntent {
        let words = normalized(command)
        if pausePhrases.contains(words) { return .pause }
        if stopPhrases.contains(words) { return .stopListening }
        let target = switchPrefixes.first(where: { words.hasPrefix($0) }).map { String(words.dropFirst($0.count)) } ?? words
        let compact = target.replacingOccurrences(of: " ", with: "")
        if let mode = modeNames.first(where: { $0.value.contains(compact) })?.key {
            return .switchTo(mode)
        }
        return .instruction(String(command.trimmingCharacters(in: .whitespacesAndNewlines).prefix(instructionLimit)))
    }

    /// What a mode is called out loud, for the confirmation in the AirPods.
    static func spokenName(_ mode: ConversationMode) -> String {
        switch mode {
        case .standard: "Frågor."
        case .prov: "Provläge."
        case .interview: "Intervjuläge."
        case .social: "Socialt läge."
        case .rizz: "Rizzläge."
        }
    }

    /// The name as a word of its own, any case, with or without an accent ("Lumén"). "Lumens" is not the name.
    private static func wakeWord(in text: String) -> Range<String.Index>? {
        var from = text.startIndex
        while let range = text.range(of: WakeWord.name, options: [.caseInsensitive, .diacriticInsensitive], range: from..<text.endIndex) {
            let startsWord = range.lowerBound == text.startIndex || !text[text.index(before: range.lowerBound)].isLetter
            let endsWord = range.upperBound == text.endIndex || !text[range.upperBound].isLetter
            if startsWord, endsWord { return range }
            from = range.upperBound
        }
        return nil
    }

    static func normalized(_ text: String) -> String {
        text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.union(.whitespaces).inverted).joined()
            .split(separator: " ").joined(separator: " ")
    }
}

/// D74: turns that are only filler ("äh", "ja", "kom igen") are never sent as a question or a reason to answer.
enum FillerFilter {
    private static let phrases = ["kom igen", "eller hur", "du vet"]
    private static let words: Set<String> = ["äh", "ähm", "öh", "öhm", "eh", "ehm", "hm", "hmm", "mm", "mmm", "mhm", "ja",
                                             "jaa", "jo", "joo", "aa", "a", "okej", "ok", "okay", "alltså", "typ",
                                             "liksom", "precis", "så", "va", "nä", "nää", "asså", "ba", "bara", "uh", "um"]

    static func isOnlyFiller(_ text: String) -> Bool {
        var rest = " " + VoiceChannel.normalized(text) + " "
        for phrase in phrases { rest = rest.replacingOccurrences(of: " \(phrase) ", with: " ") }
        let tokens = rest.split(separator: " ").map(String.init)
        return tokens.allSatisfy { words.contains($0) }
    }
}
