import Foundation
import Observation

/// Tunables for Provläge (D36). Defaults are the decision's numbers; the device session tunes them.
struct StudyTuning: Equatable, Sendable {
    /// Silence after the user's speech that ends the turn.
    var endpointSilence: TimeInterval = 0.8
    /// Extra wait for the recogniser's final result when only a partial exists at the endpoint.
    var finalGrace: TimeInterval = 0.7
    /// Speech must stay above the threshold this long before it counts as the start of a turn (clicks, coughs).
    var speechOnsetHold: TimeInterval = 0.12
    /// Sustained speech while the assistant talks that counts as a barge-in.
    var bargeInHold: TimeInterval = 0.4
    /// How far above the adaptive noise floor speech must be (dB).
    var speechThresholdDB: Double = 12
    /// Absolute floor: quieter than this is never speech (dBFS).
    var minimumSpeechDBFS: Double = -50
    /// The floor follows quieter input at once and rises slowly (dB per second) so speech never becomes the floor.
    var floorRiseDBPerSecond: Double = 1.0
    /// No user speech for this long ends the session (and, in Provläge, releases the microphone: "sparläge").
    var autoEndSilence: TimeInterval = 600
}

enum StudyPhase: Equatable, Sendable {
    case off
    /// Waiting for the user to speak, or collecting a turn.
    case listening
    /// The turn was sent; the answer is being produced.
    case thinking
    /// The assistant is speaking; the recogniser input is gated; barge-in watches the level.
    case speaking
}

enum StudyEvent: Equatable, Sendable {
    case turnStarted
    case endOfTurn(String)
    case bargeIn
    case autoEnded
}

/// Pure state machine for the hands-free tutor session: VAD on the 40 ms level readings, end-of-turn detection,
/// barge-in, auto-end. Time is passed in; unit-tested without audio.
struct StudyMachine: Equatable, Sendable {
    var tuning: StudyTuning
    private(set) var phase: StudyPhase = .off
    private(set) var noiseFloorDBFS: Double?
    private(set) var isUserSpeaking = false
    private var loudRunStart: Date?
    private var lastSpeechAt: Date?
    private var lastFloorUpdate: Date?
    private var lastActivityAt: Date?
    private var turnFinals: [String] = []
    private var turnPartial: String?

    init(tuning: StudyTuning = StudyTuning()) {
        self.tuning = tuning
    }

    var turnText: String {
        var parts = turnFinals
        if let turnPartial, !turnPartial.isEmpty { parts.append(turnPartial) }
        return parts.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: Session

    mutating func start(at now: Date) {
        phase = .listening
        lastActivityAt = now
        resetTurn()
    }

    mutating func stop() {
        phase = .off
        resetTurn()
    }

    // MARK: Level readings (one per capture chunk, also silence)

    mutating func level(_ rmsDBFS: Double, at now: Date) -> StudyEvent? {
        guard phase != .off else { return nil }
        updateFloor(rmsDBFS, at: now)
        let threshold = max(tuning.minimumSpeechDBFS, (noiseFloorDBFS ?? -60) + tuning.speechThresholdDB)
        let loud = rmsDBFS > threshold

        switch phase {
        case .listening:
            if loud {
                if loudRunStart == nil { loudRunStart = now }
                lastActivityAt = now
                if !isUserSpeaking, let start = loudRunStart, now.timeIntervalSince(start) >= tuning.speechOnsetHold {
                    isUserSpeaking = true
                    lastSpeechAt = now
                    return .turnStarted
                }
                if isUserSpeaking { lastSpeechAt = now }
            } else {
                loudRunStart = nil
                if isUserSpeaking, let last = lastSpeechAt {
                    let silence = now.timeIntervalSince(last)
                    if silence >= tuning.endpointSilence {
                        if !turnFinals.isEmpty || silence >= tuning.endpointSilence + tuning.finalGrace {
                            return endTurnIfPossible(now: now)
                        }
                    }
                }
            }
            if let activity = lastActivityAt, now.timeIntervalSince(activity) >= tuning.autoEndSilence {
                phase = .off
                resetTurn()
                return .autoEnded
            }
        case .speaking:
            if loud {
                if loudRunStart == nil { loudRunStart = now }
                if let start = loudRunStart, now.timeIntervalSince(start) >= tuning.bargeInHold {
                    phase = .listening
                    resetTurn()
                    isUserSpeaking = true
                    lastSpeechAt = now
                    lastActivityAt = now
                    return .bargeIn
                }
            } else {
                loudRunStart = nil
            }
        case .thinking, .off:
            if loud { lastActivityAt = now }
        }
        return nil
    }

    // MARK: Transcript

    mutating func transcriptPartial(_ text: String) {
        guard phase == .listening else { return }
        turnPartial = text
    }

    /// A final result closes the turn at once if the user has already fallen silent long enough.
    mutating func transcriptFinal(_ text: String, at now: Date) -> StudyEvent? {
        guard phase == .listening else { return nil }
        turnPartial = nil
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { turnFinals.append(trimmed) }
        if isUserSpeaking, let last = lastSpeechAt, now.timeIntervalSince(last) >= tuning.endpointSilence {
            return endTurnIfPossible(now: now)
        }
        return nil
    }

    // MARK: Answer / speech lifecycle

    mutating func answerStarted() {
        guard phase != .off else { return }
        phase = .thinking
    }

    mutating func speechStarted() {
        guard phase != .off else { return }
        phase = .speaking
        loudRunStart = nil
    }

    /// Back to listening for the next turn (speech finished, answer failed, or nothing to say).
    mutating func resumeListening(at now: Date) {
        guard phase != .off else { return }
        phase = .listening
        lastActivityAt = now
        resetTurn()
    }

    // MARK: Private

    private mutating func endTurnIfPossible(now: Date) -> StudyEvent? {
        let text = turnText
        isUserSpeaking = false
        lastSpeechAt = nil
        loudRunStart = nil
        guard !text.isEmpty else {
            // Noise without words: forget it, keep listening.
            resetTurn()
            return nil
        }
        phase = .thinking
        resetTurn()
        lastActivityAt = now
        return .endOfTurn(text)
    }

    private mutating func resetTurn() {
        turnFinals.removeAll()
        turnPartial = nil
        isUserSpeaking = false
        lastSpeechAt = nil
        loudRunStart = nil
    }

    private mutating func updateFloor(_ rmsDBFS: Double, at now: Date) {
        guard let floor = noiseFloorDBFS, let previous = lastFloorUpdate else {
            noiseFloorDBFS = rmsDBFS
            lastFloorUpdate = now
            return
        }
        // Gaps between readings (paused capture) must not let the floor jump: at most one second per update.
        let elapsed = min(1.0, max(0, now.timeIntervalSince(previous)))
        lastFloorUpdate = now
        if rmsDBFS < floor {
            noiseFloorDBFS = rmsDBFS
        } else if rmsDBFS <= floor + tuning.speechThresholdDB / 2 {
            // Only clearly-not-speech frames pull the floor up, so a long question never becomes "noise".
            noiseFloorDBFS = min(rmsDBFS, floor + tuning.floorRiseDBPerSecond * elapsed)
        }
    }
}

/// Persisted Provläge settings (UserDefaults).
@MainActor
@Observable
final class StudySettings {
    static let endpointKey = "study.endpointSilence"
    static let autoEndKey = "study.autoEndMinutes"
    static let voiceChatKey = "study.voiceChatMode"

    /// 0.5…1.5 s.
    var endpointSilence: Double {
        didSet { defaults.set(endpointSilence, forKey: Self.endpointKey) }
    }
    /// 1…60 minutes.
    var autoEndMinutes: Int {
        didSet { defaults.set(autoEndMinutes, forKey: Self.autoEndKey) }
    }
    /// Use the C-HFP-voiceChat capture config (echo cancellation) while in Provläge — to measure (D36).
    var useVoiceChatMode: Bool {
        didSet { defaults.set(useVoiceChatMode, forKey: Self.voiceChatKey) }
    }
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.object(forKey: Self.endpointKey) as? Double
        self.endpointSilence = stored ?? 0.8
        self.autoEndMinutes = defaults.object(forKey: Self.autoEndKey) as? Int ?? 10
        self.useVoiceChatMode = defaults.object(forKey: Self.voiceChatKey) as? Bool ?? false
    }

    var tuning: StudyTuning {
        var tuning = StudyTuning()
        tuning.endpointSilence = min(1.5, max(0.5, endpointSilence))
        tuning.autoEndSilence = TimeInterval(min(60, max(1, autoEndMinutes)) * 60)
        return tuning
    }
}
