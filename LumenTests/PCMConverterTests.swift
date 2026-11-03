import AVFAudio
import Testing
@testable import Lumen

@Suite struct PCMConverterTests {
    /// Fills every channel with a sine of `amplitude` at `frequency`.
    private func sineBuffer(format: AVAudioFormat, frames: AVAudioFrameCount, frequency: Double, amplitude: Float) throws -> AVAudioPCMBuffer {
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames))
        buffer.frameLength = frames
        let channels = try #require(buffer.floatChannelData)
        for channel in 0..<Int(format.channelCount) {
            for i in 0..<Int(frames) {
                channels[channel][i] = amplitude * Float(sin(2 * Double.pi * frequency * Double(i) / format.sampleRate))
            }
        }
        return buffer
    }

    private func int16Stats(_ buffer: AVAudioPCMBuffer) throws -> (count: Int, rms: Double, peak: Int) {
        let data = try #require(buffer.int16ChannelData)
        let n = Int(buffer.frameLength)
        var sum = 0.0
        var peak = 0
        for i in 0..<n {
            let v = Int(data[0][i])
            sum += Double(v * v)
            peak = max(peak, abs(v))
        }
        return (n, n == 0 ? 0 : (sum / Double(n)).squareRoot(), peak)
    }

    @Test func convert48kStereoFloatTo16kMonoInt16() throws {
        let input = try #require(AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2))
        let buffer = try sineBuffer(format: input, frames: 48_000, frequency: 440, amplitude: 0.5)
        let converter = try PCMConverter(from: input, to: LumenAudioFormat.pcm16kMono())
        let output = try #require(AVAudioPCMBuffer(pcmFormat: converter.outputFormat,
                                                   frameCapacity: converter.outputCapacity(forInputFrames: 48_000)))
        let written = try converter.convert(buffer, into: output)
        // 1 s in → ~1 s out at 16 kHz (the resampler may hold back a few frames until flushed)
        #expect(written >= 15_800 && written <= 16_064, "frames=\(written)")

        let stats = try int16Stats(output)
        let expectedRMS = 0.5 / 2.0.squareRoot() * 32_768
        #expect(abs(stats.rms - expectedRMS) / expectedRMS < 0.05, "rms=\(stats.rms)")
        #expect(stats.peak <= Int(0.5 * 32_768 * 1.05))
        #expect(stats.peak >= Int(0.5 * 32_768 * 0.9))
        #expect(converter.outputFormat.sampleRate == 16_000)
        #expect(converter.outputFormat.channelCount == 1)
        #expect(converter.outputFormat.commonFormat == .pcmFormatInt16)
    }

    @Test func convert24kMonoFloatTo16k() throws {
        let input = try #require(AVAudioFormat(standardFormatWithSampleRate: 24_000, channels: 1))
        let buffer = try sineBuffer(format: input, frames: 24_000, frequency: 1_000, amplitude: 0.25)
        let converter = try PCMConverter(from: input, to: LumenAudioFormat.pcm16kMono())
        let output = try #require(AVAudioPCMBuffer(pcmFormat: converter.outputFormat,
                                                   frameCapacity: converter.outputCapacity(forInputFrames: 24_000)))
        let written = try converter.convert(buffer, into: output)
        #expect(written >= 15_800 && written <= 16_064, "frames=\(written)")
        let stats = try int16Stats(output)
        let expectedRMS = 0.25 / 2.0.squareRoot() * 32_768
        #expect(abs(stats.rms - expectedRMS) / expectedRMS < 0.05, "rms=\(stats.rms)")
    }

    @Test func passthrough16kInt16IsExact() throws {
        let format = LumenAudioFormat.pcm16kMono()
        let frames: AVAudioFrameCount = 640
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames))
        buffer.frameLength = frames
        let data = try #require(buffer.int16ChannelData)
        for i in 0..<Int(frames) { data[0][i] = Int16(truncatingIfNeeded: i * 37 - 10_000) }

        let converter = try PCMConverter(from: format, to: LumenAudioFormat.pcm16kMono())
        let output = try #require(AVAudioPCMBuffer(pcmFormat: converter.outputFormat,
                                                   frameCapacity: converter.outputCapacity(forInputFrames: frames)))
        let written = try converter.convert(buffer, into: output)
        #expect(written == 640)
        let out = try #require(output.int16ChannelData)
        for i in 0..<640 {
            #expect(out[0][i] == data[0][i])
        }
    }

    @Test func flushDrainsRemainingFramesAndAllowsReuse() throws {
        let input = try #require(AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1))
        let buffer = try sineBuffer(format: input, frames: 4_800, frequency: 440, amplitude: 0.5)
        let converter = try PCMConverter(from: input, to: LumenAudioFormat.pcm16kMono())
        let output = try #require(AVAudioPCMBuffer(pcmFormat: converter.outputFormat,
                                                   frameCapacity: converter.outputCapacity(forInputFrames: 4_800)))
        let first = try converter.convert(buffer, into: output)
        let flushed = try converter.flush(into: output)
        #expect(first + flushed >= 1_590 && first + flushed <= 1_610, "first=\(first) flushed=\(flushed)")
        // reusable after flush
        let again = try converter.convert(buffer, into: output)
        #expect(again > 1_500)
    }

    @Test func chunkDurationMatchesFormat() {
        #expect(LumenAudioFormat.chunkFrames == 640)
        let chunk = AudioChunk(samples: [Int16](repeating: 0, count: 640), hostTime: 0, firstSampleIndex: 0)
        #expect(abs(chunk.duration - 0.040) < 1e-9)
    }
}
