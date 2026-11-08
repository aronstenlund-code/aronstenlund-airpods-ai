import Foundation
import Testing
@testable import Lumen

/// Starting point for Toby (A1): known audio through `FileCaptureService`. This one stays offline (a tone, no
/// Scribe); the live chain is Toby's to build here.
@MainActor
@Suite struct FileCaptureE2ETests {
    @Test func aToneComesThroughAsChunks() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("e2e-tone-\(UUID().uuidString).wav")
        let tone = (0..<16_000).map { i in Int16(8_000 * sin(Double(i) * 2 * .pi * 440 / 16_000)) }
        try WAVWriter.write(samples: tone, sampleRate: 16_000, to: url)

        let capture = FileCaptureService(files: [url], gapSeconds: 0, pace: .asFastAsPossible, silenceAfter: false)
        try capture.start()
        var frames = 0
        for await chunk in try #require(capture.chunks) {
            frames += chunk.frameCount
            if frames >= tone.count { break }
        }
        capture.stop()
        #expect(frames >= tone.count)
    }
}
