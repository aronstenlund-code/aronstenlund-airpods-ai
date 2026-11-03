import Foundation

/// RMS / peak level maths (pure functions, unit-tested with synthetic signals).
enum AudioLevel {
    struct Reading: Sendable, Equatable {
        var rmsDBFS: Double
        var peakDBFS: Double

        static let silence = Reading(rmsDBFS: AudioLevel.floorDBFS, peakDBFS: AudioLevel.floorDBFS)
    }

    static let floorDBFS: Double = -120

    static func dBFS(_ linear: Double) -> Double {
        guard linear > 0 else { return floorDBFS }
        return max(floorDBFS, 20 * log10(linear))
    }

    /// Linear RMS (0…1) of Int16 samples.
    static func rmsLinear(_ samples: UnsafeBufferPointer<Int16>) -> Double {
        guard samples.count > 0 else { return 0 }
        var sum = 0.0
        for s in samples {
            let v = Double(s) / 32768
            sum += v * v
        }
        return (sum / Double(samples.count)).squareRoot()
    }

    static func reading(_ samples: UnsafeBufferPointer<Int16>) -> Reading {
        guard samples.count > 0 else { return .silence }
        var sum = 0.0
        var peak: Int32 = 0
        for s in samples {
            let v = Double(s) / 32768
            sum += v * v
            let magnitude = abs(Int32(s))
            if magnitude > peak { peak = magnitude }
        }
        return Reading(rmsDBFS: dBFS((sum / Double(samples.count)).squareRoot()),
                       peakDBFS: dBFS(Double(peak) / 32768))
    }

    static func reading(_ samples: [Int16]) -> Reading {
        samples.withUnsafeBufferPointer { reading($0) }
    }
}

/// Speech-vs-pause SNR estimate for the speaker-distance test (Phase 1 §3.6 step 2).
struct SNREstimate: Sendable, Equatable {
    /// RMS over frames classified as speech.
    var speechRMSDBFS: Double
    /// 20th percentile of frame RMS (pauses / room noise).
    var noiseFloorDBFS: Double
    /// `speechRMSDBFS - noiseFloorDBFS`.
    var snrDB: Double
    /// Fraction of frames classified as speech.
    var speechFraction: Double
    var frameCount: Int
    var durationSeconds: Double
}

enum SNREstimator {
    /// Rule set (documented so results are comparable):
    /// - frames of `frameDuration` (default 20 ms), RMS per frame;
    /// - noise floor = 20th percentile of frame RMS;
    /// - speech frames = frames at least 10 dB above the noise floor (and above −60 dBFS);
    /// - speech RMS = RMS over all speech frames; SNR = speech RMS − noise floor (dB).
    /// Returns nil for fewer than 5 frames or when no frame qualifies as speech.
    static func estimate(_ samples: [Int16], sampleRate: Double = LumenAudioFormat.sampleRate,
                         frameDuration: Double = 0.020) -> SNREstimate? {
        let frameLength = max(1, Int(sampleRate * frameDuration))
        let frameCount = samples.count / frameLength
        guard frameCount >= 5 else { return nil }

        var frameRMS = [Double](repeating: 0, count: frameCount)
        samples.withUnsafeBufferPointer { all in
            guard let base = all.baseAddress else { return }
            for f in 0..<frameCount {
                let frame = UnsafeBufferPointer(start: base + f * frameLength, count: frameLength)
                frameRMS[f] = AudioLevel.rmsLinear(frame)
            }
        }

        let sorted = frameRMS.sorted()
        let noiseFloor = max(sorted[Int(Double(frameCount - 1) * 0.2)], 1.0 / 32768)
        let threshold = max(noiseFloor * 3.1623, 0.001) // +10 dB, and above −60 dBFS

        var speechEnergy = 0.0
        var speechFrames = 0
        for rms in frameRMS where rms >= threshold {
            speechEnergy += rms * rms
            speechFrames += 1
        }
        guard speechFrames > 0 else { return nil }
        let speechRMS = (speechEnergy / Double(speechFrames)).squareRoot()
        let speechDB = AudioLevel.dBFS(speechRMS)
        let noiseDB = AudioLevel.dBFS(noiseFloor)
        return SNREstimate(speechRMSDBFS: speechDB,
                           noiseFloorDBFS: noiseDB,
                           snrDB: speechDB - noiseDB,
                           speechFraction: Double(speechFrames) / Double(frameCount),
                           frameCount: frameCount,
                           durationSeconds: Double(samples.count) / sampleRate)
    }
}
