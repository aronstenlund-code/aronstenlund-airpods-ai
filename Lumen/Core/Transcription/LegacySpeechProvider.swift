import AVFAudio
import Foundation
import Speech

/// Last link of the D18 chain: `SFSpeechRecognizer` restricted to on-device recognition
/// (`requiresOnDeviceRecognition = true`, D22) so the consent promise "audio never leaves the phone" holds.
@MainActor
final class LegacySpeechProvider: STTProvider {
    let engine: STTEngine = .legacyOnDevice
    let locale: Locale
    let results: AsyncStream<STTResult>

    private let resultsContinuation: AsyncStream<STTResult>.Continuation
    private var contextualStrings: [String] = []
    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var feedTask: Task<Void, Never>?

    init(locale: Locale) {
        self.locale = locale
        let (stream, continuation) = AsyncStream<STTResult>.makeStream(bufferingPolicy: .bufferingNewest(64))
        self.results = stream
        self.resultsContinuation = continuation
    }

    func prepare() async throws(STTError) {
        let identifier = locale.identifier(.bcp47)
        guard let recognizer = SFSpeechRecognizer(locale: locale) else {
            throw STTError.languageUnsupported(locale: identifier)
        }
        guard recognizer.supportsOnDeviceRecognition else {
            throw STTError.onDeviceUnavailable(locale: identifier)
        }
        self.recognizer = recognizer
        let status = await Self.requestAuthorization()
        guard status == .authorized else { throw STTError.authorizationDenied }
    }

    func start(audio: AsyncStream<AudioChunk>) async throws(STTError) {
        await stop()
        guard let recognizer, recognizer.isAvailable else {
            throw STTError.startFailed(detail: "recognizer not available")
        }
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = true
        if !contextualStrings.isEmpty {
            request.contextualStrings = contextualStrings
        }
        self.request = request

        task = recognizer.recognitionTask(with: request, resultHandler: Self.resultHandler(resultsContinuation))

        feedTask = Task { [weak self] in
            for await chunk in audio {
                self?.append(chunk)
            }
            self?.request?.endAudio()
        }
        Log.transcription.info("on-device SFSpeechRecognizer started · \(self.locale.identifier(.bcp47), privacy: .public)")
    }

    // Speech calls these on its own queues. Made outside the main actor so they carry no main-actor isolation,
    // which Swift 6 would trap on at run time (the capture crash of 2026-11-07).

    nonisolated static func requestAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { (continuation: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
    }

    nonisolated static func resultHandler(_ continuation: AsyncStream<STTResult>.Continuation) -> @Sendable (SFSpeechRecognitionResult?, (any Error)?) -> Void {
        { result, error in
            if let result {
                continuation.yield(STTResult(text: result.bestTranscription.formattedString,
                                             isFinal: result.isFinal,
                                             audioStart: nil,
                                             audioEnd: nil))
            }
            if let error {
                Log.transcription.error("SFSpeechRecognizer: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    func stop() async {
        feedTask?.cancel()
        feedTask = nil
        request?.endAudio()
        task?.finish()
        task = nil
        request = nil
    }

    func setContextualStrings(_ strings: [String]) {
        contextualStrings = Array(strings.prefix(100))
    }

    private func append(_ chunk: AudioChunk) {
        guard let request else { return }
        let frames = AVAudioFrameCount(chunk.samples.count)
        guard frames > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: LumenAudioFormat.pcm16kMono(), frameCapacity: frames),
              let channel = buffer.int16ChannelData else { return }
        buffer.frameLength = frames
        chunk.samples.withUnsafeBufferPointer { source in
            if let base = source.baseAddress {
                channel[0].update(from: base, count: Int(frames))
            }
        }
        request.append(buffer)
    }
}
