import Foundation
import LumenScoring

/// One live session, Rizzläge or Socialt läge (D43/D63): the rolling transcript and the current suggestions. Lives in memory and is gone when
/// the session ends. Pure; unit-tested.
struct RizzSession: Equatable, Sendable {
    struct Line: Equatable, Sendable {
        var speaker: RizzSpeaker
        var text: String
        var at: Date
        /// D81: "Talare 1" … from the voice; nil when not known.
        var label: String? = nil
    }

    static let window: TimeInterval = 120
    /// Backend limits: 413 above these.
    static let maxLines = 40
    static let lineLimit = 300
    /// How close the user's words must be to a suggestion to count as using it.
    static let usedWER = 0.5

    let style: LiveStyle
    private(set) var lines: [Line] = []
    private(set) var suggestions: [String] = []
    private(set) var index = 0
    /// Everything offered this session, for Historik.
    private(set) var offered: [String] = []
    /// The wearer's own lines, for Historik.
    private(set) var ownLines: [String] = []

    init(style: LiveStyle) {
        self.style = style
    }

    var current: String? { suggestions.indices.contains(index) ? suggestions[index] : nil }
    var hasConversation: Bool { !lines.isEmpty }

    mutating func add(_ speaker: RizzSpeaker, text: String, at date: Date, label: String? = nil) {
        lines.append(Line(speaker: speaker, text: text, at: date, label: speaker == .other ? label : nil))
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
        lines.suffix(Self.maxLines).map {
            SocialRequest.Line(speaker: $0.speaker.rawValue, text: String($0.text.prefix(Self.lineLimit)), label: $0.label)
        }
    }
}

/// What a live session sends (D63/D69). Nil means nothing may be sent: Rizzläge without the 18+ confirmation. Pure;
/// unit-tested.
enum LiveRequest {
    /// Suggestions for the conversation so far: every line from everyone in the last two minutes, several other
    /// speakers included (the wearer is "user", everyone else "other"), plus the stored calibration.
    static func suggestions(for session: RizzSession, trigger: String, interests: [String], profile: String,
                            calibration: String?, adultConfirmed: Bool) -> PersonaRequest? {
        persona(session.style, adultConfirmed: adultConfirmed,
                social: SocialRequest(style: session.style.rawValue, trigger: trigger, transcript: session.transcript,
                                      interests: interests, profile: profile, calibration: calibration,
                                      speaker: session.lines.last(where: { $0.speaker == .other })?.label))
    }

    /// The wearer's instruction ("lite mindre kaxig", "ge mig tre pickup lines"). It goes in `calibrate` only; the
    /// transcript carries the conversation so far, so "ge mig tre" has something to build on, but never the
    /// instruction itself.
    static func instruction(_ text: String, for session: RizzSession, interests: [String], profile: String,
                            calibration: String?, adultConfirmed: Bool) -> PersonaRequest? {
        let instruction = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !instruction.isEmpty else { return nil }
        let trigger = session.hasConversation ? "stall" : "opener"
        return persona(session.style, adultConfirmed: adultConfirmed,
                       social: SocialRequest(style: session.style.rawValue, trigger: trigger, transcript: session.transcript,
                                             interests: interests, profile: profile,
                                             calibrate: String(instruction.prefix(VoiceChannel.instructionLimit)),
                                             calibration: calibration))
    }

    private static func persona(_ style: LiveStyle, adultConfirmed: Bool, social: SocialRequest) -> PersonaRequest? {
        let flirts = style == .flirt
        guard !flirts || adultConfirmed else { return nil }
        return PersonaRequest(persona: "social", social: social, adultConfirmed: flirts ? true : nil)
    }
}

/// "nästa" alone as a voice command (D43).
enum RizzCommand {
    static func isNext(_ text: String) -> Bool {
        let word = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        return word == "nästa" || word == "next"
    }
}
