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
    /// 0…1. Rizzläge speaks quietly (D43).
    var speechVolume: Float { get set }

    func playTestTone(frequency: Double, duration: Double) throws(AudioError)
    /// Speaks `text` through our engine (not the system's) using `AVSpeechSynthesizer.write`.
    /// `voiceIdentifier` picks a specific `AVSpeechSynthesisVoice`; nil = the default voice for `language`.
    func speak(_ text: String, language: String, voiceIdentifier: String?) async throws(AudioError)
    /// Schedules raw 16-bit mono PCM (streamed cloud TTS, item 5) into the playback graph.
    func play(samples: [Int16], sampleRate: Double) throws(AudioError)
    func stop()
    /// A72 part 3 (Toby T15b): the last `stop()` that took 200 ms or more, split up ("synthesizer 19 650 ms, player
    /// 3 ms"); nil when it was quick.
    var lastSlowStop: String? { get }
    func clearLatencySamples()
    /// A4: seconds of speech scheduled but not played yet.
    var queuedSeconds: Double { get }
    /// A4: when the scheduled speech last ran out (nil while something is queued).
    var drainedAt: Date? { get }
    /// A4: a sentence's audio is complete: the resampler's last frames play now instead of opening the next one.
    func endOfSpeech()
    /// A7 "upprepa": the speech scheduled from now on is kept (until `stopRecordingSpeech`) so it can play again
    /// without a new TTS call.
    func startRecordingSpeech()
    func stopRecordingSpeech()
    /// Plays the kept speech again. False: nothing kept.
    func replayRecordedSpeech() throws(AudioError) -> Bool
}

extension PlaybackServicing {
    var lastSlowStop: String? { nil }
    func speak(_ text: String, language: String) async throws(AudioError) {
        try await speak(text, language: language, voiceIdentifier: nil)
    }

    var queuedSeconds: Double { 0 }
    var drainedAt: Date? { nil }
    func endOfSpeech() {}
    func startRecordingSpeech() {}
    func stopRecordingSpeech() {}
    func replayRecordedSpeech() throws(AudioError) -> Bool { false }
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
    var speechVolume: Float = 1 {
        didSet { player.volume = speechVolume }
    }
    private var activeStreams = 0
    private var pendingBuffers = 0
    /// A4: frames scheduled and not played yet (playback format, 24 kHz), and when that last reached zero.
    private var queuedFrames = 0
    private(set) var drainedAt: Date?
    var queuedSeconds: Double { Double(queuedFrames) / playbackFormat.sampleRate }
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
        player.volume = speechVolume
        timePitch.installTap(onBus: 0, bufferSize: 256, format: playbackFormat, block: Self.probeTapBlock(probe))
    }

    // MARK: - Callbacks that iOS calls on its own threads
    //
    // Made in nonisolated static functions: an inline closure in this `@MainActor` class would inherit main-actor
    // isolation, and Swift 6 traps at run time when Core Audio or the synthesizer calls it on another queue
    // (the capture crash of 2026-11-07, see CaptureService.tapBlock).

    /// The latency probe on the playback branch; runs on the real-time render queue.
    nonisolated static func probeTapBlock(_ probe: PlaybackLatencyProbe) -> AVAudioNodeTapBlock {
        let block: @Sendable (AVAudioPCMBuffer, AVAudioTime) -> Void = { buffer, time in
            probe.observe(buffer, at: time)
        }
        return block
    }

    /// `AVSpeechSynthesizer.write`: buffers arrive on the synthesizer's queue. An empty buffer ends the utterance.
    nonisolated static func ttsBufferCallback(_ continuation: AsyncStream<TTSChunk>.Continuation) -> @Sendable (AVAudioBuffer) -> Void {
        { buffer in
            guard let pcm = buffer as? AVAudioPCMBuffer else { return }
            if pcm.frameLength == 0 {
                continuation.finish()
                return
            }
            if let chunk = TTSChunk(pcm) {
                continuation.yield(chunk)
            }
        }
    }

    /// `scheduleBuffer` completion: runs on a Core Audio thread, hands `action` the work for the main actor.
    nonisolated static func playedBackHandler(_ action: @escaping @Sendable () -> Void) -> @Sendable (AVAudioPlayerNodeCompletionCallbackType) -> Void {
        { _ in action() }
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
        Log.playback.info("Speak (\(language, privacy: .public)): \(text.count, privacy: .public) chars")

        synthesizer.write(utterance, toBufferCallback: Self.ttsBufferCallback(continuation))

        defer { endStream() }
        var chunkCount = 0
        for await chunk in stream {
            try schedule(chunk)
            chunkCount += 1
        }
        endOfSpeech() // A4: the resampler's tail belongs to this sentence
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

    private func bufferFinished(generation: Int, frames: Int) {
        guard generation == scheduleGeneration else { return }
        pendingBuffers = max(0, pendingBuffers - 1)
        queuedFrames = max(0, queuedFrames - frames)
        if pendingBuffers == 0 { drainedAt = Date() }
        updateSpeaking()
    }

    /// A4: drains the frames the sample-rate converter still holds (Apple's voice is not 24 kHz) and resets it, so
    /// they end this sentence instead of starting the next one (a click). Streamed 24 kHz audio passes straight
    /// through and has nothing held.
    func endOfSpeech() {
        guard let converter = ttsConverter,
              let output = AVAudioPCMBuffer(pcmFormat: playbackFormat, frameCapacity: 4_096) else { return }
        do {
            try converter.flush(into: output)
        } catch {
            Log.playback.error("TTS converter flush failed: \(error.localizedDescription, privacy: .public)")
            return
        }
        guard output.frameLength > 0 else { return }
        enqueue(output)
    }

    private func updateSpeaking() {
        let speaking = activeStreams > 0 || pendingBuffers > 0
        if speaking != isSpeaking { isSpeaking = speaking }
    }

    /// A7: the last answer's speech, as scheduled (at most `recordingLimitSeconds`).
    private var speechRecording: [TTSChunk] = []
    private var recordedSeconds: Double = 0
    private var isRecordingSpeech = false
    private var isReplaying = false
    static let recordingLimitSeconds: Double = 120

    func startRecordingSpeech() {
        speechRecording.removeAll()
        recordedSeconds = 0
        isRecordingSpeech = true
    }

    func stopRecordingSpeech() {
        isRecordingSpeech = false
    }

    func replayRecordedSpeech() throws(AudioError) -> Bool {
        let chunks = speechRecording
        guard !chunks.isEmpty else { return false }
        isReplaying = true
        defer { isReplaying = false }
        try graph.ensureRunning()
        if pendingBuffers == 0 { requestPlayback() }
        for chunk in chunks { try schedule(chunk) }
        endOfSpeech()
        return true
    }

    private func schedule(_ chunk: TTSChunk) throws(AudioError) {
        if isRecordingSpeech, !isReplaying, chunk.sampleRate > 0, recordedSeconds < Self.recordingLimitSeconds {
            speechRecording.append(chunk)
            recordedSeconds += Double(chunk.samples.count) / chunk.sampleRate
        }
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
        enqueue(output)
    }

    private func enqueue(_ output: AVAudioPCMBuffer) {
        pendingBuffers += 1
        let frames = Int(output.frameLength)
        queuedFrames += frames
        drainedAt = nil
        updateSpeaking()
        let generation = scheduleGeneration
        player.scheduleBuffer(output, completionCallbackType: .dataPlayedBack,
                              completionHandler: Self.playedBackHandler { [weak self] in
                                  Task { @MainActor in self?.bufferFinished(generation: generation, frames: frames) }
                              })
        if !player.isPlaying { player.play() }
        onAudioScheduled?()
    }

    private(set) var lastSlowStop: String?

    func stop() {
        // A72 part 3 (Toby T15b): a new question waited 8–20 s right here when nothing was playing. The synthesizer and
        // the player are only stopped when they have something to stop, and a slow stop is reported.
        let started = Date()
        if activeStreams > 0 { synthesizer.stopSpeaking(at: .immediate) }
        let synthesizerDone = Date()
        scheduleGeneration += 1
        if pendingBuffers > 0 { player.stop() }
        let synthesizerMs = Int(synthesizerDone.timeIntervalSince(started) * 1000)
        let playerMs = Int(Date().timeIntervalSince(synthesizerDone) * 1000)
        lastSlowStop = synthesizerMs + playerMs >= 200 ? "synthesizer \(synthesizerMs) ms, player \(playerMs) ms" : nil
        if let lastSlowStop { Log.playback.error("Slow stop: \(lastSlowStop, privacy: .public)") }
        pendingBuffers = 0
        queuedFrames = 0
        drainedAt = nil
        activeStreams = 0
        ttsConverter?.resetForNextStream()
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
