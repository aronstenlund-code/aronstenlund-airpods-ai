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
    /// No user speech for this long ends the session and releases the microphone. Nil: never (D71, the default).
    var autoEndSilence: TimeInterval?
    /// Rizzläge: nobody has spoken for this long (D43). Nil: off.
    var stallSilence: TimeInterval?
    /// Input this recent means someone is talking: suggestions wait for a pause.
    var talkingWindow: TimeInterval = 0.4
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
    case stalled
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
    private var lastLoudAt: Date?
    private var stallFired = false
    private var turnLevelSum = 0.0
    private var turnLevelCount = 0
    /// Average level of the last finished turn (who spoke, D43).
    private(set) var lastTurnLevelDBFS: Double?

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
        stallFired = false
        lastLoudAt = nil
        resetTurn()
    }

    /// Anyone in the room, in any phase.
    func someoneIsTalking(at now: Date) -> Bool {
        guard let lastLoudAt else { return false }
        return now.timeIntervalSince(lastLoudAt) < tuning.talkingWindow
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
        if loud { lastLoudAt = now }

        switch phase {
        case .listening:
            if loud {
                if loudRunStart == nil { loudRunStart = now }
                lastActivityAt = now
                if !isUserSpeaking, let start = loudRunStart, now.timeIntervalSince(start) >= tuning.speechOnsetHold {
                    isUserSpeaking = true
                    lastSpeechAt = now
                    stallFired = false
                    turnLevelSum = rmsDBFS
                    turnLevelCount = 1
                    return .turnStarted
                }
                if isUserSpeaking {
                    lastSpeechAt = now
                    turnLevelSum += rmsDBFS
                    turnLevelCount += 1
                }
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
            if let limit = tuning.autoEndSilence, let activity = lastActivityAt, now.timeIntervalSince(activity) >= limit {
                phase = .off
                resetTurn()
                return .autoEnded
            }
            if let stall = tuning.stallSilence, !stallFired, !isUserSpeaking, !loud,
               let activity = lastActivityAt, now.timeIntervalSince(activity) >= stall {
                stallFired = true
                return .stalled
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
                    stallFired = false
                    turnLevelSum = rmsDBFS
                    turnLevelCount = 1
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
        lastTurnLevelDBFS = turnLevelCount > 0 ? turnLevelSum / Double(turnLevelCount) : nil
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

    /// A voice command took the words: they are not part of the next turn (D74).
    mutating func discardTurnText() {
        turnFinals.removeAll()
        turnPartial = nil
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
    /// D74: 0.8 s cut sentences in two on the iPhone ("Det är en annan . Ja, obrutet").
    static let defaultEndpointSilence = 1.2

    /// 0.5…1.5 s.
    var endpointSilence: Double {
        didSet { defaults.set(endpointSilence, forKey: Self.endpointKey) }
    }
    /// 0 = never (D71, the default), otherwise 1…60 minutes.
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
        self.endpointSilence = stored ?? Self.defaultEndpointSilence
        self.autoEndMinutes = defaults.object(forKey: Self.autoEndKey) as? Int ?? 0
        self.useVoiceChatMode = defaults.object(forKey: Self.voiceChatKey) as? Bool ?? false
    }

    var tuning: StudyTuning {
        var tuning = StudyTuning()
        tuning.endpointSilence = min(1.5, max(0.5, endpointSilence))
        tuning.autoEndSilence = autoEndMinutes > 0 ? TimeInterval(min(60, autoEndMinutes) * 60) : nil
        return tuning
    }
}
