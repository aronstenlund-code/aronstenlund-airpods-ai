#if DEBUG
import AVFAudio
import Foundation
import Observation

/// A1 (Toby's test hooks): WAV files instead of the microphone, behind the same `CaptureServicing` protocol, so the
/// whole chain after the microphone (gate, Silero, Scribe, turns, answers) runs on known audio in the Simulator.
/// Debug and test builds only. The Simulator is no device verification.
///
/// Turned on for the app with `LUMEN_AUDIO_FILES=/path/a.wav:/path/b.wav` (environment or launch argument
/// `-LumenAudioFiles …`), `LUMEN_AUDIO_LOOP=1` to repeat, `LUMEN_AUDIO_GAP=2.5` for the silence between files.
/// Tests can also build one directly and hand it to `SessionController`.
@MainActor
@Observable
final class FileCaptureService: CaptureServicing {
    enum Pace: Sendable, Equatable {
        /// 40 ms of audio every 40 ms, as the microphone delivers it.
        case realTime
        /// As fast as the consumer reads (for offline checks that need no timing).
        case asFastAsPossible
    }

    private(set) var isCapturing = false
    private(set) var level: AudioLevel.Reading = .silence
    private(set) var chunks: AsyncStream<AudioChunk>?
    let ringBuffer = Int16RingBuffer(seconds: LumenAudioFormat.ringBufferSeconds, sampleRate: LumenAudioFormat.sampleRate)
    var inputFormatDescription: String? { "WAV files (\(files.count)) · 16000 Hz · 1 ch · Int16" }
    private(set) var conversionErrorCount = 0
    var onFormatChange: (@MainActor (String) -> Void)?
    var onError: (@MainActor (AudioError) -> Void)?
    var voiceProcessing = false

    let files: [URL]
    let loop: Bool
    let gapSeconds: Double
    let pace: Pace
    /// After the last file (without `loop`): keep sending silence so the session goes on listening.
    let silenceAfter: Bool
    /// Which file is playing, and how many chunks were sent (for the test's log).
    private(set) var currentFile: Int = 0
    private(set) var chunksSent = 0
    /// Called when every file has been played once.
    var onFinishedFiles: (@MainActor () -> Void)?

    private var task: Task<Void, Never>?
    private var continuation: AsyncStream<AudioChunk>.Continuation?

    static let chunkFrames = Int(LumenAudioFormat.sampleRate * 0.04)

    init(files: [URL], loop: Bool = false, gapSeconds: Double = 1.0, pace: Pace = .realTime, silenceAfter: Bool = true) {
        self.files = files
        self.loop = loop
        self.gapSeconds = gapSeconds
        self.pace = pace
        self.silenceAfter = silenceAfter
    }

    /// From `LUMEN_AUDIO_FILES` (environment or `-LumenAudioFiles` launch argument). Nil: use the microphone.
    static func fromEnvironment(_ info: ProcessInfo = .processInfo) -> FileCaptureService? {
        let env = info.environment
        var value = env["LUMEN_AUDIO_FILES"]
        if value == nil, let index = info.arguments.firstIndex(of: "-LumenAudioFiles"), index + 1 < info.arguments.count {
            value = info.arguments[index + 1]
        }
        guard let value, !value.isEmpty else { return nil }
        let urls = value.split(separator: ":").map { URL(fileURLWithPath: String($0)) }
        return FileCaptureService(files: urls, loop: env["LUMEN_AUDIO_LOOP"] == "1",
                                  gapSeconds: env["LUMEN_AUDIO_GAP"].flatMap(Double.init) ?? 1.0)
    }

    func start() throws(AudioError) {
        guard !isCapturing else { throw .alreadyCapturing }
        var decoded: [[Int16]] = []
        for url in files {
            do {
                decoded.append(try Self.decode(url))
            } catch {
                conversionErrorCount += 1
                throw .conversionFailed(detail: "\(url.lastPathComponent): \(error.localizedDescription)")
            }
        }
        let (stream, continuation) = AsyncStream.makeStream(of: AudioChunk.self, bufferingPolicy: .bufferingNewest(500))
        chunks = stream
        self.continuation = continuation
        isCapturing = true
        chunksSent = 0
        let gap = [Int16](repeating: 0, count: Int(gapSeconds * LumenAudioFormat.sampleRate))
        task = Task { [weak self] in
            var index: Int64 = 0
            var round = 0
            repeat {
                for (number, samples) in decoded.enumerated() {
                    self?.currentFile = number
                    for part in [samples, gap] {
                        var offset = 0
                        while offset < part.count {
                            guard let self, !Task.isCancelled, self.isCapturing else { return }
                            let end = min(offset + Self.chunkFrames, part.count)
                            self.emit(Array(part[offset..<end]), index: index)
                            index += Int64(end - offset)
                            offset = end
                            if self.pace == .realTime { try? await Task.sleep(for: .milliseconds(40)) } else { await Task.yield() }
                        }
                    }
                }
                round += 1
                if round == 1 { self?.onFinishedFiles?() }
            } while self?.loop == true && !Task.isCancelled
            // Silence afterwards, so the session (and its pause detection) goes on as if the room went quiet.
            let silence = [Int16](repeating: 0, count: Self.chunkFrames)
            while let self, !Task.isCancelled, self.isCapturing, self.silenceAfter {
                self.emit(silence, index: index)
                index += Int64(silence.count)
                if self.pace == .realTime { try? await Task.sleep(for: .milliseconds(40)) } else { try? await Task.sleep(for: .milliseconds(5)) }
            }
        }
    }

    private func emit(_ samples: [Int16], index: Int64) {
        ringBuffer.write(samples)
        level = AudioLevel.reading(samples)
        chunksSent += 1
        continuation?.yield(AudioChunk(samples: samples, hostTime: mach_absolute_time(), firstSampleIndex: index))
    }

    func stop() {
        isCapturing = false
        task?.cancel()
        task = nil
        continuation?.finish()
        continuation = nil
        chunks = nil
        level = .silence
    }

    func exportLast(seconds: Double) throws(AudioError) -> URL {
        let samples = ringBuffer.snapshot(lastSeconds: seconds)
        guard !samples.isEmpty else { throw .export(detail: "ring buffer is empty") }
        return try exportSamples(samples, name: "file-last\(Int(seconds))s")
    }

    func exportSamples(_ samples: [Int16], name: String) throws(AudioError) -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("lumen-\(name)-\(UUID().uuidString.prefix(6)).wav")
        try WAVWriter.write(samples: samples, sampleRate: Int(LumenAudioFormat.sampleRate), to: url)
        return url
    }

    // MARK: Decoding

    /// Any WAV/CAF/M4A that AVAudioFile reads → 16 kHz mono Int16 (channels averaged, linear resampling).
    nonisolated static func decode(_ url: URL) throws -> [Int16] {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        let frames = AVAudioFrameCount(file.length)
        guard frames > 0, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return [] }
        try file.read(into: buffer)
        guard let channels = buffer.floatChannelData else { return [] }
        let count = Int(buffer.frameLength)
        let channelCount = Int(format.channelCount)
        var mono = [Float](repeating: 0, count: count)
        for c in 0..<channelCount {
            let data = channels[c]
            for i in 0..<count { mono[i] += data[i] / Float(channelCount) }
        }
        return resample(mono, from: format.sampleRate, to: LumenAudioFormat.sampleRate)
    }

    nonisolated static func resample(_ samples: [Float], from rate: Double, to target: Double) -> [Int16] {
        guard !samples.isEmpty else { return [] }
        let ratio = rate / target
        let outCount = Int(Double(samples.count) / ratio)
        var out = [Int16](repeating: 0, count: outCount)
        for i in 0..<outCount {
            let position = Double(i) * ratio
            let left = Int(position)
            let right = min(left + 1, samples.count - 1)
            let fraction = Float(position - Double(left))
            let value = samples[left] * (1 - fraction) + samples[right] * fraction
            out[i] = Int16(max(-1, min(1, value)) * 32_767)
        }
        return out
    }
}
#endif
