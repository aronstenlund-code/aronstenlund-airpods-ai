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

    private(set) var status: Status = .idle {
        didSet { if status != oldValue { onStatusChanged?(status) } }
    }
    /// A11: the listening screen must never say "Lyssnar" while nothing transcribes.
    var onStatusChanged: (@MainActor (Status) -> Void)?
    /// A11: Scribe is tried again after a failure, 1, 2, 4 … 30 s apart, as long as capture runs, also after the
    /// phone's own recogniser failed.
    private(set) var scribeRetryAttempt = 0
    private var retryTask: Task<Void, Never>?
    static let maxRetryDelay: TimeInterval = 30

    static func retryDelay(attempt: Int) -> TimeInterval {
        min(maxRetryDelay, pow(2, Double(max(0, attempt - 1))))
    }
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
    /// A29 (Toby T7): told every time the recogniser closes (true) or opens (false).
    @ObservationIgnored var onInputGate: (@MainActor (Bool) -> Void)?

    func setInputGated(_ gated: Bool) {
        guard gated != isInputGated else { return }
        isInputGated = gated
        controller.log(gated ? "STT input gated (own speech)" : "STT input open")
        onInputGate?(gated)
        // A56 (Toby T5b finding 1): words that waited uncommitted while Lumen spoke are looked at again now. Before,
        // the stale timer gave up while the input was gated and the words waited for Scribe to end its session
        // (12–22 s after the question).
        if !gated, hasWaitingWords {
            controller.log("Words waited while Lumen spoke: the final is looked for again (A56)")
            scheduleStaleCommit()
        }
    }

    /// Words heard that Scribe has not committed yet (someone is in the middle of saying something).
    var hasWaitingWords: Bool { partialSince != nil && !lastPartialText.isEmpty }
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
    /// A14: when someone else's speech was last muted; the forced final is only for a turn drowned in chatter.
    private var otherSpokeAt: Date?
    private var commitRequestedAt: Date?
    /// A21.4 (Toby T5 finding 4): words that stay uncommitted after the speaker went quiet. Scribe is asked for the
    /// final; if none comes, the last partial is used as the final. A question never waits for the session to close.
    private var staleTask: Task<Void, Never>?
    private var lastPartialText = ""
    /// The partial used as a final, so Scribe's own final (or partials) of the same words later are not a new turn.
    private var usedPartial: (key: String, at: Date)?
    /// A56: when the VAD first held a stale final back, and when the final was last asked for (to log Scribe's reply).
    private var staleDeferredSince: Date?
    /// A74 (K42.5): how long the last final was spoken (first heard word to the last change), nil without partials.
    private(set) var lastUtteranceSeconds: Double?
    private var lastPartialChangeAt: Date?
    /// A63: how many uncommitted runs of words began this session (only the first 30 are logged).
    private var partialsSeen = 0
    private var staleCommitAskedAt: Date?
    /// A21.4: how often the final was asked for, and how often the partial had to be used, for Diagnostics.
    private(set) var staleCommits = 0
    private(set) var partialsUsedAsFinal = 0
    /// No new words for the pause plus this: the speaker is done, ask Scribe for its final.
    static let staleMargin: TimeInterval = 0.8
    /// No final this long after asking for it: the last partial is the final.
    static let commitWait: TimeInterval = 1.5
    /// A56: the VAD may hold the final back this long after the pause (others talking, noise), then it is asked for.
    static let maxVADDefer: TimeInterval = 3
    static let usedPartialWindow: TimeInterval = 15

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
        scribeRetryAttempt = 0
        retryTask?.cancel()
        retryTask = nil
        scribeKeytermsDropped = false
        lifecycleTask?.cancel()
        lifecycleTask = Task { await startTranscribing() }
    }

    func captureStopped() {
        retryTask?.cancel()
        retryTask = nil
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
                scheduleScribeRetry(reason: "no on-device engine")
                return
            }
            engine = chosen
        }

        let provider = makeProvider(locale, engine)
        if engine == .scribe {
            // A11 / Toby: how many keyterms and the longest, each time a session opens.
            let terms = scribeKeyterms
            let longest = terms.max(by: { $0.count < $1.count })
            controller.log("Scribe keyterms: \(terms.count), longest \(longest?.count ?? 0) characters" + (longest.map { " (\($0))" } ?? ""))
        }
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
            scheduleScribeRetry(reason: "prepare failed")
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
                            self.otherSpokeAt = now
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
                let reason = (provider as? ScribeProvider)?.endReason ?? "no reason given"
                self.controller.log("Scribe session ended after \(Int(ranFor)) s (\(reason)): reconnecting")
                self.scribeRetryAttempt = 0
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
                self.scheduleScribeRetry(reason: "\(engine.displayName) stopped")
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
            status = .failed(error.localizedDescription)
            scheduleScribeRetry(reason: "start failed")
        }
    }

    /// A10.2: own end of turn. Words wait uncommitted and the wearer has been quiet for the mode's pause (others may
    /// still talk): ask Scribe for the final now instead of waiting for a silence that does not come.
    private func endTurnIfScribeDoesNot(now: Date) {
        // A14 (Toby T6: 38 forced finals in Frågor, last words cut): only when others are talking now, so Scribe
        // cannot hear the pause itself, and only after a little more than the pause.
        guard let other = otherSpokeAt, now.timeIntervalSince(other) < 1.5,
              let since = partialSince, let spoke = wearerSpokeAt, spoke >= since.addingTimeInterval(-10),
              now.timeIntervalSince(spoke) >= pauseSeconds + 0.4,
              commitRequestedAt.map({ now.timeIntervalSince($0) > 2 }) ?? true else { return }
        commitRequestedAt = now
        ownEndsOfTurn += 1
        controller.log("Wearer quiet for \(pauseSeconds) s, Scribe had not committed: final asked for (A10)")
        provider?.commit()
    }

    /// D78: finals become whole utterances before the question gate and the backend see them.
    private func deliver(_ incoming: STTResult) {
        guard let result = strippingUsedWords(incoming) else { return }
        if result.isFinal {
            // A74 (K42.5): first heard word to the last change of the words, for the backend's command check.
            if let since = partialSince { lastUtteranceSeconds = max(0, (lastPartialChangeAt ?? since).timeIntervalSince(since)) }
            else { lastUtteranceSeconds = nil }
            if let asked = staleCommitAskedAt, Date().timeIntervalSince(asked) < Self.commitWait + 1 {
                controller.log("Scribe answered the final asked for, after \(String(format: "%.1f", Date().timeIntervalSince(asked))) s (A56)")
            }
            staleCommitAskedAt = nil
            partialSince = nil
            staleTask?.cancel()
            staleTask = nil
            staleDeferredSince = nil
            lastPartialText = ""
        } else if !result.text.isEmpty {
            if partialSince == nil {
                partialSince = Date()
                partialsSeen += 1
                if partialsSeen <= 30 { controller.log("Scribe: words heard, not committed yet (A63)") } // for Toby's runs
            }
            if result.text != lastPartialText {
                lastPartialText = result.text
                lastPartialChangeAt = Date() // A74
                staleDeferredSince = nil
                scheduleStaleCommit()
            }
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

    /// A21.4: Scribe's result for words already used from a partial: dropped, or only its new words after them.
    private func strippingUsedWords(_ result: STTResult) -> STTResult? {
        guard let used = usedPartial else { return result }
        guard Date().timeIntervalSince(used.at) < Self.usedPartialWindow else {
            usedPartial = nil
            return result
        }
        guard let rest = UsedWords.remainder(of: result.text, after: used.key) else {
            if result.isFinal { usedPartial = nil } // other words: Scribe has moved on
            return result
        }
        if result.isFinal {
            usedPartial = nil
            controller.log("Scribe's final had words already used from the partial: \(rest.isEmpty ? "dropped" : "only the rest kept") (A21)")
        }
        if rest.isEmpty { return nil }
        var trimmed = result
        trimmed.text = rest
        return trimmed
    }

    /// A21.4: no new partial for the pause + `staleMargin` while words wait uncommitted: ask for the final, then use
    /// the partial if it still does not come. Scribe only (the phone's recognisers finalise by themselves).
    private func scheduleStaleCommit() {
        staleTask?.cancel()
        guard joinsUtterances, case .running(.scribe) = status else { return }
        let wait = pauseSeconds + Self.staleMargin
        staleTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(wait))
            guard let self, !Task.isCancelled, self.partialSince != nil, !self.lastPartialText.isEmpty else { return }
            if self.isInputGated { return } // Lumen speaks: `setInputGated(false)` looks again (A56)
            if self.vadSpeaking() == true { // someone still talks: look again later, at most `maxVADDefer` (A56)
                let since = self.staleDeferredSince ?? Date()
                if self.staleDeferredSince == nil {
                    self.staleDeferredSince = since
                    self.controller.log("Words wait uncommitted, the VAD still hears speech: waiting up to \(Int(Self.maxVADDefer)) s more (A56)")
                }
                if Date().timeIntervalSince(since) < Self.maxVADDefer {
                    self.scheduleStaleCommit()
                    return
                }
                self.controller.log("The VAD still hears speech after \(Int(Self.maxVADDefer)) s: the final is asked for anyway (A56)")
            }
            self.staleDeferredSince = nil
            self.staleCommits += 1
            self.staleCommitAskedAt = Date()
            self.controller.log("No final from Scribe \(String(format: "%.1f", wait)) s after the last words: final asked for (A21)")
            self.provider?.commit()
            try? await Task.sleep(for: .seconds(Self.commitWait))
            guard !Task.isCancelled, self.partialSince != nil, !self.lastPartialText.isEmpty else { return }
            self.usePartialAsFinal()
        }
    }

    private func usePartialAsFinal() {
        let text = lastPartialText
        partialsUsedAsFinal += 1
        controller.log("Scribe did not commit: the last partial is used as the final (A21): \(text)")
        usedPartial = (AheadAnswer.key(text), Date())
        partialSince = nil
        lastPartialText = ""
        staleTask = nil
        for utterance in assembler.final(text) {
            sink?.receiveFinalTranscript(utterance, at: Date())
        }
        flushPending() // the speaker is done: what is pending is one utterance
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

    /// A62: the term is among the keyterms the running Scribe session was opened with.
    func isConnectedKeyterm(_ term: String) -> Bool {
        connectedKeyterms.contains { $0.caseInsensitiveCompare(term) == .orderedSame }
    }

    /// A62 (K40): the quiz answer's words reach Scribe now, while Lumen still asks the question (the input is gated
    /// then, and words said while it connects wait in the stream). The time is logged so Oscar can measure the cost.
    private(set) var lastQuizReconnectMs: Int?

    func applyQuizKeytermsNow() async {
        guard case .running(.scribe) = status, controller.isCapturing,
              !scribeKeytermsDropped, scribeKeyterms != connectedKeyterms else { return }
        let started = Date()
        controller.log("Scribe keyterms for the quiz answer: reconnecting while Lumen asks (A62)")
        await startTranscribing()
        let ms = Int(Date().timeIntervalSince(started) * 1000)
        lastQuizReconnectMs = ms
        controller.log("Scribe reconnected for the quiz answer in \(ms) ms, input gated: \(isInputGated) (A62)")
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

    /// A45: told when Scribe fails and the iPhone's own recogniser takes over.
    @ObservationIgnored var onFallback: (@MainActor (String) -> Void)?

    private func fallBackToDevice(_ reason: String) async {
        cloudFailure = reason
        onFallback?(reason)
        controller.log("Scribe unavailable (\(reason)): using the iPhone's speech recognition")
        await startTranscribing()
        // A11: the phone is a stopgap; Scribe is tried again later, whether the phone works or not.
        scheduleScribeRetry(reason: reason)
    }

    /// A11: one pending retry at a time; the delay doubles per failed attempt up to 30 s.
    private func scheduleScribeRetry(reason: String) {
        guard settings?.useCloud == true, controller.isCapturing, retryTask == nil else { return }
        scribeRetryAttempt += 1
        let delay = Self.retryDelay(attempt: scribeRetryAttempt)
        controller.log("Scribe retry \(scribeRetryAttempt) in \(Int(delay)) s (\(reason))")
        retryTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard let self, !Task.isCancelled else { return }
            self.retryTask = nil
            guard self.controller.isCapturing else { return }
            self.cloudFailure = nil
            await self.startTranscribing()
        }
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
        staleTask?.cancel()
        staleTask = nil
        lastPartialText = ""
        usedPartial = nil
        if staleCommits > 0 {
            controller.log("Stale words: \(staleCommits) finals asked for, \(partialsUsedAsFinal) partials used as finals (A21)")
        }
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

/// A21.4: the words of a result that come after the ones already used as a final.
enum UsedWords {
    /// Nil: the text does not start with the used words. Empty: nothing new.
    static func remainder(of text: String, after usedKey: String) -> String? {
        let usedWords = usedKey.split(separator: " ")
        guard !usedWords.isEmpty else { return nil }
        let words = text.split(separator: " ")
        var index = 0
        var matched = 0
        while index < words.count, matched < usedWords.count {
            let keys = AheadAnswer.key(String(words[index])).split(separator: " ") // "250×250" is two words
            index += 1
            for key in keys where matched < usedWords.count {
                guard key == usedWords[matched] else { return nil }
                matched += 1
            }
        }
        guard matched > 0 else { return nil }
        // Only a part of the used words (Scribe's partials grow): they are all used already.
        let rest = words[index...].joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        return AheadAnswer.key(rest).isEmpty ? "" : rest
    }
}

