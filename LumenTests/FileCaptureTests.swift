import Foundation
import Testing
@testable import Lumen

/// A1: the WAV source behind `CaptureServicing`, checked on every push (offline, fast).
@MainActor
@Suite struct FileCaptureTests {
    private func writeWAV(_ samples: [Int16], rate: Int) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("a1-\(UUID().uuidString).wav")
        try WAVWriter.write(samples: samples, sampleRate: rate, to: url)
        return url
    }

    @Test func filesBecomeFortyMillisecondChunksAndFillTheRingBuffer() async throws {
        let first = try writeWAV([Int16](repeating: 4_000, count: 8_000), rate: 16_000) // 0.5 s
        let second = try writeWAV([Int16](repeating: -4_000, count: 8_000), rate: 16_000)
        let capture = FileCaptureService(files: [first, second], gapSeconds: 0.2, pace: .asFastAsPossible, silenceAfter: false)
        try capture.start()
        #expect(capture.isCapturing)

        var frames = 0
        var sizes = Set<Int>()
        for await chunk in try #require(capture.chunks) {
            frames += chunk.frameCount
            sizes.insert(chunk.frameCount)
            if frames >= 8_000 * 2 + 3_200 * 2 { break }
        }
        #expect(sizes.max() == FileCaptureService.chunkFrames, "40 ms chunks")
        #expect(frames == 16_000 + 6_400, "both files and both gaps")
        #expect(capture.currentFile == 1, "the second file was played")
        #expect(capture.ringBuffer.totalWritten >= 22_400)
        capture.stop()
        #expect(!capture.isCapturing)
    }

    @Test func otherRatesAreResampledTo16kHz() throws {
        let url = try writeWAV([Int16](repeating: 1_000, count: 48_000), rate: 48_000) // 1 s at 48 kHz
        let samples = try FileCaptureService.decode(url)
        #expect(abs(samples.count - 16_000) <= 2)
        #expect(abs(Int(samples[100]) - 1_000) <= 2)
    }

    @Test func theEnvironmentTurnsItOn() {
        #expect(FileCaptureService.fromEnvironment(ProcessInfo.processInfo) == nil, "no variable: the microphone")
    }
}
