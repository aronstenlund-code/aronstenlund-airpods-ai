import Foundation
import Observation

/// The five Rizzläge styles (D43). Raw values are the backend's `social.style`.
enum RizzStyle: String, CaseIterable, Identifiable, Sendable {
    case flirtig
    case rolig
    case självsäker
    case avslappnad
    case uppriktig

    var id: String { rawValue }
}

/// Who said a line in Rizzläge. Raw values are the backend's `speaker`.
enum RizzSpeaker: String, Sendable, Equatable {
    case user
    case other

    /// By input level: the wearer is closer to the microphone. Possible with limitations, untested on device (D43).
    static func tag(levelDBFS: Double?, thresholdDBFS: Double) -> RizzSpeaker {
        guard let levelDBFS else { return .other }
        return levelDBFS >= thresholdDBFS ? .user : .other
    }
}

/// Intervjuläge and Rizzläge setup, kept on this phone (UserDefaults).
@MainActor
@Observable
final class ModeSettings {
    static let interviewKey = "mode.interviewSetup"
    static let styleKey = "mode.rizzStyle"
    static let interestsKey = "mode.rizzInterests"
    static let profileKey = "mode.rizzProfile"
    static let thresholdKey = "mode.speakerThresholdDBFS"
    static let countsKey = "mode.rizzStyleCounts"

    /// The role or the pasted job ad.
    var interviewSetup: String {
        didSet { defaults.set(interviewSetup, forKey: Self.interviewKey) }
    }
    var rizzStyle: RizzStyle {
        didSet { defaults.set(rizzStyle.rawValue, forKey: Self.styleKey) }
    }
    /// Comma separated, as typed.
    var rizzInterests: String {
        didSet { defaults.set(rizzInterests, forKey: Self.interestsKey) }
    }
    var rizzProfile: String {
        didSet { defaults.set(rizzProfile, forKey: Self.profileKey) }
    }
    /// Louder than this is the wearer. The device session tunes it.
    var speakerThresholdDBFS: Double {
        didSet { defaults.set(speakerThresholdDBFS, forKey: Self.thresholdKey) }
    }
    /// How often a suggestion in each style was actually used. Counts only, never content (D43).
    private(set) var styleCounts: [String: Int]
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.interviewSetup = defaults.string(forKey: Self.interviewKey) ?? ""
        self.rizzStyle = defaults.string(forKey: Self.styleKey).flatMap(RizzStyle.init(rawValue:)) ?? .rolig
        self.rizzInterests = defaults.string(forKey: Self.interestsKey) ?? ""
        self.rizzProfile = defaults.string(forKey: Self.profileKey) ?? ""
        self.speakerThresholdDBFS = defaults.object(forKey: Self.thresholdKey) as? Double ?? -30
        self.styleCounts = defaults.dictionary(forKey: Self.countsKey) as? [String: Int] ?? [:]
    }

    var interests: [String] {
        rizzInterests.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    func countUse(of style: RizzStyle) {
        styleCounts[style.rawValue, default: 0] += 1
        defaults.set(styleCounts, forKey: Self.countsKey)
    }
}
