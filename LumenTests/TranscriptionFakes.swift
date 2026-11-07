import Foundation
@testable import Lumen

/// In-memory STT engine: records calls, lets tests emit results and inspect the audio it was fed.
@MainActor
final class FakeSTTProvider: STTProvider {
    let engine: STTEngine
    let locale: Locale
    let results: AsyncStream<STTResult>
    let emit: AsyncStream<STTResult>.Continuation

    var prepareError: STTError?
    var startError: STTError?
    private(set) var prepareCalls = 0
    private(set) var startCalls = 0
    private(set) var stopCalls = 0
    private(set) var contextualStrings: [String] = []
    private(set) var receivedChunks: [AudioChunk] = []
    private var feedTask: Task<Void, Never>?

    init(locale: Locale, engine: STTEngine) {
        self.locale = locale
        self.engine = engine
        let (stream, continuation) = AsyncStream<STTResult>.makeStream()
        results = stream
        emit = continuation
    }

    func prepare() async throws(STTError) {
        prepareCalls += 1
        if let prepareError { throw prepareError }
    }

    func start(audio: AsyncStream<AudioChunk>) async throws(STTError) {
        startCalls += 1
        if let startError { throw startError }
        feedTask = Task { [weak self] in
            for await chunk in audio {
                self?.receivedChunks.append(chunk)
            }
        }
    }

    func stop() async {
        stopCalls += 1
        feedTask?.cancel()
        feedTask = nil
        emit.finish()
    }

    func setContextualStrings(_ strings: [String]) {
        contextualStrings = strings
    }
}

@MainActor
final class FakeTranscriptSink: TranscriptSink {
    private(set) var partials: [String] = []
    private(set) var finals: [String] = []

    func receivePartialTranscript(_ text: String, at date: Date) { partials.append(text) }
    func receiveFinalTranscript(_ text: String, at date: Date) { finals.append(text) }
}

/// What the coordinator's injected closures see; created before the coordinator so the closures can capture it.
@MainActor
final class ProviderRecorder {
    var availability = SpeechEngineAvailability(speechTranscriberLocales: ["sv-se", "en-us"],
                                                dictationLocales: ["sv-se", "en-us"],
                                                legacyOnDeviceLocales: [])
    var prepareError: STTError?
    var startError: STTError?
    private(set) var created: [FakeSTTProvider] = []

    func make(locale: Locale, engine: STTEngine) -> FakeSTTProvider {
        let provider = FakeSTTProvider(locale: locale, engine: engine)
        provider.prepareError = prepareError
        provider.startError = startError
        created.append(provider)
        return provider
    }
}

@MainActor
struct CoordinatorHarness {
    let session = ControllerHarness()
    let recorder = ProviderRecorder()
    let sink = FakeTranscriptSink()
    let defaults: UserDefaults
    let language: LanguageSettings
    let coordinator: TranscriptionCoordinator

    init(language selected: TranscriptionLanguage = .swedish, availability: SpeechEngineAvailability? = nil) {
        let suite = "lumen.tests.transcription.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        language = LanguageSettings(defaults: defaults, systemLocale: Locale(identifier: "sv_SE"))
        language.selected = selected
        if let availability { recorder.availability = availability }
        let recorder = self.recorder
        coordinator = TranscriptionCoordinator(controller: session.controller, language: language,
                                               probe: { _ in recorder.availability },
                                               makeProvider: { locale, engine in recorder.make(locale: locale, engine: engine) })
        coordinator.sink = sink
    }

    var provider: FakeSTTProvider? { recorder.created.first }
}

/// A coordinator that never finds a speech engine — for tests that only need a `ListeningModel`.
@MainActor
func makeTestCoordinator(_ controller: SessionController) -> TranscriptionCoordinator {
    let suite = "lumen.tests.listening.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    return TranscriptionCoordinator(controller: controller,
                                    language: LanguageSettings(defaults: defaults, systemLocale: Locale(identifier: "sv_SE")),
                                    utteranceHold: 0,
                                    probe: { _ in .nothing },
                                    makeProvider: { locale, engine in FakeSTTProvider(locale: locale, engine: engine) })
}

/// Polls `condition` on the main actor until it holds or `timeout` passes.
@MainActor
func waitUntil(timeout: Duration = .seconds(3), _ condition: @MainActor () -> Bool) async -> Bool {
    let deadline = ContinuousClock.now + timeout
    while !condition() {
        if ContinuousClock.now > deadline { return false }
        try? await Task.sleep(for: .milliseconds(10))
    }
    return true
}
