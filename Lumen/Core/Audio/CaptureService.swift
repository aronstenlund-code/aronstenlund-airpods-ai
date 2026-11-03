import AVFAudio
import Foundation
import Observation
import os

@MainActor
protocol CaptureServicing: AnyObject {
    var isCapturing: Bool { get }
    /// Live input level, updated ~20×/s while capturing.
    var level: AudioLevel.Reading { get }
    /// Stream of ~40 ms 16 kHz mono Int16 chunks for the current capture (new stream per `start()`).
    var chunks: AsyncStream<AudioChunk>? { get }
    /// Last 60 s of 16 kHz mono Int16 audio.
    var ringBuffer: Int16RingBuffer { get }
    var inputFormatDescription: String? { get }
    var conversionErrorCount: Int { get }
    /// Fired when the hardware input format changed and the converter was rebuilt.
    var onFormatChange: (@MainActor (String) -> Void)? { get set }
    /// Fired for errors that happen outside a call (engine restart after a configuration change).
    var onError: (@MainActor (AudioError) -> Void)? { get set }

    func start() throws(AudioError)
    func stop()
    /// Debug builds only: writes the last `seconds` of the ring buffer to Documents as WAV.
    func exportLast(seconds: Double) throws(AudioError) -> URL
    func exportSamples(_ samples: [Int16], name: String) throws(AudioError) -> URL
}

/// State touched from the audio render thread.
///
/// `@unchecked Sendable` justification: `converter`, `outputBuffer` and `frameCursor` are used only from the
/// tap callback, which Core Audio invokes serially on one real-time thread; they are never touched after
/// `removeTap`. `ring`, `levelBox`, `errorBox` and `continuation` are thread-safe on their own.
final class CaptureTapContext: @unchecked Sendable {
    let inputFormat: AVAudioFormat
    private let converter: PCMConverter
    private let outputBuffer: AVAudioPCMBuffer
    private let ring: Int16RingBuffer
    let continuation: AsyncStream<AudioChunk>.Continuation
    private let levelBox = OSAllocatedUnfairLock(initialState: AudioLevel.Reading.silence)
    private let errorBox = OSAllocatedUnfairLock(initialState: 0)
    private var frameCursor: Int64 = 0

    init(inputFormat: AVAudioFormat, ring: Int16RingBuffer,
         continuation: AsyncStream<AudioChunk>.Continuation, maxInputFrames: AVAudioFrameCount) throws(AudioError) {
        self.inputFormat = inputFormat
        self.ring = ring
        self.continuation = continuation
        self.converter = try PCMConverter(from: inputFormat, to: LumenAudioFormat.pcm16kMono())
        guard let buffer = AVAudioPCMBuffer(pcmFormat: converter.outputFormat,
                                            frameCapacity: converter.outputCapacity(forInputFrames: maxInputFrames)) else {
            throw .converterUnavailable(from: LumenAudioFormat.describe(inputFormat), to: "16 kHz mono Int16")
        }
        self.outputBuffer = buffer
    }

    /// Real-time path: convert → ring buffer → level → chunk. No locks held across calls, no async work.
    /// The chunk's `[Int16]` is the one allocation (owned storage is needed to hand samples off the thread).
    func process(_ buffer: AVAudioPCMBuffer, at time: AVAudioTime) {
        let frames: Int
        do {
            frames = try converter.convert(buffer, into: outputBuffer)
        } catch {
            errorBox.withLock { $0 += 1 }
            return
        }
        guard frames > 0, let channels = outputBuffer.int16ChannelData else { return }
        let samples = UnsafeBufferPointer(start: channels[0], count: frames)
        ring.write(samples)
        let reading = AudioLevel.reading(samples)
        levelBox.withLock { $0 = reading }
        continuation.yield(AudioChunk(samples: Array(samples), hostTime: time.hostTime, firstSampleIndex: frameCursor))
        frameCursor += Int64(frames)
    }

    var level: AudioLevel.Reading { levelBox.withLock { $0 } }
    var conversionErrors: Int { errorBox.withLock { $0 } }
}

@MainActor
@Observable
final class CaptureService: CaptureServicing {
    private(set) var isCapturing = false
    private(set) var level: AudioLevel.Reading = .silence
    private(set) var chunks: AsyncStream<AudioChunk>?
    let ringBuffer = Int16RingBuffer(seconds: LumenAudioFormat.ringBufferSeconds, sampleRate: LumenAudioFormat.sampleRate)
    private(set) var inputFormatDescription: String?
    private(set) var conversionErrorCount = 0
    var onFormatChange: (@MainActor (String) -> Void)?
    var onError: (@MainActor (AudioError) -> Void)?

    private let graph: AudioGraph
    private var tapContext: CaptureTapContext?
    private var levelTimer: Timer?
    private var observers: [NSObjectProtocol] = []

    init(graph: AudioGraph) {
        self.graph = graph
        observers.append(NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.handleEngineConfigurationChange() }
        })
    }

    func start() throws(AudioError) {
        guard !isCapturing else { throw .alreadyCapturing }
        let engine = graph.engine
        let input = engine.inputNode

        // We want the room, not one voice (ARCHITECTURE §4.2). Default is already off; a failure here is
        // reported, not fatal.
        if input.isVoiceProcessingEnabled {
            do {
                try input.setVoiceProcessingEnabled(false)
            } catch {
                onError?(.engineStart(detail: "setVoiceProcessingEnabled(false): \(error.localizedDescription)"))
            }
        }

        let (stream, continuation) = AsyncStream<AudioChunk>.makeStream(bufferingPolicy: .bufferingNewest(128))
        let context = try installTap(on: input, continuation: continuation)
        do {
            try graph.ensureRunning()
        } catch {
            input.removeTap(onBus: 0)
            continuation.finish()
            throw error
        }

        tapContext = context
        chunks = stream
        isCapturing = true
        inputFormatDescription = LumenAudioFormat.describe(context.inputFormat)
        Log.capture.info("Capture started · input \(self.inputFormatDescription ?? "?", privacy: .public) · voiceProcessing=\(input.isVoiceProcessingEnabled)")
        Log.signposter.emitEvent("capture.started")

        levelTimer?.invalidate()
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.pollLevel() }
        }
    }

    private func installTap(on input: AVAudioInputNode, continuation: AsyncStream<AudioChunk>.Continuation) throws(AudioError) -> CaptureTapContext {
        let hardwareFormat = input.outputFormat(forBus: 0)
        guard hardwareFormat.sampleRate > 0, hardwareFormat.channelCount > 0 else {
            throw .noInputRoute
        }
        let context = try CaptureTapContext(inputFormat: hardwareFormat, ring: ringBuffer, continuation: continuation,
                                            maxInputFrames: AVAudioFrameCount(hardwareFormat.sampleRate * 0.25))
        let requestedFrames = AVAudioFrameCount(hardwareFormat.sampleRate * LumenAudioFormat.chunkDuration)
        input.installTap(onBus: 0, bufferSize: requestedFrames, format: hardwareFormat) { buffer, time in
            context.process(buffer, at: time)
        }
        return context
    }

    func stop() {
        levelTimer?.invalidate()
        levelTimer = nil
        if let context = tapContext {
            graph.engine.inputNode.removeTap(onBus: 0)
            context.continuation.finish()
            conversionErrorCount = context.conversionErrors
        }
        tapContext = nil
        chunks = nil
        isCapturing = false
        level = .silence
        graph.stop()
        Log.capture.info("Capture stopped · conversion errors=\(self.conversionErrorCount)")
        Log.signposter.emitEvent("capture.stopped")
    }

    private func pollLevel() {
        guard let context = tapContext else { return }
        level = context.level
        let errors = context.conversionErrors
        if errors != conversionErrorCount {
            conversionErrorCount = errors
            Log.capture.error("Conversion errors so far: \(errors)")
        }
    }

    /// Sample-rate / channel change on route change (Phase 1 §6): rebuild the converter and restart the engine.
    private func handleEngineConfigurationChange() {
        guard isCapturing, let old = tapContext else { return }
        let input = graph.engine.inputNode
        let newFormat = input.outputFormat(forBus: 0)
        let changed = newFormat.sampleRate != old.inputFormat.sampleRate || newFormat.channelCount != old.inputFormat.channelCount
        Log.capture.warning("Engine configuration change · format changed=\(changed) · \(LumenAudioFormat.describe(newFormat), privacy: .public)")

        input.removeTap(onBus: 0)
        do {
            let context = try installTap(on: input, continuation: old.continuation)
            tapContext = context
            inputFormatDescription = LumenAudioFormat.describe(context.inputFormat)
            try graph.ensureRunning()
            if changed {
                onFormatChange?("\(LumenAudioFormat.describe(old.inputFormat)) → \(LumenAudioFormat.describe(newFormat))")
            }
        } catch {
            onError?(error)
        }
    }

    // MARK: - Debug export

    func exportLast(seconds: Double) throws(AudioError) -> URL {
        let samples = ringBuffer.snapshot(lastSeconds: seconds)
        guard !samples.isEmpty else { throw .export(detail: "ring buffer is empty") }
        return try exportSamples(samples, name: "last\(Int(seconds))s")
    }

    func exportSamples(_ samples: [Int16], name: String) throws(AudioError) -> URL {
        #if DEBUG
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw .export(detail: "no Documents directory")
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let url = documents.appendingPathComponent("lumen-\(formatter.string(from: Date()))-\(name).wav")
        try WAVWriter.write(samples: samples, sampleRate: Int(LumenAudioFormat.sampleRate), to: url)
        Log.capture.info("Exported \(samples.count) samples to \(url.lastPathComponent, privacy: .public)")
        return url
        #else
        throw .export(detail: "WAV export is only available in Debug builds")
        #endif
    }
}
