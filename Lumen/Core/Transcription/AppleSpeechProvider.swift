import AVFAudio
import CoreMedia
import Foundation
import Speech

/// `SpeechAnalyzer`-based provider (iOS 26): `SpeechTranscriber` or `DictationTranscriber`, on device.
/// Our 16 kHz Int16 chunks are converted to the analyzer's preferred format and fed as `AnalyzerInput`.
@MainActor
final class AppleSpeechProvider: STTProvider {
    let engine: STTEngine
    let locale: Locale
    let results: AsyncStream<STTResult>

    private let resultsContinuation: AsyncStream<STTResult>.Continuation
    private var contextualStrings: [String] = []
    private var analyzer: SpeechAnalyzer?
    private var inputBuilder: AsyncStream<AnalyzerInput>.Continuation?
    private var converter: PCMConverter?
    private var resultsTask: Task<Void, Never>?
    private var feedTask: Task<Void, Never>?
    private(set) var conversionErrors = 0
    /// Download progress of the speech model while `prepare()` installs it, else nil.
    private(set) var installProgress: Progress?

    private enum Module {
        case transcriber(SpeechTranscriber)
        case dictation(DictationTranscriber)

        var speechModule: any SpeechModule {
            switch self {
            case .transcriber(let module): module
            case .dictation(let module): module
            }
        }
    }

    init(locale: Locale, engine: STTEngine) {
        precondition(engine != .legacyOnDevice, "use LegacySpeechProvider for SFSpeechRecognizer")
        self.locale = locale
        self.engine = engine
        let (stream, continuation) = AsyncStream<STTResult>.makeStream(bufferingPolicy: .bufferingNewest(64))
        self.results = stream
        self.resultsContinuation = continuation
    }

    private func makeModule() -> Module {
        switch engine {
        case .dictationTranscriber:
            .dictation(DictationTranscriber(locale: locale,
                                            contentHints: [],
                                            transcriptionOptions: [],
                                            reportingOptions: [.volatileResults],
                                            attributeOptions: [.audioTimeRange]))
        case .speechTranscriber, .legacyOnDevice:
            .transcriber(SpeechTranscriber(locale: locale,
                                           transcriptionOptions: [],
                                           reportingOptions: [.volatileResults],
                                           attributeOptions: [.audioTimeRange]))
        }
    }

    // MARK: - STTProvider

    func prepare() async throws(STTError) {
        let module = makeModule()
        do {
            if let request = try await AssetInventory.assetInstallationRequest(supporting: [module.speechModule]) {
                installProgress = request.progress
                Log.transcription.info("Installing speech model for \(self.locale.identifier(.bcp47), privacy: .public)")
                try await request.downloadAndInstall()
                installProgress = nil
            }
        } catch {
            installProgress = nil
            throw STTError.modelInstallFailed(detail: String(describing: error))
        }
    }

    func start(audio: AsyncStream<AudioChunk>) async throws(STTError) {
        await stop()
        let module = makeModule()
        let speechModule = module.speechModule

        guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [speechModule]) else {
            throw STTError.audioFormat(detail: "no analyzer audio format for \(engine.displayName)")
        }
        do {
            converter = try PCMConverter(from: LumenAudioFormat.pcm16kMono(), to: format)
        } catch {
            throw STTError.audioFormat(detail: error.localizedDescription)
        }

        let analyzer = SpeechAnalyzer(modules: [speechModule])
        self.analyzer = analyzer
        if !contextualStrings.isEmpty {
            let context = AnalysisContext()
            context.contextualStrings = [.general: contextualStrings]
            do {
                try await analyzer.setContext(context)
            } catch {
                Log.transcription.error("setContext failed: \(String(describing: error), privacy: .public)")
            }
        }

        let (inputSequence, inputBuilder) = AsyncStream<AnalyzerInput>.makeStream()
        self.inputBuilder = inputBuilder

        let continuation = resultsContinuation
        resultsTask = Task {
            do {
                switch module {
                case .transcriber(let transcriber):
                    for try await result in transcriber.results {
                        continuation.yield(Self.map(result.text, isFinal: result.isFinal, range: result.range))
                    }
                case .dictation(let dictation):
                    for try await result in dictation.results {
                        continuation.yield(Self.map(result.text, isFinal: result.isFinal, range: result.range))
                    }
                }
            } catch {
                Log.transcription.error("results stream ended with error: \(String(describing: error), privacy: .public)")
            }
        }

        do {
            try await analyzer.start(inputSequence: inputSequence)
        } catch {
            resultsTask?.cancel()
            self.analyzer = nil
            throw STTError.startFailed(detail: String(describing: error))
        }

        feedTask = Task { [weak self] in
            for await chunk in audio {
                self?.feed(chunk)
            }
            self?.inputBuilder?.finish()
        }
        Log.transcription.info("\(self.engine.displayName, privacy: .public) started · \(self.locale.identifier(.bcp47), privacy: .public) · analyzer format \(LumenAudioFormat.describe(format), privacy: .public)")
    }

    func stop() async {
        feedTask?.cancel()
        feedTask = nil
        inputBuilder?.finish()
        inputBuilder = nil
        if let analyzer {
            self.analyzer = nil
            let finish = Task { try await analyzer.finalizeAndFinishThroughEndOfInput() }
            let watchdog = Task {
                try await Task.sleep(for: .seconds(5))
                finish.cancel()
            }
            do {
                try await finish.value
            } catch {
                Log.transcription.error("finalize: \(String(describing: error), privacy: .public)")
            }
            watchdog.cancel()
        }
        resultsTask?.cancel()
        resultsTask = nil
        converter = nil
    }

    func setContextualStrings(_ strings: [String]) {
        contextualStrings = Array(strings.prefix(100))
    }

    // MARK: - Feeding

    private func feed(_ chunk: AudioChunk) {
        guard let converter, let inputBuilder else { return }
        let frames = AVAudioFrameCount(chunk.samples.count)
        guard frames > 0,
              let input = AVAudioPCMBuffer(pcmFormat: converter.inputFormat, frameCapacity: frames),
              let channel = input.int16ChannelData else { return }
        input.frameLength = frames
        chunk.samples.withUnsafeBufferPointer { source in
            if let base = source.baseAddress {
                channel[0].update(from: base, count: Int(frames))
            }
        }
        guard let output = AVAudioPCMBuffer(pcmFormat: converter.outputFormat,
                                            frameCapacity: converter.outputCapacity(forInputFrames: frames)) else { return }
        do {
            let written = try converter.convert(input, into: output)
            if written > 0 {
                inputBuilder.yield(AnalyzerInput(buffer: output))
            }
        } catch {
            conversionErrors += 1
        }
    }

    private static func map(_ text: AttributedString, isFinal: Bool, range: CMTimeRange) -> STTResult {
        STTResult(text: String(text.characters),
                  isFinal: isFinal,
                  audioStart: range.start.isNumeric ? range.start.seconds : nil,
                  audioEnd: range.end.isNumeric ? range.end.seconds : nil)
    }
}
