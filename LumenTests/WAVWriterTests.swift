import Foundation
import Testing
@testable import Lumen

@Suite struct WAVWriterTests {
    @Test func headerIsCanonical() throws {
        let samples: [Int16] = [0, 1, -1, 32_767, -32_768, 1234]
        let data = WAVWriter.data(samples: samples, sampleRate: 16_000)
        #expect(data.count == 44 + samples.count * 2)
        let header = try #require(WAVWriter.readHeader(data))
        #expect(header == WAVWriter.Header(sampleRate: 16_000, channels: 1, bitsPerSample: 16, dataBytes: 12))
        #expect(header.frameCount == 6)

        // Sample bytes are little-endian Int16
        let bytes = [UInt8](data[44...])
        #expect(bytes[0] == 0 && bytes[1] == 0)
        #expect(bytes[2] == 1 && bytes[3] == 0)
        #expect(bytes[4] == 0xFF && bytes[5] == 0xFF)
        #expect(bytes[6] == 0xFF && bytes[7] == 0x7F)
        #expect(bytes[8] == 0x00 && bytes[9] == 0x80)
    }

    @Test func sixtySecondsHasCorrectDuration() throws {
        let data = WAVWriter.data(samples: [Int16](repeating: 0, count: 960_000), sampleRate: 16_000)
        let header = try #require(WAVWriter.readHeader(data))
        #expect(abs(header.duration - 60) < 1e-9)
        #expect(data.count == 44 + 1_920_000)
    }

    @Test func rejectsGarbage() {
        #expect(WAVWriter.readHeader(Data()) == nil)
        #expect(WAVWriter.readHeader(Data(repeating: 0x41, count: 64)) == nil)
    }

    @Test func writesFile() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("lumen-test-\(UUID().uuidString).wav")
        try WAVWriter.write(samples: [1, 2, 3], sampleRate: 16_000, to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let data = try Data(contentsOf: url)
        #expect(WAVWriter.readHeader(data)?.dataBytes == 6)
    }
}
