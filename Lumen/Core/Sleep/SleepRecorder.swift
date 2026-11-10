@preconcurrency import AVFoundation
import Foundation
import SoundAnalysis
@preconcurrency import Speech

/// A49 (D123): listens all night on the phone. Apple's sound classifier (SoundAnalysis, on the device) tells speech,
/// snoring and other noises apart; speech is kept as a clip (1.5 s before it starts, until 2 s of quiet, at most 30 s)
/// and written out word for word by the phone's own speech recognition (`requiresOnDeviceRecognition`). Nothing
/// leaves the phone. The microphone indicator stays on all night (iOS), and "Vakna" stops everything.
///
/// The audio thread only copies buffers; the analysis and the files run on one serial queue. The class is
/// `@unchecked Sendable` because every mutable property is touched only on that queue (documented per property).
final class SleepRecorder: NSObject, @unchecked Sendable {
    enum Event: Sendable {
        case talk(at: Date, seconds: Double, file: URL)
        case snore(at: Date, seconds: Double)
        case noise(at: Date)
    }

    static let preRoll: TimeInterval = 1.5
    static let quietEnd: TimeInterval = 2
    static let maxClip: TimeInterval = 30
    static let speechConfidence = 0.7
    static let snoreConfidence = 0.6
    static let noiseConfidence = 0.6
    static let calmLabels: Set<String> = ["silence", "speech", "snoring", "breathing", "speech_synthesizer", "music"]

    private let engine = AVAudioEngine()
    private let queue = DispatchQueue(label: "lumen.sleep")
    private let folder: URL
    private let onEvent: @Sendable (Event) -> Void
    // On `queue` only:
    private var analyzer: SNAudioStreamAnalyzer?
    private var framePosition: AVAudioFramePosition = 0
    private var format: AVAudioFormat?
    private var preBuffers: [AVAudioPCMBuffer] = []
    private var clip: AVAudioFile?
    private var clipURL: URL?
    private var clipStart: Date?
    private var lastSpeech: Date?
    private var speaking = false

    init(folder: URL, onEvent: @escaping @Sendable (Event) -> Void) {
        self.folder = folder
        self.onEvent = onEvent
    }

    func start() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: [])
        try session.setActive(true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        let analyzer = SNAudioStreamAnalyzer(format: format)
        let request = try SNClassifySoundRequest(classifierIdentifier: .version1)
        try analyzer.add(request, withObserver: self)
        queue.sync {
            self.format = format
            self.analyzer = analyzer
        }
        input.installTap(onBus: 0, bufferSize: 8192, format: format) { [weak self] buffer, _ in
            guard let self, let copy = Self.copy(buffer) else { return }
            self.queue.async { self.process(copy) }
        }
        engine.prepare()
        try engine.start()
    }

    func stop() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        queue.sync {
            self.analyzer?.completeAnalysis()
            self.analyzer = nil
            self.finishClip(at: Date())
        }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: On the queue

    private func process(_ buffer: AVAudioPCMBuffer) {
        analyzer?.analyze(buffer, atAudioFramePosition: framePosition)
        framePosition += AVAudioFramePosition(buffer.frameLength)
        if let clip {
            try? clip.write(from: buffer)
            let now = Date()
            if let start = clipStart, now.timeIntervalSince(start) > Self.maxClip { finishClip(at: now) }
            else if let last = lastSpeech, !speaking, now.timeIntervalSince(last) > Self.quietEnd { finishClip(at: now) }
        } else {
            preBuffers.append(buffer)
            let seconds = preBuffers.reduce(0.0) { $0 + Double($1.frameLength) / $1.format.sampleRate }
            if seconds > Self.preRoll, preBuffers.count > 1 { preBuffers.removeFirst() }
        }
    }

    private func speechHeard(at now: Date) {
        lastSpeech = now
        speaking = true
        guard clip == nil, let format else { return }
        let url = folder.appendingPathComponent("talk-\(Int(now.timeIntervalSince1970)).caf")
        guard let file = try? AVAudioFile(forWriting: url, settings: format.settings) else { return }
        for buffer in preBuffers { try? file.write(from: buffer) }
        preBuffers = []
        clip = file
        clipURL = url
        clipStart = now.addingTimeInterval(-Self.preRoll)
    }

    private func finishClip(at now: Date) {
        guard let url = clipURL, let start = clipStart else { return }
        clip = nil
        clipURL = nil
        clipStart = nil
        speaking = false
        onEvent(.talk(at: start, seconds: now.timeIntervalSince(start), file: url))
    }

    private static func copy(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let copy = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: buffer.frameLength) else { return nil }
        copy.frameLength = buffer.frameLength
        let channels = Int(buffer.format.channelCount)
        if let from = buffer.floatChannelData, let to = copy.floatChannelData {
            for channel in 0..<channels { to[channel].update(from: from[channel], count: Int(buffer.frameLength)) }
        } else if let from = buffer.int16ChannelData, let to = copy.int16ChannelData {
            for channel in 0..<channels { to[channel].update(from: from[channel], count: Int(buffer.frameLength)) }
        }
        return copy
    }

    /// The words in a clip, on the phone only. Nil when nothing could be made out (or no Swedish on-device model).
    static func transcribe(_ url: URL, locale: Locale = Locale(identifier: "sv-SE")) async -> String? {
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.supportsOnDeviceRecognition else { return nil }
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = false
        return await withCheckedContinuation { continuation in
            let once = Once()
            recognizer.recognitionTask(with: request) { result, error in
                if let result, result.isFinal {
                    let text = result.bestTranscription.formattedString.trimmingCharacters(in: .whitespacesAndNewlines)
                    once.run { continuation.resume(returning: text.isEmpty ? nil : text) }
                } else if error != nil {
                    once.run { continuation.resume(returning: nil) }
                }
            }
        }
    }
}

extension SleepRecorder: SNResultsObserving {
    func request(_ request: any SNRequest, didProduce result: any SNResult) {
        guard let result = result as? SNClassificationResult else { return }
        let now = Date()
        // Called on the analyzer's thread, which is `queue` (analyze runs there).
        if let speech = result.classification(forIdentifier: "speech"), speech.confidence >= Self.speechConfidence {
            speechHeard(at: now)
        } else {
            speaking = false
        }
        if let snore = result.classification(forIdentifier: "snoring"), snore.confidence >= Self.snoreConfidence {
            onEvent(.snore(at: now, seconds: result.timeRange.duration.seconds / 2)) // windows overlap by half
        }
        if let top = result.classifications.first, top.confidence >= Self.noiseConfidence, !Self.calmLabels.contains(top.identifier) {
            onEvent(.noise(at: now))
        }
    }
}

/// Resumes a continuation once, whatever the recogniser calls back with.
private final class Once: @unchecked Sendable {
    private let lock = NSLock()
    private var done = false

    func run(_ body: () -> Void) {
        lock.lock()
        defer { lock.unlock() }
        guard !done else { return }
        done = true
        body()
    }
}
