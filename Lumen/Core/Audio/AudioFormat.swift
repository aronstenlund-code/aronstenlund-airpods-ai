import AVFAudio

/// Internal audio format (D4): 16 kHz, mono, Int16 PCM — accepted by Apple and cloud STT providers.
enum LumenAudioFormat {
    static let sampleRate: Double = 16_000
    static let channelCount: AVAudioChannelCount = 1
    static let chunkDuration: TimeInterval = 0.040
    static let ringBufferSeconds: Double = 60

    static var chunkFrames: Int { Int(sampleRate * chunkDuration) }

    /// Fresh format object each call (AVAudioFormat is not Sendable, so it is not stored statically).
    static func pcm16kMono() -> AVAudioFormat {
        // Fixed, valid parameters → the initializer cannot fail.
        AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: sampleRate, channels: channelCount, interleaved: true)!
    }

    static func describe(_ format: AVAudioFormat) -> String {
        let common: String
        switch format.commonFormat {
        case .pcmFormatFloat32: common = "Float32"
        case .pcmFormatFloat64: common = "Float64"
        case .pcmFormatInt16: common = "Int16"
        case .pcmFormatInt32: common = "Int32"
        case .otherFormat: common = "other"
        @unknown default: common = "unknown"
        }
        let interleaved = format.channelCount > 1 ? (format.isInterleaved ? " interleaved" : " non-interleaved") : ""
        return "\(Int(format.sampleRate.rounded())) Hz · \(format.channelCount) ch · \(common)\(interleaved)"
    }
}

/// ~40 ms of 16 kHz mono Int16 audio with a host-time stamp (Phase 1 §3.3).
struct AudioChunk: Sendable, Equatable {
    let samples: [Int16]
    /// `mach_absolute_time` of the first sample's input buffer, from `AVAudioTime.hostTime`.
    let hostTime: UInt64
    /// Running sample index since capture start (first sample of this chunk).
    let firstSampleIndex: Int64

    var frameCount: Int { samples.count }
    var duration: TimeInterval { Double(samples.count) / LumenAudioFormat.sampleRate }
}

/// Hands exactly one buffer to `AVAudioConverter`'s `@Sendable` input block.
///
/// `@unchecked Sendable` justification: the converter calls the input block synchronously on the thread
/// that called `convert`, and `PCMConverter` itself is single-owner, so `set`/`take` never race.
/// The block must not capture the (non-Sendable) buffer or a mutable local, hence this hand-off object.
private final class OneShotInputFeed: @unchecked Sendable {
    private var buffer: AVAudioPCMBuffer?

    func set(_ buffer: AVAudioPCMBuffer) {
        self.buffer = buffer
    }

    func take() -> AVAudioPCMBuffer? {
        defer { buffer = nil }
        return buffer
    }
}

/// Wraps `AVAudioConverter` for one fixed input → output format pair.
/// Not thread-safe: owned by exactly one caller (the capture tap context, or the main actor for TTS).
final class PCMConverter {
    let inputFormat: AVAudioFormat
    let outputFormat: AVAudioFormat
    private let converter: AVAudioConverter
    private let feed = OneShotInputFeed()

    init(from input: AVAudioFormat, to output: AVAudioFormat) throws(AudioError) {
        guard let converter = AVAudioConverter(from: input, to: output) else {
            throw .converterUnavailable(from: LumenAudioFormat.describe(input), to: LumenAudioFormat.describe(output))
        }
        self.inputFormat = input
        self.outputFormat = output
        self.converter = converter
    }

    /// Output capacity needed for `inputFrames`, with headroom for resampler delay.
    func outputCapacity(forInputFrames inputFrames: AVAudioFrameCount) -> AVAudioFrameCount {
        let ratio = outputFormat.sampleRate / inputFormat.sampleRate
        return AVAudioFrameCount((Double(inputFrames) * ratio).rounded(.up)) + 64
    }

    /// Converts `input` into `output` (which must have enough capacity). Returns frames written.
    /// A sample-rate converter may hold back a few frames; they are emitted on the next call or by `flush`.
    @discardableResult
    func convert(_ input: AVAudioPCMBuffer, into output: AVAudioPCMBuffer) throws(AudioError) -> Int {
        output.frameLength = 0
        feed.set(input)
        let feed = self.feed
        var conversionError: NSError?
        let status = converter.convert(to: output, error: &conversionError) { _, outStatus in
            if let buffer = feed.take() {
                outStatus.pointee = .haveData
                return buffer
            }
            outStatus.pointee = .noDataNow
            return nil
        }
        if let conversionError {
            throw .conversionFailed(detail: conversionError.localizedDescription)
        }
        if status == .error {
            throw .conversionFailed(detail: "AVAudioConverter returned .error")
        }
        return Int(output.frameLength)
    }

    /// A4: forget held frames without playing them (speech was interrupted).
    func resetForNextStream() {
        converter.reset()
    }

    /// Drains frames the resampler is still holding. The converter is reset afterwards and can be reused.
    @discardableResult
    func flush(into output: AVAudioPCMBuffer) throws(AudioError) -> Int {
        output.frameLength = 0
        var conversionError: NSError?
        let status = converter.convert(to: output, error: &conversionError) { _, outStatus in
            outStatus.pointee = .endOfStream
            return nil
        }
        if let conversionError {
            throw .conversionFailed(detail: conversionError.localizedDescription)
        }
        if status == .error {
            throw .conversionFailed(detail: "AVAudioConverter returned .error while flushing")
        }
        converter.reset()
        return Int(output.frameLength)
    }
}
