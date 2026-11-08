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

    /// D82.2: the wearer only with a clear margin above the threshold. When it cannot be told for sure, the turn is
    /// the other person's, and a suggestion is asked for.
    static let certaintyMarginDB = 3.0

    /// By input level: the wearer is closer to the microphone. Possible with limitations, untested on device (D43).
    static func tag(levelDBFS: Double?, thresholdDBFS: Double) -> RizzSpeaker {
        guard let levelDBFS else { return .other }
        return levelDBFS >= thresholdDBFS + certaintyMarginDB ? .user : .other
    }

    /// Why the turn went to whom, for the per-turn log (D82.3).
    static func reason(levelDBFS: Double?, thresholdDBFS: Double) -> String {
        guard let levelDBFS else { return "no level measured → other" }
        let line = String(format: "%.0f dBFS vs threshold %.0f + %.0f dB", levelDBFS, thresholdDBFS, certaintyMarginDB)
        if levelDBFS >= thresholdDBFS + certaintyMarginDB { return line + " → wearer" }
        if levelDBFS >= thresholdDBFS - certaintyMarginDB { return line + " → uncertain, treated as other" }
        return line + " → other"
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
    static let lastModeKey = "mode.lastSelected"
    static let liveStartKey = "mode.liveStartConfirmed"
    static let calibrationsKey = "mode.calibrations"
    static let pausesKey = "mode.pauseSeconds"
    /// Settings range for the pause (D80).
    static let pauseRange: ClosedRange<Double> = 0.5...3.0

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
    /// The mode picker's last choice, so the app opens where the user left it (D72). Frågor on the first start.
    var lastMode: ConversationMode {
        didSet { defaults.set(lastMode.rawValue, forKey: Self.lastModeKey) }
    }
    /// Live modes whose start screen ("They know the app is listening") was confirmed on this phone. Switching to one
    /// by voice needs it (D74): the start screen is the guardrail, the voice only saves taking out the phone later.
    private(set) var liveStartConfirmed: Set<String>
    /// What the wearer has told the AI in each live mode, as the backend merged it (D69). On this phone only,
    /// reset in Settings.
    private(set) var calibrations: [String: String]
    /// How long the speaker must be quiet before Lumen answers, per mode (D80). Replaces D78's fixed waits.
    private(set) var pauses: [String: Double]
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.interviewSetup = defaults.string(forKey: Self.interviewKey) ?? ""
        self.isAdultConfirmed = defaults.bool(forKey: Self.adultKey)
        self.rizzInterests = defaults.string(forKey: Self.interestsKey) ?? ""
        self.rizzProfile = defaults.string(forKey: Self.profileKey) ?? ""
        self.speakerThresholdDBFS = defaults.object(forKey: Self.thresholdKey) as? Double ?? -30
        self.styleCounts = defaults.dictionary(forKey: Self.countsKey) as? [String: Int] ?? [:]
        self.lastMode = defaults.string(forKey: Self.lastModeKey).flatMap(ConversationMode.init(rawValue:)) ?? .standard
        self.liveStartConfirmed = Set(defaults.stringArray(forKey: Self.liveStartKey) ?? [])
        self.calibrations = defaults.dictionary(forKey: Self.calibrationsKey) as? [String: String] ?? [:]
        self.pauses = defaults.dictionary(forKey: Self.pausesKey) as? [String: Double] ?? [:]
    }

    var interests: [String] {
        rizzInterests.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    /// D80 defaults: Frågor 1.0 s, Provläge 1.2 s, Intervju 1.5 s, Socialt/Rizz 0.8 s.
    nonisolated static func defaultPause(for mode: ConversationMode) -> Double {
        switch mode {
        case .standard: 1.0
        case .prov: 1.2
        case .interview: 1.5
        case .social, .rizz: 0.8
        }
    }

    func pause(for mode: ConversationMode) -> Double {
        pauses[mode.rawValue] ?? Self.defaultPause(for: mode)
    }

    func setPause(_ seconds: Double, for mode: ConversationMode) {
        pauses[mode.rawValue] = min(Self.pauseRange.upperBound, max(Self.pauseRange.lowerBound, seconds))
        defaults.set(pauses, forKey: Self.pausesKey)
    }

    func calibration(for mode: ConversationMode) -> String? {
        calibrations[mode.rawValue]
    }

    /// Stores `done.calibration`; empty removes it (the backend sends "" after "återställ").
    func setCalibration(_ text: String?, for mode: ConversationMode) {
        let trimmed = String((text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).prefix(VoiceChannel.instructionLimit))
        calibrations[mode.rawValue] = trimmed.isEmpty ? nil : trimmed
        defaults.set(calibrations, forKey: Self.calibrationsKey)
    }

    /// "Återställ" in Settings.
    func resetCalibration(for mode: ConversationMode) {
        setCalibration(nil, for: mode)
    }

    func hasConfirmedLiveStart(_ mode: ConversationMode) -> Bool {
        liveStartConfirmed.contains(mode.rawValue)
    }

    func confirmLiveStart(_ mode: ConversationMode) {
        liveStartConfirmed.insert(mode.rawValue)
        defaults.set(Array(liveStartConfirmed).sorted(), forKey: Self.liveStartKey)
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
