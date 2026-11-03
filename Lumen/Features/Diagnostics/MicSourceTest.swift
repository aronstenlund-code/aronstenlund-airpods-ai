import Foundation

/// Mic-source sanity check (Phase 1 §3.6): confirm the active input is really the AirPods mic.
/// Tapping the iPhone body produces sharp impulses on the built-in mic that the AirPods barely pick up.
/// `currentRoute` alone is not trusted (see Architect report, forum 784318).
enum MicSourceTest {
    static let instructions = "Hold the iPhone at arm's length from your head and tap its back firmly 3 times within 5 seconds. The built-in mic hears the taps as sharp impulses; the AirPods mics barely do."

    enum Verdict: String, Sendable, Equatable {
        case builtInMicLikely
        case externalMicLikely
        case inconclusive

        var text: String {
            switch self {
            case .builtInMicLikely: "iPhone built-in mic is LIKELY active (taps detected)"
            case .externalMicLikely: "External (AirPods) mic likely active (no taps detected)"
            case .inconclusive: "Inconclusive — repeat with firmer taps"
            }
        }
    }

    struct Result: Sendable, Equatable {
        var impulses: Int
        var verdict: Verdict
        var baselineDBFS: Double
        var maxImpulseDBFS: Double

        var summary: String {
            "\(verdict.text) — \(impulses) impulse(s), baseline \(String(format: "%.1f", baselineDBFS)) dBFS, loudest \(String(format: "%.1f", maxImpulseDBFS)) dBFS"
        }
    }

    /// Rule set: 10 ms frames; baseline = median frame level; impulse = frame ≥ baseline + 15 dB and ≥ −45 dBFS;
    /// 150 ms refractory period between impulses. ≥ 3 impulses → built-in mic; 0 → external mic; else inconclusive.
    static func analyze(_ samples: [Int16], sampleRate: Double = LumenAudioFormat.sampleRate) -> Result {
        let frameLength = max(1, Int(sampleRate * 0.010))
        let frameCount = samples.count / frameLength
        guard frameCount >= 10 else {
            return Result(impulses: 0, verdict: .inconclusive, baselineDBFS: AudioLevel.floorDBFS, maxImpulseDBFS: AudioLevel.floorDBFS)
        }

        var levels = [Double](repeating: AudioLevel.floorDBFS, count: frameCount)
        samples.withUnsafeBufferPointer { all in
            guard let base = all.baseAddress else { return }
            for f in 0..<frameCount {
                let frame = UnsafeBufferPointer(start: base + f * frameLength, count: frameLength)
                levels[f] = AudioLevel.dBFS(AudioLevel.rmsLinear(frame))
            }
        }

        let baseline = levels.sorted()[frameCount / 2]
        let threshold = max(baseline + 15, -45)
        let refractoryFrames = Int(0.150 / 0.010)

        var impulses = 0
        var maxLevel = AudioLevel.floorDBFS
        var lastImpulse = -refractoryFrames
        for (index, level) in levels.enumerated() {
            if level > maxLevel { maxLevel = level }
            if level >= threshold, index - lastImpulse >= refractoryFrames {
                impulses += 1
                lastImpulse = index
            }
        }

        let verdict: Verdict
        if impulses >= 3 { verdict = .builtInMicLikely }
        else if impulses == 0 { verdict = .externalMicLikely }
        else { verdict = .inconclusive }
        return Result(impulses: impulses, verdict: verdict, baselineDBFS: baseline, maxImpulseDBFS: maxLevel)
    }
}
