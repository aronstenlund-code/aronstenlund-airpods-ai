import Foundation
import Observation

/// Connects the capture session to a speech-to-text provider: Scribe when allowed (D44), else the best on-device
/// engine for the chosen language (D18 chain). Follows the session (start/stop/resume) and forwards results to the
/// Listening screen. A Scribe failure falls back to the phone for the rest of the listening run.
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
    /// Nil: on-device only.
    let settings: STTSettings?
    /// Why Scribe is not in use although it is switched on, shown with the status.
    private(set) var cloudFailure: String?
    weak var sink: (any TranscriptSink)?

    private let controller: SessionController
    private let probe: AvailabilityProbe
    private let makeProvider: ProviderFactory
    private var provider: (any STTProvider)?
    /// Prep topics (item 9), applied to the current provider and every later one.
    private(set) var contextualStrings: [String] = []
    /// True while our own speech plays in Provläge: capture chunks are dropped before the recogniser (D36).
    private(set) var isInputGated = false
    private var gateTask: Task<Void, Never>?

    func setInputGated(_ gated: Bool) {
        guard gated != isInputGated else { return }
        isInputGated = gated
        controller.log(gated ? "STT input gated (own speech)" : "STT input open")
    }
    private var resultsTask: Task<Void, Never>?
    private var lifecycleTask: Task<Void, Never>?
    private var chunkSubscription: UUID?
    private var generation = 0

    init(controller: SessionController,
         language: LanguageSettings,
         settings: STTSettings? = nil,
         probe: @escaping AvailabilityProbe = { candidates in await SpeechAvailabilityProbe.current(candidates: candidates) },
         makeProvider: @escaping ProviderFactory = { locale, engine in
             engine == .legacyOnDevice ? LegacySpeechProvider(locale: locale) : AppleSpeechProvider(locale: locale, engine: engine)
         }) {
        self.controller = controller
        self.language = language
        self.settings = settings
        self.probe = probe
        self.makeProvider = makeProvider
        controller.onCaptureStarted = { [weak self] in self?.captureStarted() }
        controller.onCaptureStopped = { [weak self] in self?.captureStopped() }
    }

    // MARK: - Session hooks

    func captureStarted() {
        cloudFailure = nil
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

        let engine: STTEngine
        if settings?.useCloud == true, cloudFailure == nil {
            engine = .scribe
        } else {
            status = .probing
            let availability = await probe(TranscriptionLanguage.allCases.map(\.locale))
            guard myGeneration == generation else { return }
            self.availability = availability

            guard let chosen = SpeechEngineSelector.choose(for: locale, availability: availability) else {
                status = .unavailable(selectedLanguage)
                controller.log("STT: no on-device engine for \(locale.identifier(.bcp47))")
                return
            }
            engine = chosen
        }

        let provider = makeProvider(locale, engine)
        provider.setContextualStrings(contextualStrings)
        status = .preparing(engine)
        do {
            try await provider.prepare()
        } catch {
            guard myGeneration == generation else { return }
            if engine == .scribe {
                await fallBackToDevice(error.localizedDescription)
                return
            }
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
        // Gate (D36): while the assistant speaks, its own voice must not reach the recogniser.
        let (gatedStream, gatedContinuation) = AsyncStream<AudioChunk>.makeStream(bufferingPolicy: .bufferingNewest(256))
        gateTask?.cancel()
        gateTask = Task { [weak self] in
            for await chunk in subscription.stream {
                guard let self else { break }
                if !self.isInputGated { gatedContinuation.yield(chunk) }
            }
            gatedContinuation.finish()
        }
        resultsTask = Task { [weak self] in
            for await result in provider.results {
                guard let self else { return }
                if result.isFinal {
                    self.sink?.receiveFinalTranscript(result.text, at: Date())
                } else {
                    self.sink?.receivePartialTranscript(result.text, at: Date())
                }
            }
            // Stopping changes the generation first, so reaching this with the same one means the socket died.
            guard let self, myGeneration == self.generation, engine == .scribe else { return }
            self.lifecycleTask = Task { await self.fallBackToDevice("connection lost") }
        }
        do {
            try await provider.start(audio: gatedStream)
            guard myGeneration == generation else { return }
            status = .running(engine)
            controller.log("STT running: \(engine.displayName) · \(locale.identifier(.bcp47))")
        } catch {
            guard myGeneration == generation else { return }
            if engine == .scribe {
                await fallBackToDevice(error.localizedDescription)
                return
            }
            status = .failed(error.localizedDescription)
            controller.log("STT start failed: \(error.localizedDescription)")
            await stopTranscribing()
        }
    }

    private func fallBackToDevice(_ reason: String) async {
        cloudFailure = reason
        controller.log("Scribe unavailable (\(reason)): using the iPhone's speech recognition")
        await startTranscribing()
    }

    /// Hold-to-ask released.
    func commit() {
        provider?.commit()
    }

    /// Switches between Scribe and the phone; a live session changes over at once.
    func setUseCloud(_ useCloud: Bool) async {
        settings?.useCloud = useCloud
        cloudFailure = nil
        if controller.isCapturing {
            await startTranscribing()
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
        gateTask?.cancel()
        gateTask = nil
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
        contextualStrings = Array(strings.prefix(100))
        provider?.setContextualStrings(contextualStrings)
    }
}
