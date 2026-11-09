import Foundation

/// A10: in Provläge and Frågor the speaker is the wearer, close to the AirPods microphone. Others talking in the room
/// reach it 10–20 dB quieter (Oscar O6). Their speech must neither start nor stretch a turn, and with endless chatter
/// Scribe never hears a pause, so it never commits.
///
/// Per 256 ms Silero window (the `SpeechGate` window):
/// - speech at the wearer's level passes;
/// - speech clearly below it (`marginDB`) is someone else: it goes to Scribe as silence, so Scribe's own pause
///   detection ends the wearer's question and the chatter is neither transcribed nor billed;
/// - the wearer's level is learned from the session's own loud speech, so no calibration step is needed.
/// Without a learned level (the first words) everything passes, as before. Pure and unit-tested.
struct WearerFocus: Equatable, Sendable {
    /// Below the wearer's level by this much = someone else. The wearer's own syllables vary about ±6 dB.
    var marginDB: Double = 9
    /// Speech must be this far above the noise floor to teach the wearer's level.
    var learnAboveFloorDB: Double = 15
    /// Silero says speech.
    var speechProbability: Float = 0.5

    private(set) var floorDBFS: Double?
    private(set) var wearerDBFS: Double?
    /// When the wearer last spoke (for the end of turn when Scribe does not commit).
    private(set) var lastWearerSpeechAt: Date?
    private(set) var mutedWindows = 0
    private(set) var passedWindows = 0

    enum Verdict: Equatable, Sendable {
        case wearer
        case other
        case quiet
    }

    mutating func judge(rmsDBFS: Double, probability: Float, at now: Date) -> Verdict {
        updateFloor(rmsDBFS)
        guard probability >= speechProbability else { return .quiet }
        if let wearer = wearerDBFS, rmsDBFS < wearer - marginDB {
            mutedWindows += 1
            // Never learned from (others must not pull the level down), but the level relaxes 0.2 dB a second, so
            // a wearer who starts speaking more quietly is let through again.
            wearerDBFS = wearer - 0.05
            return .other
        }
        if let floor = floorDBFS, rmsDBFS >= floor + learnAboveFloorDB {
            // Rises fast, sinks slowly: one shout does not make the wearer quiet afterwards for long.
            wearerDBFS = wearerDBFS.map { $0 < rmsDBFS ? $0 * 0.7 + rmsDBFS * 0.3 : $0 * 0.97 + rmsDBFS * 0.03 } ?? rmsDBFS
        }
        passedWindows += 1
        lastWearerSpeechAt = now
        return .wearer
    }

    private mutating func updateFloor(_ rms: Double) {
        guard let floor = floorDBFS else {
            floorDBFS = rms
            return
        }
        // Follows quieter input at once and rises slowly, like `StudyMachine`'s floor.
        floorDBFS = rms < floor ? rms : min(rms, floor + 0.25)
    }

    mutating func reset() {
        self = WearerFocus(marginDB: marginDB, learnAboveFloorDB: learnAboveFloorDB, speechProbability: speechProbability)
    }

    static func rmsDBFS(_ window: [Int16]) -> Double {
        guard !window.isEmpty else { return -120 }
        var sum = 0.0
        for sample in window {
            let value = Double(sample) / 32_768
            sum += value * value
        }
        let rms = (sum / Double(window.count)).squareRoot()
        return rms > 0 ? 20 * log10(rms) : -120
    }
}
