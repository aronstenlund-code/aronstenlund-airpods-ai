import Foundation

/// Minimal PCM WAV writer/reader for 16-bit mono/interleaved Int16 audio (debug exports, Phase 1 §3.3).
/// Sample bytes are appended in host order; all Apple platforms are little-endian, which is what WAV requires.
enum WAVWriter {
    struct Header: Equatable, Sendable {
        var sampleRate: Int
        var channels: Int
        var bitsPerSample: Int
        var dataBytes: Int

        var frameCount: Int { channels == 0 || bitsPerSample == 0 ? 0 : dataBytes / (channels * bitsPerSample / 8) }
        var duration: Double { sampleRate == 0 ? 0 : Double(frameCount) / Double(sampleRate) }
    }

    static func data(samples: [Int16], sampleRate: Int, channels: Int = 1) -> Data {
        let dataBytes = samples.count * 2
        var out = Data(capacity: 44 + dataBytes)

        func ascii(_ s: String) { out.append(contentsOf: Array(s.utf8)) }
        func u32(_ v: UInt32) { withUnsafeBytes(of: v.littleEndian) { out.append(contentsOf: $0) } }
        func u16(_ v: UInt16) { withUnsafeBytes(of: v.littleEndian) { out.append(contentsOf: $0) } }

        ascii("RIFF")
        u32(UInt32(36 + dataBytes))
        ascii("WAVE")
        ascii("fmt ")
        u32(16)                                  // PCM fmt chunk size
        u16(1)                                   // PCM
        u16(UInt16(channels))
        u32(UInt32(sampleRate))
        u32(UInt32(sampleRate * channels * 2))   // byte rate
        u16(UInt16(channels * 2))                // block align
        u16(16)                                  // bits per sample
        ascii("data")
        u32(UInt32(dataBytes))
        samples.withUnsafeBufferPointer { out.append($0) }
        return out
    }

    static func write(samples: [Int16], sampleRate: Int, channels: Int = 1, to url: URL) throws(AudioError) {
        do {
            try data(samples: samples, sampleRate: sampleRate, channels: channels).write(to: url, options: .atomic)
        } catch {
            throw .export(detail: "\(url.lastPathComponent): \(error.localizedDescription)")
        }
    }

    /// Parses a canonical 44-byte header (as written by `data`). Returns nil for anything else.
    static func readHeader(_ data: Data) -> Header? {
        guard data.count >= 44 else { return nil }
        func str(_ offset: Int) -> String { String(decoding: data[data.startIndex + offset ..< data.startIndex + offset + 4], as: UTF8.self) }
        func u32(_ offset: Int) -> UInt32 {
            data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: UInt32.self).littleEndian }
        }
        func u16(_ offset: Int) -> UInt16 {
            data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: UInt16.self).littleEndian }
        }
        guard str(0) == "RIFF", str(8) == "WAVE", str(12) == "fmt ", str(36) == "data", u16(20) == 1 else { return nil }
        return Header(sampleRate: Int(u32(24)), channels: Int(u16(22)), bitsPerSample: Int(u16(34)), dataBytes: Int(u32(40)))
    }
}
