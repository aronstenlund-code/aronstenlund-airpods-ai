import AVFAudio
import Foundation
import Observation
import os

@MainActor
protocol PlaybackServicing: AnyObject {
    /// Playback rate without pitch change, clamped to 0.5…2.0.
    var rate: Float { get set }
    /// "play requested → first non-silent buffer rendered" measurements, ms, newest last.
    var latencySamplesMs: [Double] { get }
    var isSpeaking: Bool { get }
    /// Every buffer of speech handed to the player (Apple or streamed): first-audio latency.
    var onAudioScheduled: (@MainActor () -> Void)? { get set }

    func playTestTone(frequency: Double, duration: Double) throws(AudioError)
    /// Speaks `text` through our engine (not the system's) using `AVSpeechSynthesizer.write`.
    /// `voiceIdentifier` picks a specific `AVSpeechSynthesisVoice`; nil = the default voice for `language`.
    func speak(_ text: String, language: String, voiceIdentifier: String?) async throws(AudioError)
    /// Schedules raw 16-bit mono PCM (streamed cloud TTS, item 5) into the playback graph.
    func play(samples: [Int16], sampleRate: Double) throws(AudioError)
    func stop()
    func clearLatencySamples()
}

extension PlaybackServicing {
    func speak(_ text: String, language: String) async throws(AudioError) {
        try await speak(text, language: language, voiceIdentifier: nil)
    }
}

/// Measures the time from a play request to the first non-silent buffer leaving the time-pitch node.
/// Sendable: all state is behind a lock. `observe` runs on the render thread (no allocation on the fast path).
final class PlaybackLatencyProbe: Sendable {
    struct State: Sendable {
        var requestedHostTime: UInt64?
        var measurementsMs: [Double] = []
    }

    private let state = OSAllocatedUnfairLock(initialState: State())

    func markRequested() {
        let now = mach_absolute_time()
        state.withLock { $0.requestedHostTime = now }
    }

    func observe(_ buffer: AVAudioPCMBuffer, at time: AVAudioTime) {
        guard let requested = state.withLock({ $0.requestedHostTime }) else { return }
        guard let channels = buffer.floatChannelData else { return }
        let count = Int(buffer.frameLength)
        var peak: Float = 0
        let samples = channels[0]
        for i in 0..<count {
            let v = abs(samples[i])
            if v > peak { peak = v }
        }
        guard peak > 0.001 else { return }
        let now = mach_absolute_time()
        let elapsedMs = AVAudioTime.seconds(forHostTime: now &- requested) * 1000
        state.withLock {
            $0.requestedHostTime = nil
            $0.measurementsMs.append(elapsedMs)
        }
    }

    /// Returns and clears the finished measurements.
    func drain() -> [Double] {
        state.withLock { s in
            let m = s.measurementsMs
            s.measurementsMs.removeAll()
            return m
        }
    }
}

/// Sendable copy of one TTS buffer (AVAudioPCMBuffer is not Sendable). Mono: channel 0 only.
struct TTSChunk: Sendable {
    let samples: [Float]
    let sampleRate: Double

    init(samples: [Float], sampleRate: Double) {
        self.samples = samples
        self.sampleRate = sampleRate
    }

    init(pcm16 samples: [Int16], sampleRate: Double) {
        self.samples = samples.map { Float($0) / 32768 }
        self.sampleRate = sampleRate
    }

    init?(_ buffer: AVAudioPCMBuffer) {
        let frames = Int(buffer.frameLength)
        guard frames > 0 else { return nil }
        let format = buffer.format
        let stride = format.isInterleaved ? Int(format.channelCount) : 1
        sampleRate = format.sampleRate
        if let data = buffer.floatChannelData {
            let source = data[0]
            samples = (0..<frames).map { source[$0 * stride] }
        } else if let data = buffer.int16ChannelData {
            let source = data[0]
            samples = (0..<frames).map { Float(source[$0 * stride]) / 32768 }
        } else if let data = buffer.int32ChannelData {
            let source = data[0]
            samples = (0..<frames).map { Float(Double(source[$0 * stride]) / 2_147_483_648) }
        } else {
            return nil
        }
    }
}

@MainActor
@Observable
final class PlaybackService: PlaybackServicing {
    var rate: Float = 1.0 {
        didSet {
            let clamped = min(2.0, max(0.5, rate))
            if clamped != rate { rate = clamped }
            timePitch.rate = clamped
        }
    }
    private(set) var latencySamplesMs: [Double] = []
    /// True while speech is being scheduled or scheduled buffers are still playing (self-playback suppression, §4.3).
    private(set) var isSpeaking = false
    var onAudioScheduled: (@MainActor () -> Void)?
    private var activeStreams = 0
    private var pendingBuffers = 0
    /// Bumped by `stop()` so completion callbacks of discarded buffers are ignored.
    private var scheduleGeneration = 0

    private let graph: AudioGraph
    /// Fixed graph format for the playback branch (D16); the mixer converts to the hardware rate.
    private let playbackFormat: AVAudioFormat
    private var player = AVAudioPlayerNode()
    private var timePitch = AVAudioUnitTimePitch()
    private let probe = PlaybackLatencyProbe()
    private let synthesizer = AVSpeechSynthesizer()
    private var ttsConverter: PCMConverter?

    init(graph: AudioGraph) {
        self.graph = graph
        // Fixed, valid parameters → cannot fail.
        self.playbackFormat = AVAudioFormat(standardFormatWithSampleRate: 24_000, channels: 1)!
        attach()
        graph.onRebuild = { [weak self] in
            self?.player = AVAudioPlayerNode()
            self?.timePitch = AVAudioUnitTimePitch()
            self?.attach()
        }
    }

    private func attach() {
        let engine = graph.engine
        engine.attach(player)
        engine.attach(timePitch)
        engine.connect(player, to: timePitch, format: playbackFormat)
        engine.connect(timePitch, to: engine.mainMixerNode, format: playbackFormat)
        timePitch.rate = rate
        let probe = self.probe
        timePitch.installTap(onBus: 0, bufferSize: 256, format: playbackFormat) { buffer, time in
            probe.observe(buffer, at: time)
        }
    }

    // MARK: - Test tone

    func playTestTone(frequency: Double = 440, duration: Double = 0.6) throws(AudioError) {
        try graph.ensureRunning()
        let sampleRate = playbackFormat.sampleRate
        let frames = AVAudioFrameCount(sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: playbackFormat, frameCapacity: frames),
              let channel = buffer.floatChannelData?[0] else {
            throw .playbackFormatUnavailable
        }
        buffer.frameLength = frames
        let ramp = sampleRate * 0.01
        for i in 0..<Int(frames) {
            let t = Double(i) / sampleRate
            let envelope = min(1.0, min(Double(i), Double(Int(frames) - i)) / ramp)
            channel[i] = Float(0.3 * sin(2 * .pi * frequency * t) * envelope)
        }
        requestPlayback()
        player.scheduleBuffer(buffer, completionHandler: nil)
        if !player.isPlaying { player.play() }
        Log.playback.info("Test tone \(Int(frequency)) Hz, \(duration) s")
    }

    // MARK: - TTS through our engine

    func speak(_ text: String, language: String, voiceIdentifier: String?) async throws(AudioError) {
        let chosen = voiceIdentifier.flatMap { AVSpeechSynthesisVoice(identifier: $0) }
        guard let voice = chosen ?? AVSpeechSynthesisVoice(language: language) else {
            throw .ttsFailed(detail: "no voice for \(language)")
        }
        try graph.ensureRunning()
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice

        let (stream, continuation) = AsyncStream<TTSChunk>.makeStream(bufferingPolicy: .unbounded)
        beginStream()
        requestPlayback()
        Log.playback.info("Speak (\(language, privacy: .public)): \(text, privacy: .public)")

        synthesizer.write(utterance) { buffer in
            guard let pcm = buffer as? AVAudioPCMBuffer else { return }
            if pcm.frameLength == 0 {
                continuation.finish()
                return
            }
            if let chunk = TTSChunk(pcm) {
                continuation.yield(chunk)
            }
        }

        defer { endStream() }
        var chunkCount = 0
        for await chunk in stream {
            try schedule(chunk)
            chunkCount += 1
        }
        Log.playback.info("TTS finished scheduling \(chunkCount) buffers")
    }

    /// Streamed cloud TTS (item 5): each call schedules one buffer; `isSpeaking` stays true until it has played.
    func play(samples: [Int16], sampleRate: Double) throws(AudioError) {
        guard !samples.isEmpty else { return }
        try graph.ensureRunning()
        if pendingBuffers == 0 { requestPlayback() }
        try schedule(TTSChunk(pcm16: samples, sampleRate: sampleRate))
    }

    private func beginStream() {
        activeStreams += 1
        updateSpeaking()
    }

    private func endStream() {
        activeStreams = max(0, activeStreams - 1)
        updateSpeaking()
    }

    private func bufferFinished(generation: Int) {
        guard generation == scheduleGeneration else { return }
        pendingBuffers = max(0, pendingBuffers - 1)
        updateSpeaking()
    }

    private func updateSpeaking() {
        let speaking = activeStreams > 0 || pendingBuffers > 0
        if speaking != isSpeaking { isSpeaking = speaking }
    }

    private func schedule(_ chunk: TTSChunk) throws(AudioError) {
        guard let inputFormat = AVAudioFormat(standardFormatWithSampleRate: chunk.sampleRate, channels: 1),
              let input = AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: AVAudioFrameCount(chunk.samples.count)),
              let inputChannel = input.floatChannelData?[0] else {
            throw .playbackFormatUnavailable
        }
        input.frameLength = AVAudioFrameCount(chunk.samples.count)
        chunk.samples.withUnsafeBufferPointer { source in
            if let base = source.baseAddress {
                inputChannel.update(from: base, count: source.count)
            }
        }

        if ttsConverter == nil || ttsConverter?.inputFormat.sampleRate != chunk.sampleRate {
            ttsConverter = try PCMConverter(from: inputFormat, to: playbackFormat)
        }
        guard let converter = ttsConverter,
              let output = AVAudioPCMBuffer(pcmFormat: playbackFormat,
                                            frameCapacity: converter.outputCapacity(forInputFrames: input.frameLength)) else {
            throw .playbackFormatUnavailable
        }
        try converter.convert(input, into: output)
        guard output.frameLength > 0 else { return }
        pendingBuffers += 1
        updateSpeaking()
        let generation = scheduleGeneration
        player.scheduleBuffer(output, completionCallbackType: .dataPlayedBack) { [weak self] _ in
            Task { @MainActor in self?.bufferFinished(generation: generation) }
        }
        if !player.isPlaying { player.play() }
        onAudioScheduled?()
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        scheduleGeneration += 1
        player.stop()
        pendingBuffers = 0
        activeStreams = 0
        updateSpeaking()
    }

    func clearLatencySamples() {
        latencySamplesMs.removeAll()
        _ = probe.drain()
    }

    // MARK: - Latency

    private func requestPlayback() {
        probe.markRequested()
        Log.signposter.emitEvent("play.requested")
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(700))
            self?.collectLatency()
        }
    }

    private func collectLatency() {
        let measurements = probe.drain()
        guard !measurements.isEmpty else { return }
        latencySamplesMs.append(contentsOf: measurements)
        Log.signposter.emitEvent("play.firstAudio")
        for ms in measurements {
            Log.playback.info("play requested → first buffer rendered: \(String(format: "%.1f", ms), privacy: .public) ms (+ output latency \(String(format: "%.1f", AVAudioSession.sharedInstance().outputLatency * 1000), privacy: .public) ms)")
        }
    }
}
