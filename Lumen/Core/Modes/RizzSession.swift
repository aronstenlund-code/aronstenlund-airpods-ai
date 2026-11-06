import Foundation
import LumenScoring

/// One Rizzläge session (D43): the rolling transcript and the current suggestions. Lives in memory and is gone when
/// the session ends. Pure; unit-tested.
struct RizzSession: Equatable, Sendable {
    struct Line: Equatable, Sendable {
        var speaker: RizzSpeaker
        var text: String
        var at: Date
    }

    static let window: TimeInterval = 120
    /// Backend limits: 413 above these.
    static let maxLines = 40
    static let lineLimit = 300
    /// How close the user's words must be to a suggestion to count as using it.
    static let usedWER = 0.5

    let style: RizzStyle
    private(set) var lines: [Line] = []
    private(set) var suggestions: [String] = []
    private(set) var index = 0
    /// Everything offered this session, for Historik.
    private(set) var offered: [String] = []
    /// The wearer's own lines, for Historik.
    private(set) var ownLines: [String] = []

    init(style: RizzStyle) {
        self.style = style
    }

    var current: String? { suggestions.indices.contains(index) ? suggestions[index] : nil }
    var hasConversation: Bool { !lines.isEmpty }

    mutating func add(_ speaker: RizzSpeaker, text: String, at date: Date) {
        lines.append(Line(speaker: speaker, text: text, at: date))
        lines.removeAll { date.timeIntervalSince($0.at) > Self.window }
        if speaker == .user { ownLines.append(text) }
    }

    /// New options, best first.
    mutating func offer(_ options: [String]) {
        suggestions = options
        index = 0
        offered += options
    }

    /// Moves to the next option, wrapping around ("nästa").
    @discardableResult
    mutating func next() -> String? {
        guard !suggestions.isEmpty else { return nil }
        index = (index + 1) % suggestions.count
        return current
    }

    /// Did the user say one of the suggestions, more or less?
    func usesSuggestion(_ text: String) -> Bool {
        let scorer = Scorer()
        return suggestions.contains { scorer.score(reference: $0, hypothesis: text).wer <= Self.usedWER }
    }

    var transcript: [SocialRequest.Line] {
        lines.suffix(Self.maxLines).map { SocialRequest.Line(speaker: $0.speaker.rawValue, text: String($0.text.prefix(Self.lineLimit))) }
    }
}

/// "nästa" alone as a voice command (D43).
enum RizzCommand {
    static func isNext(_ text: String) -> Bool {
        let word = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        return word == "nästa" || word == "next"
    }
}
