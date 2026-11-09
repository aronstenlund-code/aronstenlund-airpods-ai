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
    /// Scribe's pause detection for the current mode (D78).
    private(set) var scribeTuning = ScribeTuning.standard
    /// Finals are joined into whole utterances (D78). False passes every final straight through (unit tests).
    let joinsUtterances: Bool
    /// The user's pause for the current mode (D80): the pending words are passed on when it is over.
    private(set) var pauseSeconds: TimeInterval = ModeSettings.defaultPause(for: .standard)
    /// After Scribe's own commit the rest of the pause; other engines wait the whole pause after their last result.
    var utteranceHold: TimeInterval {
        if case .running(.scribe) = status { return max(0.05, pauseSeconds - scribeTuning.silenceSeconds) }
        return pauseSeconds
    }
    private var assembler = UtteranceAssembler()
    /// The keyterms the running Scribe session was opened with, and when (D80).
    private var connectedKeyterms: [String] = []
    private var scribeStartedAt: Date?
    /// A8.5: Scribe refused the session (a bad keyterm closes it with 1008 `invalid_request`), so for the rest of this
    /// listening run it opens without keyterms instead of falling back to the phone.
    private(set) var scribeKeytermsDropped = false
    /// The keyterms a Scribe session opens with: sanitised (≤ 20 × ≤ 20 characters), or none after a refusal.
    var scribeKeyterms: [String] {
        scribeKeytermsDropped ? [] : ScribeKeyterms.sanitized(contextualStrings)
    }
    /// A Scribe session is reopened for new keyterms at most this often, and only in a quiet moment.
    static let keytermReconnectInterval: TimeInterval = 120
    private var flushTask: Task<Void, Never>?
    /// Silero before Scribe (D78). Nil: everything goes to the recogniser.
    let vad: VoiceActivityLoader?
    /// Local VAD statistics for the Diagnostics export: seconds sent to Scribe and seconds held back.
    private(set) var vadSentSeconds: Double = 0
    private(set) var vadHeldSeconds: Double = 0
    /// D82.2: the local VAD is running, and when it last heard speech.
    private(set) var vadIsRunning = false
    private(set) var vadLastSpeechAt: Date?
    /// Speech within this long counts as "someone is talking".
    static let vadTalkingWindow: TimeInterval = 0.4
    /// A10: the current mode wants only the wearer's voice (Provläge, Frågor), see `WearerFocus`.
    private(set) var modeFocusesOnWearer = true
    /// A10: seconds of other people's speech sent to Scribe as silence, and own ends of turn, for Diagnostics.
    private(set) var focusMutedSeconds: Double = 0
    private(set) var ownEndsOfTurn = 0
    /// A10: words heard but not committed yet, since when; and when the wearer last spoke.
    private var partialSince: Date?
    private var wearerSpokeAt: Date?
    private var commitRequestedAt: Date?

    /// D82.2: Silero, not the input level, says whether someone is talking, so background noise is not speech.
    /// Nil when no VAD runs (the caller falls back to the level).
    func vadSpeaking(now: Date = Date()) -> Bool? {
        guard vadIsRunning else { return nil }
        guard let last = vadLastSpeechAt else { return false }
        return now.timeIntervalSince(last) < Self.vadTalkingWindow
    }
    private var chunkSubscription: UUID?
    private var generation = 0

    init(controller: SessionController,
         language: LanguageSettings,
         settings: STTSettings? = nil,
         joinsUtterances: Bool = true,
         vad: VoiceActivityLoader? = nil,
         probe: @escaping AvailabilityProbe = { candidates in await SpeechAvailabilityProbe.current(candidates: candidates) },
         makeProvider: @escaping ProviderFactory = { locale, engine in
             engine == .legacyOnDevice ? LegacySpeechProvider(locale: locale) : AppleSpeechProvider(locale: locale, engine: engine)
         }) {
        self.controller = controller
        self.language = language
        self.settings = settings
        self.joinsUtterances = joinsUtterances
        self.vad = vad
        self.probe = probe
        self.makeProvider = makeProvider
        controller.onCaptureStarted = { [weak self] in self?.captureStarted() }
        controller.onCaptureStopped = { [weak self] in self?.captureStopped() }
    }

    // MARK: - Session hooks

    func captureStarted() {
        cloudFailure = nil
        scribeKeytermsDropped = false
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
        // Toby T1 finding 1 / A8: subscribe before the token and the socket, so the words said while Scribe
        // connects wait in the stream (up to 256 chunks, 10 s) instead of being lost.
        let subscription = controller.subscribeToChunks()
        chunkSubscription = subscription.id
        func dropSubscription() {
            if chunkSubscription == subscription.id {
                controller.unsubscribeFromChunks(subscription.id)
                chunkSubscription = nil
            }
        }
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
                dropSubscription()
                status = .unavailable(selectedLanguage)
                controller.log("STT: no on-device engine for \(locale.identifier(.bcp47))")
                return
            }
            engine = chosen
        }

        let provider = makeProvider(locale, engine)
        provider.setContextualStrings(engine == .scribe ? scribeKeyterms : contextualStrings)
        provider.setScribeTuning(scribeTuning)
        status = .preparing(engine)
        do {
            try await provider.prepare()
        } catch {
            guard myGeneration == generation else { return }
            if engine == .scribe {
                await fallBackToDevice(error.localizedDescription)
                return
            }
            dropSubscription()
            status = .failed(error.localizedDescription)
            controller.log("STT prepare failed: \(error.localizedDescription)")
            return
        }
        guard myGeneration == generation, controller.isCapturing else {
            dropSubscription()
            await provider.stop()
            return
        }

        self.provider = provider
        // Gate (D36): while the assistant speaks, its own voice must not reach the recogniser.
        let (gatedStream, gatedContinuation) = AsyncStream<AudioChunk>.makeStream(bufferingPolicy: .bufferingNewest(256))
        // D78: in front of Scribe, Silero lets only speech through. Not ready or switched off: everything goes.
        let usesGate = engine == .scribe && settings?.useLocalVAD == true
        if usesGate { vad?.loadIfNeeded() }
        let detector = usesGate ? vad?.detector : nil
        if usesGate {
            controller.log(detector == nil ? "Local VAD not ready: all audio goes to Scribe" : "Local VAD in front of Scribe")
        }
        let silence = scribeTuning.silenceSeconds
        let focuses = detector != nil && modeFocusesOnWearer && settings?.focusOnWearer == true
        if focuses { controller.log("Wearer focus in front of Scribe (A10)") }
        vadIsRunning = detector != nil
        vadLastSpeechAt = nil
        gateTask?.cancel()
        gateTask = Task { [weak self] in
            var gate = SpeechGate(scribeSilence: silence)
            var focus = WearerFocus()
            await detector?.reset()
            for await chunk in subscription.stream {
                guard let self else { break }
                if self.isInputGated { continue }
                guard let detector else {
                    gatedContinuation.yield(chunk)
                    continue
                }
                for window in gate.collect(chunk.samples) {
                    // A detector error lets the window through: VAD must never cost words.
                    var probability = (try? await detector.speechProbability(SpeechGate.floats(window))) ?? 1
                    var sent = window
                    if focuses {
                        let now = Date()
                        switch focus.judge(rmsDBFS: WearerFocus.rmsDBFS(window), probability: probability, at: now) {
                        case .other:
                            // Someone else: silence for Scribe, so the wearer's pause is a pause (A10).
                            sent = [Int16](repeating: 0, count: window.count)
                            probability = 0
                            self.focusMutedSeconds += SpeechGate.windowSeconds
                        case .wearer:
                            self.wearerSpokeAt = now
                        case .quiet:
                            break
                        }
                        self.endTurnIfScribeDoesNot(now: now)
                    }
                    if probability >= gate.openThreshold { self.vadLastSpeechAt = Date() }
                    let out = gate.decide(sent, probability: probability)
                    let windowSeconds = Double(window.count) / LumenAudioFormat.sampleRate
                    if out.isEmpty {
                        self.vadHeldSeconds += windowSeconds
                    } else {
                        self.vadSentSeconds += Double(out.count) / LumenAudioFormat.sampleRate
                        gatedContinuation.yield(AudioChunk(samples: out, hostTime: chunk.hostTime, firstSampleIndex: chunk.firstSampleIndex))
                    }
                }
            }
            gatedContinuation.finish()
        }
        let startedAt = Date()
        resultsTask = Task { [weak self] in
            for await result in provider.results {
                guard let self else { return }
                self.deliver(result)
            }
            // Stopping changes the generation first, so reaching this with the same one means the recogniser ended
            // by itself. D74: listening never stops by itself, so it starts again.
            guard let self, myGeneration == self.generation, self.controller.isCapturing else { return }
            let ranFor = Date().timeIntervalSince(startedAt)
            let refused = (provider as? ScribeProvider)?.endedAsInvalidRequest == true
            if engine == .scribe, !self.scribeKeytermsDropped, !self.connectedKeyterms.isEmpty,
               refused || ranFor < Self.reconnectAfter {
                // A8.5: a refused request (or a session that died at once with keyterms) is retried once without them.
                let reason = (provider as? ScribeProvider)?.endReason ?? "ended after \(Int(ranFor)) s"
                self.controller.log("Scribe refused the session (\(reason)): reopening without keyterms")
                self.scribeKeytermsDropped = true
                self.lifecycleTask = Task { await self.startTranscribing() }
            } else if engine == .scribe, ranFor >= Self.reconnectAfter {
                // A session limit or a dropped connection after a while: a new Scribe session, not the phone.
                self.controller.log("Scribe session ended after \(Int(ranFor)) s: reconnecting")
                self.lifecycleTask = Task { await self.startTranscribing() }
            } else if engine == .scribe {
                self.lifecycleTask = Task { await self.fallBackToDevice("connection lost") }
            } else if ranFor >= Self.reconnectAfter {
                self.controller.log("\(engine.displayName) ended after \(Int(ranFor)) s: restarting")
                self.lifecycleTask = Task {
                    try? await Task.sleep(for: .seconds(1))
                    await self.startTranscribing()
                }
            } else {
                self.status = .failed("\(engine.displayName) stopped")
                self.controller.log("\(engine.displayName) stopped after \(Int(ranFor)) s")
            }
        }
        do {
            try await provider.start(audio: gatedStream)
            guard myGeneration == generation else { return }
            status = .running(engine)
            if engine == .scribe {
                connectedKeyterms = scribeKeyterms
                scribeStartedAt = Date()
            }
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

    /// A10.2: own end of turn. Words wait uncommitted and the wearer has been quiet for the mode's pause (others may
    /// still talk): ask Scribe for the final now instead of waiting for a silence that does not come.
    private func endTurnIfScribeDoesNot(now: Date) {
        guard let since = partialSince, let spoke = wearerSpokeAt, spoke >= since.addingTimeInterval(-10),
              now.timeIntervalSince(spoke) >= pauseSeconds,
              commitRequestedAt.map({ now.timeIntervalSince($0) > 2 }) ?? true else { return }
        commitRequestedAt = now
        ownEndsOfTurn += 1
        controller.log("Wearer quiet for \(pauseSeconds) s, Scribe had not committed: final asked for (A10)")
        provider?.commit()
    }

    /// D78: finals become whole utterances before the question gate and the backend see them.
    private func deliver(_ result: STTResult) {
        if result.isFinal {
            partialSince = nil
        } else if partialSince == nil, !result.text.isEmpty {
            partialSince = Date()
        }
        guard joinsUtterances else {
            if result.isFinal {
                sink?.receiveFinalTranscript(result.text, at: Date())
            } else {
                sink?.receivePartialTranscript(result.text, at: Date())
            }
            return
        }
        if result.isFinal {
            for utterance in assembler.final(result.text) {
                sink?.receiveFinalTranscript(utterance, at: Date())
            }
            if let pending = assembler.pending {
                sink?.receivePartialTranscript(pending, at: Date())
                sink?.receiveSentenceHeard(pending, at: Date())
            }
        } else {
            sink?.receivePartialTranscript(assembler.display(partial: result.text), at: Date())
        }
        scheduleFlush()
    }

    /// No new words for `utteranceHold`: the speaker is done, so what is pending is one utterance.
    private func scheduleFlush() {
        flushTask?.cancel()
        guard assembler.pending != nil else { return }
        let hold = utteranceHold
        flushTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(hold))
            guard let self, !Task.isCancelled else { return }
            self.flushPending()
        }
    }

    private func flushPending() {
        flushTask?.cancel()
        flushTask = nil
        if let utterance = assembler.flush() {
            sink?.receiveFinalTranscript(utterance, at: Date())
        }
    }

    struct OnDeviceFailure: Error, Equatable {
        var message: String
    }

    /// Diagnostics (D78): runs the phone's best on-device recogniser on a recording, so it can be compared with what
    /// Scribe heard live on the same audio. Returns the engine's name and its final results.
    func transcribeOnDevice(_ samples: [Int16]) async -> Result<(String, [String]), OnDeviceFailure> {
        let locale = language.selected.locale
        let availability = await probe(TranscriptionLanguage.allCases.map(\.locale))
        guard let engine = SpeechEngineSelector.choose(for: locale, availability: availability) else {
            return .failure(OnDeviceFailure(message: "no on-device engine for \(locale.identifier(.bcp47))"))
        }
        let provider = makeProvider(locale, engine)
        do {
            try await provider.prepare()
        } catch {
            return .failure(OnDeviceFailure(message: error.localizedDescription))
        }
        let results = provider.results
        let collector = Task { () -> [String] in
            var finals: [String] = []
            for await result in results where result.isFinal {
                finals.append(result.text)
            }
            return finals
        }
        let (audio, input) = AsyncStream<AudioChunk>.makeStream(bufferingPolicy: .unbounded)
        do {
            try await provider.start(audio: audio)
        } catch {
            collector.cancel()
            return .failure(OnDeviceFailure(message: error.localizedDescription))
        }
        let step = Int(LumenAudioFormat.sampleRate * LumenAudioFormat.chunkDuration)
        var index = 0
        while index < samples.count {
            let end = min(samples.count, index + step)
            input.yield(AudioChunk(samples: Array(samples[index..<end]), hostTime: 0, firstSampleIndex: Int64(index)))
            index = end
            if index % (step * 25) == 0 { await Task.yield() }
        }
        input.finish()
        // Let the recogniser finish the last words, then stop it; stopping ends `results`.
        try? await Task.sleep(for: .seconds(4))
        await provider.stop()
        let finals = await collector.value
        controller.log("On-device pass on a recording: \(engine.displayName), \(finals.count) results")
        return .success((engine.displayName, finals))
    }

    /// D80: the topic changed the keyterms; Scribe only takes them when a session opens, so in a quiet moment (the
    /// caller checks) and at most every two minutes the session is reopened with them.
    func applyKeytermsIfQuiet() async {
        guard case .running(.scribe) = status, controller.isCapturing,
              !scribeKeytermsDropped, scribeKeyterms != connectedKeyterms,
              let started = scribeStartedAt, Date().timeIntervalSince(started) >= Self.keytermReconnectInterval else { return }
        controller.log("Scribe keyterms changed: reconnecting in a pause")
        await startTranscribing()
    }

    /// D87: Provläge starts: a running Scribe session takes the exam's keyterms now, before the first word (no wait
    /// for a pause; the user has not started yet).
    func applyKeytermsNow() async {
        guard case .running(.scribe) = status, controller.isCapturing,
              !scribeKeytermsDropped, scribeKeyterms != connectedKeyterms else { return }
        controller.log("Scribe keyterms for the exam: reconnecting")
        await startTranscribing()
    }

    /// The mode or its pause changed (D80): Scribe commits a little before the pause is over, and a running Scribe
    /// session reconnects with the new values.
    func setPause(_ seconds: TimeInterval, mode: ConversationMode) async {
        pauseSeconds = seconds
        let focus = mode == .prov || mode == .standard
        if focus != modeFocusesOnWearer {
            modeFocusesOnWearer = focus
            if case .running(.scribe) = status, controller.isCapturing, scribeTuning == .forMode(mode, pause: seconds) {
                await startTranscribing() // the tuning below reconnects otherwise
            }
        }
        await setScribeTuning(.forMode(mode, pause: seconds))
    }

    /// The mode changed (D78): a running Scribe session reconnects with that mode's pause detection.
    func setScribeTuning(_ tuning: ScribeTuning) async {
        guard tuning != scribeTuning else { return }
        scribeTuning = tuning
        if case .running(.scribe) = status, controller.isCapturing {
            controller.log("Scribe pause detection \(tuning.silenceSeconds) s: reconnecting")
            await startTranscribing()
        }
    }

    /// A10: the wearer focus on or off; a running Scribe session changes over at once.
    func setFocusOnWearer(_ on: Bool) async {
        settings?.focusOnWearer = on
        if case .running(.scribe) = status, controller.isCapturing {
            await startTranscribing()
        }
    }

    /// Switches the local VAD on or off; a running Scribe session changes over at once.
    func setUseLocalVAD(_ on: Bool) async {
        settings?.useLocalVAD = on
        if case .running(.scribe) = status, controller.isCapturing {
            await startTranscribing()
        }
    }

    /// A recogniser that ran at least this long and then ended is started again (D74); one that ends at once is a
    /// failure, not a session limit, and is not retried in a loop.
    static let reconnectAfter: TimeInterval = 20

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
        scribeKeytermsDropped = false
        if controller.isCapturing {
            await startTranscribing()
        }
    }

    /// All state changes happen before the first suspension, so a `startTranscribing()` that begins while an
    /// older stop is still finalising its provider is never invalidated by it.
    func stopTranscribing() async {
        vadIsRunning = false
        partialSince = nil
        if focusMutedSeconds > 0 || ownEndsOfTurn > 0 {
            controller.log("Wearer focus: \(Int(focusMutedSeconds)) s of others muted, \(ownEndsOfTurn) own ends of turn")
        }
        flushPending() // words heard before the stop are not lost
        assembler.reset()
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
