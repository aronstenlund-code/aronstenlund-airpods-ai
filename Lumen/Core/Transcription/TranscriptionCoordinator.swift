import Foundation
import Observation

/// Connects the capture session to a speech-to-text provider: picks the engine for the chosen language (D18
/// chain), follows the session (start/stop/resume), and forwards results to the Listening screen.
@MainActor
@Observable
final class TranscriptionCoordinator {
    enum Status: Equatable, Sendable {
        case idle
        case probing
        case preparing(STTEngine)
        case running(STTEngine)
        /// No on-device engine supports the chosen language on this iPhone.
        case unavailable(TranscriptionLanguage)
        case failed(String)

        var isRunning: Bool {
            if case .running = self { return true }
            return false
        }
    }

    typealias ProviderFactory = @MainActor (Locale, STTEngine) -> any STTProvider
    typealias AvailabilityProbe = @MainActor ([Locale]) async -> SpeechEngineAvailability

    private(set) var status: Status = .idle
    private(set) var availability: SpeechEngineAvailability?
    let language: LanguageSettings
    weak var sink: (any TranscriptSink)?

    private let controller: SessionController
    private let probe: AvailabilityProbe
    private let makeProvider: ProviderFactory
    private var provider: (any STTProvider)?
    private var resultsTask: Task<Void, Never>?
    private var lifecycleTask: Task<Void, Never>?
    private var chunkSubscription: UUID?
    private var generation = 0

    init(controller: SessionController,
         language: LanguageSettings,
         probe: @escaping AvailabilityProbe = { candidates in await SpeechAvailabilityProbe.current(candidates: candidates) },
         makeProvider: @escaping ProviderFactory = { locale, engine in
             engine == .legacyOnDevice ? LegacySpeechProvider(locale: locale) : AppleSpeechProvider(locale: locale, engine: engine)
         }) {
        self.controller = controller
        self.language = language
        self.probe = probe
        self.makeProvider = makeProvider
        controller.onCaptureStarted = { [weak self] in self?.captureStarted() }
        controller.onCaptureStopped = { [weak self] in self?.captureStopped() }
    }

    // MARK: - Session hooks

    func captureStarted() {
        lifecycleTask?.cancel()
        lifecycleTask = Task { await startTranscribing() }
    }

    func captureStopped() {
        lifecycleTask?.cancel()
        lifecycleTask = Task { await stopTranscribing() }
    }

    // MARK: - Control

    /// Picks an engine for the selected language, prepares it (model download on first use) and starts it on
    /// the live chunk stream. Safe to call again: the previous provider is stopped first.
    func startTranscribing() async {
        await stopTranscribing()
        generation += 1
        let myGeneration = generation
        let selectedLanguage = language.selected
        let locale = selectedLanguage.locale

        status = .probing
        let availability = await probe(TranscriptionLanguage.allCases.map(\.locale))
        guard myGeneration == generation else { return }
        self.availability = availability

        guard let engine = SpeechEngineSelector.choose(for: locale, availability: availability) else {
            status = .unavailable(selectedLanguage)
            controller.log("STT: no on-device engine for \(locale.identifier(.bcp47))")
            return
        }

        let provider = makeProvider(locale, engine)
        status = .preparing(engine)
        do {
            try await provider.prepare()
        } catch {
            guard myGeneration == generation else { return }
            status = .failed(error.localizedDescription)
            controller.log("STT prepare failed: \(error.localizedDescription)")
            return
        }
        guard myGeneration == generation, controller.isCapturing else {
            await provider.stop()
            return
        }

        self.provider = provider
        let subscription = controller.subscribeToChunks()
        chunkSubscription = subscription.id
        resultsTask = Task { [weak self] in
            for await result in provider.results {
                guard let self else { return }
                if result.isFinal {
                    self.sink?.receiveFinalTranscript(result.text, at: Date())
                } else {
                    self.sink?.receivePartialTranscript(result.text, at: Date())
                }
            }
        }
        do {
            try await provider.start(audio: subscription.stream)
            guard myGeneration == generation else { return }
            status = .running(engine)
            controller.log("STT running: \(engine.displayName) · \(locale.identifier(.bcp47))")
        } catch {
            guard myGeneration == generation else { return }
            status = .failed(error.localizedDescription)
            controller.log("STT start failed: \(error.localizedDescription)")
            await stopTranscribing()
        }
    }

    /// All state changes happen before the first suspension, so a `startTranscribing()` that begins while an
    /// older stop is still finalising its provider is never invalidated by it.
    func stopTranscribing() async {
        generation += 1
        let stopping = provider
        provider = nil
        if let id = chunkSubscription {
            controller.unsubscribeFromChunks(id)
            chunkSubscription = nil
        }
        resultsTask?.cancel()
        resultsTask = nil
        switch status {
        case .running, .preparing, .probing: status = .idle
        case .idle, .unavailable, .failed: break
        }
        if let stopping {
            await stopping.stop()
        }
    }

    /// Persists the language and restarts recognition if a session is live.
    func setLanguage(_ newLanguage: TranscriptionLanguage) async {
        guard newLanguage != language.selected else { return }
        language.selected = newLanguage
        controller.log("Language set to \(newLanguage.rawValue)")
        if controller.isCapturing {
            await startTranscribing()
        } else if case .unavailable = status {
            status = .idle
        }
    }

    /// Prep topics (item 9) for the current and future providers.
    func setContextualStrings(_ strings: [String]) {
        provider?.setContextualStrings(strings)
    }
}
