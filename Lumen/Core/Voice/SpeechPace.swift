import Foundation
import Observation

/// A20.1 (owner-approved): Lumen's voice slows down where the student needs it. Per context (mode + subject) the
/// pace steps 1.0 → 0.9 → 0.85 when the student often asks "igen" / "va?", says "långsammare", or takes notes (a long
/// silence after an answer in Provläge). "Snabbare" steps back. The pace is a learned setting: it is kept, shown in
/// Minne as a readable line ("Långsammare tal i Biologi") and can be removed there.
enum SpeechPace {
    /// The steps, fastest first. The user's own speed (Inställningar › Röst) is multiplied by these.
    static let steps: [Double] = [1.0, 0.9, 0.85]
    /// "Igen" / "va?" this many times within `repeatWindow` is a sign the voice is too fast.
    static let repeatsToSlow = 2
    static let repeatWindow: TimeInterval = 10 * 60
    /// Provläge: this long without a word after an answer looks like writing it down.
    static let noteSilence: TimeInterval = 20
    /// Note-taking pauses before the pace steps down (one long pause can be anything).
    static let notesToSlow = 3

    static func slower(than factor: Double) -> Double {
        steps.first { $0 < factor - 0.001 } ?? steps.last!
    }

    static func faster(than factor: Double) -> Double {
        steps.last { $0 > factor + 0.001 } ?? steps.first!
    }

    /// What the student says to change the pace (whole utterance, with or without "Lumen", Provläge and Frågor).
    static func request(_ text: String) -> Request? {
        let words = text.lowercased()
            .split(whereSeparator: { !$0.isLetter })
            .map(String.init)
            .filter { !fillers.contains($0) }
        guard words.count == 1, let word = words.first else { return nil }
        switch word {
        case "långsammare", "långsamt", "lugnare", "slower": return .slower
        case "snabbare", "fortare", "faster": return .faster
        default: return nil
        }
    }

    enum Request: Equatable, Sendable { case slower, faster }

    /// Words around the request that do not change it ("Lumen, kan du prata lite långsammare tack").
    static let fillers: Set<String> = ["lumen", "tack", "lite", "prata", "tala", "kan", "du", "please", "speak", "talk"]

    /// The context a pace belongs to: Provläge with its subject, or the mode.
    static func context(mode: ConversationMode, subject: String?) -> String {
        let subject = subject?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return subject.isEmpty ? mode.rawValue : mode.rawValue + "|" + subject.lowercased()
    }

    /// "Långsammare tal i Biologi", "Lite långsammare tal i Frågor".
    static func line(factor: Double, mode: ConversationMode, subject: String?) -> String {
        let how = factor <= steps.last! + 0.001 ? "Långsammare tal" : "Lite långsammare tal"
        if let subject, !subject.trimmingCharacters(in: .whitespaces).isEmpty { return how + " i " + subject }
        return how + " i " + mode.shortName.replacingOccurrences(of: " 18+", with: "")
    }
}

/// The signals within one context: repeats and note-taking pauses, with their times. Pure, unit-tested.
struct PaceSignals: Equatable, Sendable {
    private(set) var repeats: [Date] = []
    private(set) var notes = 0

    /// True: the pace should step down now (the counter starts over).
    mutating func repeated(at now: Date) -> Bool {
        repeats = repeats.filter { now.timeIntervalSince($0) < SpeechPace.repeatWindow } + [now]
        guard repeats.count >= SpeechPace.repeatsToSlow else { return false }
        repeats.removeAll()
        return true
    }

    /// True: the pace should step down now.
    mutating func tookNotes() -> Bool {
        notes += 1
        guard notes >= SpeechPace.notesToSlow else { return false }
        notes = 0
        return true
    }

    mutating func reset() {
        repeats.removeAll()
        notes = 0
    }
}

/// The learned paces, by context (UserDefaults). 1.0 is never stored.
@MainActor
@Observable
final class SpeechPaceStore {
    static let key = "voice.pace.byContext"
    struct Entry: Codable, Equatable, Sendable, Identifiable {
        var context: String
        var factor: Double
        var mode: String
        var subject: String?
        var id: String { context }
    }

    private(set) var entries: [Entry] = []
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key), let saved = try? JSONDecoder().decode([Entry].self, from: data) {
            entries = saved
        }
    }

    func factor(mode: ConversationMode, subject: String?) -> Double {
        let context = SpeechPace.context(mode: mode, subject: subject)
        return entries.first { $0.context == context }?.factor ?? 1
    }

    /// Returns the new factor.
    @discardableResult
    func set(_ factor: Double, mode: ConversationMode, subject: String?) -> Double {
        let context = SpeechPace.context(mode: mode, subject: subject)
        entries.removeAll { $0.context == context }
        if factor < 0.999 {
            let trimmed = subject?.trimmingCharacters(in: .whitespacesAndNewlines)
            entries.append(Entry(context: context, factor: factor, mode: mode.rawValue,
                                 subject: trimmed?.isEmpty == false ? trimmed : nil))
        }
        save()
        return factor
    }

    func remove(_ entry: Entry) {
        entries.removeAll { $0.context == entry.context }
        save()
    }

    func line(for entry: Entry) -> String {
        SpeechPace.line(factor: entry.factor, mode: ConversationMode(rawValue: entry.mode) ?? .prov, subject: entry.subject)
    }

    private func save() {
        if let data = try? JSONEncoder().encode(entries) { defaults.set(data, forKey: Self.key) }
    }
}
