import Foundation
import Observation

/// `social.style` (D63): Rizzläge flirts, Socialt läge never does.
enum LiveStyle: String, Sendable {
    case flirt
    case social
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
    static let adultKey = "mode.adultConfirmed"
    static let interestsKey = "mode.rizzInterests"
    static let profileKey = "mode.rizzProfile"
    static let thresholdKey = "mode.speakerThresholdDBFS"
    static let countsKey = "mode.rizzStyleCounts"

    /// The role or the pasted job ad.
    var interviewSetup: String {
        didSet { defaults.set(interviewSetup, forKey: Self.interviewKey) }
    }
    /// "Jag är 18 år eller äldre": asked once, stored on this phone (D63).
    private(set) var isAdultConfirmed: Bool
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
        self.isAdultConfirmed = defaults.bool(forKey: Self.adultKey)
        self.rizzInterests = defaults.string(forKey: Self.interestsKey) ?? ""
        self.rizzProfile = defaults.string(forKey: Self.profileKey) ?? ""
        self.speakerThresholdDBFS = defaults.object(forKey: Self.thresholdKey) as? Double ?? -30
        self.styleCounts = defaults.dictionary(forKey: Self.countsKey) as? [String: Int] ?? [:]
    }

    var interests: [String] {
        rizzInterests.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    func confirmAdult() {
        isAdultConfirmed = true
        defaults.set(true, forKey: Self.adultKey)
    }

    func countUse(of style: LiveStyle) {
        styleCounts[style.rawValue, default: 0] += 1
        defaults.set(styleCounts, forKey: Self.countsKey)
    }
}
