import Foundation
import Testing
@testable import Lumen

@Suite struct AudioLevelTests {
    @Test func fullScaleSquareIsZeroDBFS() {
        let samples: [Int16] = (0..<1_000).map { $0 % 2 == 0 ? 32_767 : -32_767 }
        let reading = AudioLevel.reading(samples)
        #expect(abs(reading.rmsDBFS) < 0.01)
        #expect(abs(reading.peakDBFS) < 0.01)
    }

    @Test func halfAmplitudeSineIsMinusNineDBFS() {
        let samples: [Int16] = (0..<16_000).map { Int16(16_383.5 * sin(2 * Double.pi * 440 * Double($0) / 16_000)) }
        let reading = AudioLevel.reading(samples)
        #expect(abs(reading.rmsDBFS - (-9.03)) < 0.1, "rms=\(reading.rmsDBFS)")
        #expect(abs(reading.peakDBFS - (-6.02)) < 0.1, "peak=\(reading.peakDBFS)")
    }

    @Test func silenceIsFloor() {
        let reading = AudioLevel.reading([Int16](repeating: 0, count: 100))
        #expect(reading == .silence)
        #expect(AudioLevel.reading([]) == .silence)
        #expect(AudioLevel.dBFS(0) == AudioLevel.floorDBFS)
        #expect(AudioLevel.dBFS(1) == 0)
    }

    /// Deterministic pseudo-noise so the test never flakes.
    private func noise(count: Int, amplitude: Int, seed: UInt64 = 42) -> [Int16] {
        var state = seed
        return (0..<count).map { _ in
            state = state &* 6364136223846793005 &+ 1442695040888963407
            let unit = Double(state >> 11) / Double(1 << 53) // 0..<1
            return Int16((unit * 2 - 1) * Double(amplitude))
        }
    }

    @Test func snrEstimatorOnSyntheticSpeechBursts() throws {
        // 4 s: noise floor ±50 (≈ −61 dBFS), three 0.5 s bursts of a 300 Hz tone at amplitude 8000 (≈ −15 dBFS)
        let sampleRate = 16_000.0
        var samples = noise(count: 64_000, amplitude: 50)
        for start in [8_000, 24_000, 44_000] {
            for i in 0..<8_000 {
                let value = 8_000 * sin(2 * Double.pi * 300 * Double(i) / sampleRate)
                samples[start + i] = Int16(clamping: Int(value) + Int(samples[start + i]))
            }
        }
        let estimate = try #require(SNREstimator.estimate(samples, sampleRate: sampleRate))
        #expect(abs(estimate.noiseFloorDBFS - (-61)) < 3, "floor=\(estimate.noiseFloorDBFS)")
        #expect(abs(estimate.speechRMSDBFS - (-15.3)) < 1.5, "speech=\(estimate.speechRMSDBFS)")
        #expect(estimate.snrDB > 40 && estimate.snrDB < 50, "snr=\(estimate.snrDB)")
        #expect(abs(estimate.speechFraction - 0.375) < 0.03, "fraction=\(estimate.speechFraction)")
        #expect(estimate.frameCount == 200)
        #expect(abs(estimate.durationSeconds - 4) < 1e-9)
    }

    @Test func snrEstimatorReturnsNilWithoutSpeech() {
        #expect(SNREstimator.estimate(noise(count: 16_000, amplitude: 50)) == nil)
        #expect(SNREstimator.estimate([Int16](repeating: 0, count: 10)) == nil)
    }
}
