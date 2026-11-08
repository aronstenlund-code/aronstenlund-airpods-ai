import Foundation
import Observation

/// Drives the Listening screen (MVP items 1–9). No business logic in views.
@MainActor
@Observable
final class ListeningModel: TranscriptSink, AnswerSink {
    let controller: SessionController
    let consent: any ConsentStoring
    let transcription: TranscriptionCoordinator
    let activation: ActivationController
    let answers: AnswerEngine
    let speaker: Speaker
    let voices: VoiceCatalog
    let notes: NotesStore
    let prep: PrepStore
    /// Historik and Minne (D49/D56), on this phone only.
    let history: HistoryStore
    let memory: MemoryStore
    /// Reports and shared history (D57). Nil: nothing leaves the phone this way.
    let feedback: FeedbackClient?
    /// The AirPods press (D74).
    private let remote: RemoteCommandHub?
    /// The hands-free mode to go back to when listening returns after a pause or an interruption (D74).
    private var resumeMode: ConversationMode?
    /// The last voice command and when, so a command seen both as a final result and as a turn runs once.
    private var lastVoice: (intent: VoiceIntent, at: Date)?
    private var questionTimer: Task<Void, Never>?
    /// D80: the answer being made before the pause is over. Spoken only when the pause comes and the words did not go on.
    private var ahead: AheadAnswer?
    private(set) var aheadStats = AheadStats()
    /// The turn being timed, logged at the first sound (D80).
    private var timeline: TurnTimeline?
    /// When the last words were heard (partial or final), for the half-pause TTS prefetch.
    private var lastHeardAt: Date?
    private var prefetchTask: Task<Void, Never>?
    /// Socialt läge / Rizzläge: the text the last early suggestion request was for, and when (D80: at most every 3 s).
    private var liveAhead: (key: String, at: Date)?
    /// D82.3: one live turn, logged when its suggestion is spoken: who, why, requested, ready, spoken.
    private var liveTurn: (endedAt: Date, who: String, requestedAt: Date?, readyAt: Date?)?
    /// When the last answer was completed, so a complaint right after it can be reported (D80).
    private var lastAnswerAt: Date?
    /// D80: turns go to the backend's memory extraction afterwards, never in the answer path.
    let memoryExtractor: MemoryExtractor?
    /// D83: Provläge's first-start answers (exam date, grade, subject, check questions, explanation length).
    let studyProfile: StudyProfileStore
    var isShowingStudyOnboarding = false
    /// D83: a nod answers "ja", a shake "nej", for yes/no check questions.
    let headMotion = HeadMotionListener()
    private var keytermTask: Task<Void, Never>?
    /// D82: what Lumen said lately, so its own voice coming back is never answered.
    private var echo = EchoFilter()
    /// The backend persona of the answer being made (interview, social), for the shared history (D82).
    private var currentPersona: String?
    /// Reopens the recogniser 0.7 s after Lumen's voice has stopped.
    private var ungateTask: Task<Void, Never>?
    static let echoTail: TimeInterval = 0.7
    /// The Diagnostics recording (D78) sees every final as it arrives.
    var finalObserver: (@MainActor (String) -> Void)?
    /// An instruction is on its way to the backend for this mode (D69): what comes back is a calibration, or the
    /// suggestions the wearer asked for ("ge mig tre", D72).
    private var instructing: ConversationMode?
    /// The suggestion trigger that waits until the instruction is back.
    private var deferredTrigger: String?
    /// The trigger of the suggestions being made, so an instruction that cancels them can ask again.
    private var inFlightTrigger: String?
    /// The instruction was a request for more and its suggestions are on screen: nothing replaces them at once.
    private var instructionSuggested = false
    /// "Skickat", or why not.
    private(set) var reportNotice: String?
    /// "Fråga Lumen": the hands-free session ends after one answer.
    private var isSingleTurn = false
    /// Mikrofon per mode (D55).
    let microphone: MicrophoneSettings
    /// What the session is for: decides the microphone and Scribe's pause detection (D78).
    private(set) var mode: ConversationMode = .standard {
        didSet {
            guard mode != oldValue else { return }
            let pause = modeSettings.pause(for: mode)
            let current = mode
            Task { await transcription.setPause(pause, mode: current) }
        }
    }
    /// The mode picker on the Listening screen, remembered between launches (D72).
    var selectedMode: ConversationMode = .standard {
        didSet { modeSettings.lastMode = selectedMode }
    }
    /// Intervjuläge and Rizzläge setup.
    let modeSettings: ModeSettings
    /// The running live session, Rizzläge or Socialt läge. Gone when it ends, and the words with it.
    private(set) var rizz: RizzSession?
    var isShowingInterviewSetup = false
    var isShowingLiveStart = false
    var isShowingAgeGate = false
    /// A microphone comparison is running: what is said is a test sentence, never a question.
    private var isComparing = false
    /// Course goals and personal keyword commands (D37).
    let goals: GoalsStore
    let commands: CommandStore
    /// "Sparade kommandot …" after a spoken save, shown once.
    private(set) var commandNotice: String?
    private let warmer: BackendWarmer?
    private let activity: (any ListeningActivityPresenting)?
    /// Provläge (D36): hands-free tutor session.
    let study: StudySessionController
    /// Why Provläge ended, shown once.
    private(set) var studyNotice: String?
    /// Per-answer latency budget (item 7), shown in the debug overlay.
    let latency = LatencyLog()
    private(set) var conversation = Conversation()
    /// The most recent question handed to the answer engine.
    private(set) var pendingQuestion: ActivationRequest?
    /// One-line notice under the answers: "not a question", failures, offline.
    private(set) var answerNotice: String?
    /// When the session was last saved as a note (item 8).
    private(set) var noteSavedAt: Date?
    var isShowingPrivacy = false
    var isShowingSettings = false
    var isShowingNotes = false
    var isShowingPrep = false
    var isShowingCommands = false
    var isShowingDiagnostics = false
    /// Text mode (item 6): the question being typed. Works without the microphone.
    var draftQuestion = ""

    var state: SessionState { controller.state }
    var isListening: Bool { controller.state.isListening }
    var isActiveSession: Bool { controller.isActiveSession }
    var canResume: Bool { controller.canResume }
    var lastError: String? { controller.lastError }
    var level: AudioLevel.Reading { controller.level }
    var language: TranscriptionLanguage { transcription.language.selected }
    var isAnswering: Bool {
        if case .answering = answers.status { return true }
        return false
    }
    var useMockAnswers: Bool {
        get { answers.useMock }
        set { answers.useMock = newValue }
    }
    /// Installed Apple voices for the selected language (settings picker).
    var appleVoices: [VoiceChoice] { AppleTTSProvider.installedVoices(for: language) }
    var canSaveNote: Bool { !conversation.answers.isEmpty }

    /// "AirPods Pro · HFP" — which microphone is live, from the session snapshot.
    var routeSummary: String? {
        guard let snapshot = controller.snapshot, let input = snapshot.inputs.first else { return nil }
        return "\(input.portName) · \(snapshot.transport)"
    }

    init(controller: SessionController, consent: any ConsentStoring,
         transcription: TranscriptionCoordinator, activation: ActivationController,
         answers: AnswerEngine, speaker: Speaker, voices: VoiceCatalog,
         notes: NotesStore, prep: PrepStore, warmer: BackendWarmer? = nil,
         activity: (any ListeningActivityPresenting)? = nil, study: StudySessionController? = nil,
         goals: GoalsStore? = nil, commands: CommandStore? = nil,
         history: HistoryStore? = nil, memory: MemoryStore? = nil, microphone: MicrophoneSettings? = nil,
         modeSettings: ModeSettings? = nil, feedback: FeedbackClient? = nil, remote: RemoteCommandHub? = nil,
         memoryExtractor: MemoryExtractor? = nil, studyProfile: StudyProfileStore? = nil) {
        self.controller = controller
        self.consent = consent
        self.transcription = transcription
        self.activation = activation
        self.answers = answers
        self.speaker = speaker
        self.voices = voices
        self.notes = notes
        self.prep = prep
        self.history = history ?? HistoryStore()
        self.memory = memory ?? MemoryStore()
        self.microphone = microphone ?? MicrophoneSettings()
        let modes = modeSettings ?? ModeSettings()
        self.modeSettings = modes
        // The remembered mode. Rizzläge only if the 18+ question was answered; the gate is never skipped.
        self.selectedMode = modes.lastMode == .rizz && !modes.isAdultConfirmed ? .standard : modes.lastMode
        self.feedback = feedback
        self.remote = remote
        self.memoryExtractor = memoryExtractor
        self.studyProfile = studyProfile ?? StudyProfileStore()
        self.goals = goals ?? GoalsStore()
        self.commands = commands ?? CommandStore()
        self.warmer = warmer
        self.activity = activity
        self.study = study ?? StudySessionController(settings: StudySettings(), session: controller)
        self.study.onEvent = { [weak self] event in self?.studyEvent(event) }
        controller.onStateChanged = { [weak self] state in self?.sessionStateChanged(state) }
        voices.onLoaded = { [weak speaker] voices, defaultID in
            speaker?.settings.reconcile(with: voices, defaultID: defaultID)
        }
        activation.onActivate = { [weak self] request in self?.activated(request) }
        answers.sink = self
        speaker.onSentenceStarted = { [weak self] provider in
            guard let self else { return }
            self.latency.markFirstSpeech(provider: provider)
            self.logTimeline()
            // D82: in every mode the recogniser is closed while Lumen speaks, and 0.7 s after.
            self.ungateTask?.cancel()
            self.transcription.setInputGated(true)
            if self.study.isActive {
                // Watch the level for a barge-in (D36).
                self.study.speechStarted()
            }
        }
        speaker.onSpeak = { [weak self] text in self?.echo.record(text, at: Date()) }
        // D82 (owner): the app only hears itself when the sound goes out of the iPhone's own speaker. Echo
        // cancellation then, never with AirPods or headphones, so their microphone keeps its quality.
        controller.voiceProcessingPolicy = { [weak self] snapshot in
            (self?.microphone.echoCancellation ?? true) && snapshot.outputsToBuiltInSpeaker
        }
        speaker.onFinished = { [weak self] in self?.speechFinished() }
        let firstPause = modes.pause(for: .standard)
        Task { [transcription] in await transcription.setPause(firstPause, mode: .standard) }
        refreshKeyterms()
        prep.onChange = { [weak self] in self?.refreshKeyterms() }
        remote?.onToggle = { [weak self] in await self?.togglePause() }
        remote?.onPlay = { [weak self] in
            guard let self, !self.isListening else { return }
            await self.togglePause()
        }
        remote?.onPause = { [weak self] in
            guard let self, self.isListening else { return }
            await self.togglePause()
        }
    }

    // MARK: - User actions

    /// The Listening screen opened, the app came back, or listening starts: wake the backend (D31) and load the
    /// voices (D23), which also signs in ahead of the first question. Quiet when offline; retried next time.
    func prepareBackend() async {
        history.purgeExpired()
        memory.purgeExpired()
        guard !answers.useMock else { return }
        Task { await feedback?.sync(history.entries) }
        Task { await warmer?.warm() }
        await voices.refreshIfNeeded()
    }

    /// Primary button: start when idle/error, stop when listening or paused.
    func toggleListening() async {
        if isActiveSession {
            await stopListening()
        } else {
            await startListening()
        }
    }

    func startListening() async {
        // Consent is checked here as well as in the UI: no microphone without a current consent record.
        guard consent.isGranted else {
            controller.log("Start refused: no consent")
            return
        }
        Task { await prepareBackend() }
        refreshKeyterms()
        await useMicrophone(for: mode)
        await controller.start()
        logMicrophone()
    }

    /// Selects the microphone for `mode`. A running session moves to the new route at once (D55).
    private func useMicrophone(for mode: ConversationMode) async {
        // D82: the AirPods keep their best recording; echo cancellation is decided by the output (see init).
        await use(config: microphone.source(for: mode).captureConfig())
    }

    private func use(config: CaptureConfig) async {
        guard config != controller.config else { return }
        let wasActive = isActiveSession
        if wasActive { await controller.stop() }
        controller.config = config
        if wasActive {
            await controller.start()
            logMicrophone()
        }
    }

    private func logMicrophone() {
        controller.log("Microphone \(microphone.source(for: mode).rawValue) for \(mode.rawValue) · \(controller.config.rawValue) · \(routeSummary ?? "no route")")
    }

    /// The phone listens to other people best from a table, not from a pocket (D55).
    var usesPhoneMicrophone: Bool { controller.config.inputPreference == .builtInMic }
    var recognizerName: String {
        if case .running(let engine) = transcription.status { return engine.displayName }
        return "none"
    }

    // MARK: - Microphone comparison (D55)

    /// Starts listening on `source`; returns where the run begins in the transcript. Nil without consent.
    func startComparison(_ source: MicrophoneSource) async -> Int? {
        guard consent.isGranted else { return nil }
        isComparing = true
        await use(config: source.captureConfig())
        if !isListening {
            if canResume { await resume() } else { await controller.start() }
        }
        guard isListening else {
            isComparing = false
            return nil
        }
        return conversation.finalSegments.count
    }

    /// Everything heard since `mark`, including words the recogniser has not finalised.
    func finishComparison(from mark: Int) -> String {
        isComparing = false
        var parts = conversation.finalSegments.dropFirst(mark).map(\.text)
        if let partial = conversation.partial { parts.append(partial.text) }
        return parts.joined(separator: " ")
    }

    /// Command keywords first: they decide what happens, and Scribe takes a limited number of keyterms (D44).
    private func refreshKeyterms() {
        let recent = conversation.answers.suffix(2)
        let terms = KeytermBuilder.terms(commands: commands.commands.map(\.keyword),
                                         topic: recent.last?.question,
                                         answers: recent.map(\.answer),
                                         goals: goals.terms,
                                         memory: memory.facts.map(\.text),
                                         prep: prep.sttTerms)
        transcription.setContextualStrings(terms + prep.sttTerms)
    }

    /// Raw capture for the Diagnostics recording (D78), the same audio the recogniser gets before any gate.
    func subscribeToAudio() -> (id: UUID, stream: AsyncStream<AudioChunk>) {
        controller.subscribeToChunks()
    }

    func unsubscribeFromAudio(_ id: UUID) {
        controller.unsubscribeFromChunks(id)
    }

    func stopListening() async {
        activation.cancelPending()
        answers.cancel()
        speaker.interrupt()
        conversation.cancelAnswer()
        await controller.stop()
    }

    func resume() async {
        await controller.resume()
    }

    /// One tap to switch to music and back (D33): screen button, Live Activity and Control. Never starts a
    /// session: the microphone is only switched on from the app.
    func togglePause() async {
        if isListening {
            await controller.pause()
        } else if canResume {
            await controller.resume()
        }
    }

    private func sessionStateChanged(_ state: SessionState) {
        if state != .listening, study.isActive {
            // Paused, stopped or failed: the hands-free session cannot continue without the microphone. After a
            // pause or an interruption it comes back in the same mode (D74).
            if case .paused = state { resumeMode = mode }
            study.stop()
            transcription.setInputGated(false)
            handsFreeEnded()
        }
        switch state {
        case .listening:
            showActivity()
            if let again = resumeMode {
                resumeMode = nil
                controller.log("Listening again: back to \(again.rawValue)")
                Task { await startHandsFree(again) }
            }
        case .paused:
            // Whoever has the audio now keeps it: no speech may restart the engine behind their back.
            answers.cancel()
            speaker.interrupt()
            conversation.cancelAnswer()
            showActivity()
        case .idle, .error:
            resumeMode = nil
            discardAhead(reason: "listening stopped")
            aheadStats = AheadStats()
            conversation.clearTranscript()
            activity?.end()
        }
        switch state {
        case .listening, .paused: remote?.show(listening: state.isListening, mode: VoiceChannel.spokenName(resumeMode ?? mode))
        case .idle, .error: remote?.clear()
        }
    }

    private func showActivity() {
        activity?.show(ListeningActivityAttributes.ContentState(isPaused: !isListening, suggestions: rizz?.suggestions ?? [],
                                                                currentSuggestion: rizz?.index ?? 0))
    }

    /// Stops the microphone, forgets the session's transcript and clears the consent record; the consent
    /// screen is shown again by `RootView`.
    func withdrawConsent() async {
        await stopListening()
        conversation.clear()
        pendingQuestion = nil
        answerNotice = nil
        consent.revoke()
    }

    func clearHistory() {
        answers.cancel()
        speaker.interrupt()
        latency.clear()
        conversation.clear()
        pendingQuestion = nil
        answerNotice = nil
        noteSavedAt = nil
        commandNotice = nil
    }

    func previewVoice() {
        speaker.preview(speaker.settings.voice, language: language)
    }

    // MARK: - Provläge (D36)

    /// One tap starts the hands-free session (starting the microphone if needed), one tap ends it.
    func toggleStudyMode() async {
        if study.isActive {
            endStudy(bySilence: false)
        } else {
            await startStudy()
        }
    }

    /// The Listening screen's mode button. Intervjuläge and Rizzläge go through their start screens first.
    func toggleSelectedMode() async {
        if study.isActive {
            endStudy(bySilence: false)
            return
        }
        switch selectedMode {
        case .standard: await toggleListening()
        case .prov: await startProvFromCard()
        case .interview: isShowingInterviewSetup = true
        case .rizz:
            if modeSettings.isAdultConfirmed { isShowingLiveStart = true } else { isShowingAgeGate = true }
        case .social: isShowingLiveStart = true
        }
    }

    /// The picker moved: Rizzläge asks for the age the first time it is opened (D63).
    func modeSelected() {
        if selectedMode == .rizz, !modeSettings.isAdultConfirmed { isShowingAgeGate = true }
    }

    func answerAgeGate(confirmed: Bool) {
        isShowingAgeGate = false
        if confirmed {
            modeSettings.confirmAdult()
        } else {
            selectedMode = .standard
        }
    }

    func startStudy() async {
        await startHandsFree(.prov)
    }

    func startHandsFree(_ newMode: ConversationMode) async {
        guard consent.isGranted else {
            controller.log("Hands-free \(newMode.rawValue) refused: no consent")
            return
        }
        if !ModeAccess.isOpen(newMode) {
            controller.log("\(newMode.rawValue) needs a subscription (D83, flag off today)")
            return
        }
        if newMode == .rizz, !modeSettings.isAdultConfirmed {
            controller.log("Rizzläge refused: no age confirmation")
            isShowingAgeGate = true
            return
        }
        studyNotice = nil
        mode = newMode
        await useMicrophone(for: newMode)
        if !isListening {
            if canResume { await resume() } else { await startListening() }
            guard isListening else { return }
        }
        answers.cancel()
        speaker.interrupt()
        conversation.cancelAnswer()
        study.endpointSilence = modeSettings.pause(for: newMode) // D80: the user's pause ends the turn
        if let style = newMode.liveStyle {
            rizz = RizzSession(style: style)
            study.stallSilence = Self.stallSilence
            study.speechDetector = { [weak self] in self?.transcription.vadSpeaking() } // D82.2
            controller.playback.speechVolume = Self.rizzVolume
        } else {
            study.stallSilence = nil
            study.speechDetector = nil
        }
        study.start()
        controller.log("Hands-free \(newMode.rawValue) started")
    }

    /// Settings → Paus (D80). The running mode changes at once.
    func setPause(_ seconds: Double, for target: ConversationMode) {
        modeSettings.setPause(seconds, for: target)
        guard target == mode else { return }
        let pause = modeSettings.pause(for: target)
        Task { await transcription.setPause(pause, mode: target) }
    }

    /// Socialt läge and Rizzläge show and speak exactly one suggestion (D72).
    static let suggestionsShown = 1

    /// The Provläge card on the main screen (D72): one tap, no setup in between.
    func startProvFromCard() async {
        selectedMode = .prov
        if !studyProfile.profile.onboarded {
            isShowingStudyOnboarding = true // D83: the questions come first, once
            return
        }
        await startStudy()
    }

    /// D83: the first-start questions were answered (or skipped): save, put the exam in Minne, start.
    func finishStudyOnboarding(_ answers: StudyProfile) async {
        var profile = answers
        profile.onboarded = true
        studyProfile.profile = profile
        isShowingStudyOnboarding = false
        studyProfileChanged()
        await startStudy()
    }

    /// Settings or a voice command changed the profile: Minne follows (absolute exam date).
    func studyProfileChanged() {
        memory.forget("provprofil")
        for fact in studyProfile.profile.memoryFacts() { memory.add(fact, kind: .fact, source: .manual) }
        refreshKeyterms()
    }

    /// D83: `persona: "tutor"` + `persona_setup` with the profile, on every Provläge call.
    private func tutorPersona() -> PersonaRequest? {
        studyProfile.profile.setupText().map { PersonaRequest(persona: "tutor", setup: $0) }
    }

    /// D82.2: 2 s of silence asks for a way to carry on (was 4 s, D43).
    static let stallSilence: TimeInterval = 2
    /// Quiet enough to say under one's breath, not loud enough to carry (D43). Tuned on device.
    static let rizzVolume: Float = 0.6

    /// Own lines reach Historik only from the AirPods mic: on the iPhone the level tag cannot tell the people on
    /// either side of the table apart, and other people's words are never saved (D56).
    private var ownLinesAreReliable: Bool { microphone.source(for: mode) == .airPods }

    /// One hands-free question for "Fråga Lumen", then the microphone goes off.
    func askFromShortcut() async {
        await controller.waitForForeground()
        isSingleTurn = true
        await startStudy()
    }

    func startFromShortcut() async {
        await controller.waitForForeground()
        if !isListening { await startListening() }
    }

    func startStudyFromShortcut() async {
        await controller.waitForForeground()
        if !study.isActive { await startStudy() }
    }

    func pauseFromShortcut() async {
        if isListening { await controller.pause() }
    }

    /// True when "Fråga Lumen" has had its answer and the session was closed.
    private func finishSingleTurn() -> Bool {
        guard isSingleTurn else { return false }
        endStudy(bySilence: false)
        Task { await stopListening() }
        return true
    }

    private func handsFreeEnded() {
        isSingleTurn = false
        discardAhead(reason: "the session ended")
        liveAhead = nil
        if let session = rizz, !session.offered.isEmpty {
            let lines = ownLinesAreReliable ? session.ownLines.joined(separator: "\n") : ""
            history.record(HistoryEntry(question: lines.isEmpty ? nil : lines, answer: "",
                                        summary: "\(mode == .rizz ? "Rizzläge" : "Socialt läge"): \(session.offered.count) förslag.",
                                        suggestions: session.offered, mode: mode.rawValue, persona: "social"))
        }
        rizz = nil
        instructing = nil
        deferredTrigger = nil
        inFlightTrigger = nil
        controller.playback.speechVolume = 1
        mode = .standard
    }

    /// Ends the session. After the silence timeout the microphone is released too ("sparläge").
    func endStudy(bySilence: Bool) {
        guard study.isActive || bySilence else { return }
        study.stop()
        handsFreeEnded()
        showActivity()
        transcription.setInputGated(false)
        if bySilence {
            studyNotice = "Ended after \(study.settings.autoEndMinutes) min of silence; the microphone was switched off."
            controller.log("Hands-free session auto-ended after silence")
            Task { await stopListening() }
        } else {
            controller.log("Provläge ended by the user")
        }
    }

    private func studyEvent(_ event: StudyEvent) {
        switch event {
        case .turnStarted:
            break
        case .endOfTurn(let raw):
            if isOwnEcho(raw, at: Date()), !isWearerUsingSuggestion(raw, level: study.lastTurnLevelDBFS) {
                discardAhead(reason: "Lumen's own echo")
                study.resumeListening()
                return
            }
            // "Lumen, …" can close a turn before its final result arrives (D74).
            let utterance = VoiceChannel.parse(raw)
            if let intent = utterance.intent { perform(intent) }
            guard let text = utterance.before else {
                discardAhead(reason: "a voice command")
                study.resumeListening()
                return
            }
            if isComplaintAboutLastAnswer(text) || (rizz != nil && (RizzCommand.isNext(text) || VoiceCommand.isReport(text))) {
                discardAhead(reason: "a command")
                study.resumeListening()
                return
            }
            logTurn()
            if !mode.isLive, FillerFilter.isOnlyFiller(text) {
                controller.log("\(mode.rawValue): filler only, not sent")
                discardAhead(reason: "filler")
                study.resumeListening()
                return
            }
            switch mode {
            case .interview: interviewTurn(text)
            case .rizz, .social: rizzTurn(text)
            case .standard, .prov:
                headMotion.stop() // answered with the voice
                activated(ActivationRequest(query: text, trigger: .tutor, language: language), persona: mode == .prov ? tutorPersona() : nil)
            }
        case .stalled:
            if let session = rizz { requestSuggestions(trigger: session.hasConversation ? "stall" : "opener") }
        case .bargeIn:
            controller.log("Provläge: barge-in — stopping the answer")
            answers.cancel()
            speaker.interrupt()
            conversation.cancelAnswer()
            latency.end()
            transcription.setInputGated(false)
        case .autoEnded:
            endStudy(bySilence: true)
        }
    }

    // MARK: - Intervjuläge (D42)

    /// D72: the interviewer's question gets the finished answer, read aloud, and nothing else: no feedback, no
    /// follow-up questions. The wearer's own words (louder, by input level) are never answered, unless they ask for
    /// something out loud ("klar", "sammanfatta", "ge mig feedback").
    private func interviewTurn(_ text: String) {
        let speaker = RizzSpeaker.tag(levelDBFS: study.lastTurnLevelDBFS, thresholdDBFS: modeSettings.speakerThresholdDBFS)
        if speaker == .user, !VoiceCommand.isInterviewRequest(text) {
            controller.log("Intervjuläge: own turn at \(study.lastTurnLevelDBFS ?? -99) dBFS, not answered")
            study.resumeListening()
            return
        }
        activated(ActivationRequest(query: text, trigger: .overheard, language: language),
                  persona: PersonaRequest(persona: "interview", setup: modeSettings.interviewSetup, turn: "question"))
    }

    /// Likely questions and model answers from the role or job ad. Long, so it is shown, not spoken.
    func prepareInterview() {
        activated(ActivationRequest(query: language == .swedish ? "Förbered mig inför intervjun" : "Prepare me for the interview",
                                    trigger: .interviewPrep, language: language),
                  persona: PersonaRequest(persona: "interview", setup: modeSettings.interviewSetup))
    }

    // MARK: - Rizzläge (D43)

    private func rizzTurn(_ text: String) {
        let speaker = RizzSpeaker.tag(levelDBFS: study.lastTurnLevelDBFS, thresholdDBFS: modeSettings.speakerThresholdDBFS)
        let why = RizzSpeaker.reason(levelDBFS: study.lastTurnLevelDBFS, thresholdDBFS: modeSettings.speakerThresholdDBFS)
        let detector = transcription.vadIsRunning ? "Silero" : "level"
        controller.log("\(mode.rawValue) turn · \(speaker == .user ? "wearer" : "other") · \(why) · speech by \(detector)")
        if speaker == .other {
            // A suggestion asked for while they were talking (D80) counts from that request.
            let early = liveAhead?.at
            let ready: Date? = early != nil && rizz?.current != nil ? Date() : nil
            liveTurn = (endedAt: Date(), who: "other", requestedAt: early, readyAt: ready)
        }
        study.resumeListening() // the room goes on while the suggestions are being made
        guard var session = rizz else { return }
        if speaker == .user, session.usesSuggestion(text) {
            modeSettings.countUse(of: session.style)
        }
        session.add(speaker, text: text, at: Date())
        rizz = session
        if speaker == .other, !FillerFilter.isOnlyFiller(text) {
            if let early = liveAhead, early.key == AheadAnswer.key(text) {
                // D80: asked for while they were talking; it is on screen or on its way, and speaks in this pause.
                liveAhead = nil
                speakSuggestion()
            } else {
                if inFlightTrigger != nil { aheadStats.discarded += 1 }
                liveAhead = nil
                requestSuggestions(trigger: "other_spoke")
            }
        }
    }

    // MARK: - Voice (D74)

    /// The question gate holds a question until the speaker is done (D78): fire it when it is due.
    private func scheduleQuestionTimer() {
        guard let due = activation.pendingDueAt else { return }
        questionTimer?.cancel()
        questionTimer = Task { [weak self] in
            let wait = due.timeIntervalSinceNow
            if wait > 0 { try? await Task.sleep(for: .seconds(wait)) }
            guard let self, !Task.isCancelled else { return }
            if self.controller.playback.isSpeaking {
                self.activation.cancelPending()
                return
            }
            self.activation.fireDue(now: Date())
        }
    }

    /// "Lumen, …" in every mode. True when the words were for Lumen: they are never conversation.
    @discardableResult
    private func handleVoice(in text: String, at date: Date) -> Bool {
        let utterance = VoiceChannel.parse(text)
        guard let intent = utterance.intent else { return false }
        study.discardTurnText()
        if let before = utterance.before, study.isActive { study.transcriptFinal(before, at: date) }
        perform(intent)
        return true
    }

    private func perform(_ intent: VoiceIntent) {
        let now = Date()
        if let last = lastVoice, last.intent == intent, now.timeIntervalSince(last.at) < 5 { return }
        lastVoice = (intent, now)
        switch intent {
        case .switchTo(let target):
            controller.log("Voice: switch to \(target.rawValue)")
            Task { await switchByVoice(to: target) }
        case .pause:
            controller.log("Voice: pause")
            Task { await pauseByVoice() }
        case .stopListening:
            controller.log("Voice: stop listening")
            Task { await stopByVoice() }
        case .instruction(let text):
            controller.log("Voice: instruction (\(text.count) characters)") // the words stay out of the log
            instruct(text)
        case .remember(let text):
            if memory.add(text, kind: .fact, source: .voice) != nil {
                controller.log("Voice: remembered (\(text.count) characters)")
                say(language == .swedish ? "Sparat." : "Saved.")
                refreshKeyterms()
            }
        case .forget(let text):
            let removed = memory.forget(text)
            controller.log("Voice: forgot \(removed) item(s)")
            say(removed > 0 ? (language == .swedish ? "Glömt." : "Forgotten.")
                            : (language == .swedish ? "Hittade inget att glömma." : "Nothing to forget."))
            refreshKeyterms()
        case .rule(let text):
            if memory.add(text, kind: .rule, source: .voice) != nil {
                controller.log("Voice: rule saved")
                say(language == .swedish ? "Regel sparad." : "Rule saved.")
            }
        }
    }

    /// "Lumen, byt till provläge" (D74). The same checks as the screen: Rizzläge needs the 18+ answer, a live mode
    /// its start screen once, Intervjuläge a role.
    func switchByVoice(to target: ConversationMode) async {
        if target == .rizz, !modeSettings.isAdultConfirmed {
            say("Rizzläge kräver att du bekräftar 18 år i appen.")
            return
        }
        if target.isLive, !modeSettings.hasConfirmedLiveStart(target) {
            say("\(VoiceChannel.spokenName(target).dropLast()) startas i appen första gången.")
            return
        }
        if target == .interview, modeSettings.interviewSetup.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            say("Intervjuläge behöver en roll i appen först.")
            return
        }
        let current: ConversationMode? = study.isActive ? mode : (isListening ? .standard : nil)
        if current == target {
            say(VoiceChannel.spokenName(target))
            return
        }
        if study.isActive { endStudy(bySilence: false) }
        selectedMode = target
        if target == .standard {
            if !isListening {
                if canResume { await resume() } else { await startListening() }
            }
        } else {
            await startHandsFree(target)
        }
        say(VoiceChannel.spokenName(target))
    }

    private func pauseByVoice() async {
        guard isListening else { return }
        say(language == .swedish ? "Pausar." : "Pausing.")
        await speechDone()
        await controller.pause()
    }

    private func stopByVoice() async {
        say(language == .swedish ? "Slutar lyssna." : "Stopping.")
        await speechDone()
        await stopListening()
    }

    /// What follows the name when it is not a command. Socialt läge and Rizzläge: the D69 instruction path.
    /// The other modes: a question to Lumen.
    private func instruct(_ text: String) {
        if rizz != nil {
            liveInstruction(text)
        } else if study.isActive, mode == .interview {
            activated(ActivationRequest(query: text, trigger: .overheard, language: language),
                      persona: PersonaRequest(persona: "interview", setup: modeSettings.interviewSetup, turn: "question"))
        } else if study.isActive, mode == .prov, StudyProfileVoice.apply(text, to: &studyProfile.profile) {
            // D83: "Lumen, korta förklaringar", "Lumen, provet är på fredag" …
            studyProfileChanged()
            controller.log("Provläge profile changed by voice")
            say(language == .swedish ? "Uppdaterat." : "Updated.")
        } else if study.isActive {
            activated(ActivationRequest(query: text, trigger: .tutor, language: language), persona: mode == .prov ? tutorPersona() : nil)
        } else {
            activated(ActivationRequest(query: text, trigger: .text, language: language))
        }
    }

    /// D69/D72: "Lumen, lite mindre kaxig" or "Lumen, ge mig tre pickup lines" in Socialt läge or Rizzläge. Sent
    /// as `social.calibrate` with the stored calibration, never as a line of the conversation. The backend answers a
    /// calibration with `done.calibration` and a request for more with that many suggestions.
    func liveInstruction(_ text: String) {
        guard let session = rizz,
              let persona = LiveRequest.instruction(text, for: session, interests: modeSettings.interests,
                                                    profile: modeSettings.rizzProfile,
                                                    calibration: modeSettings.calibration(for: mode),
                                                    adultConfirmed: modeSettings.isAdultConfirmed) else { return }
        if let trigger = inFlightTrigger { deferredTrigger = trigger } // the suggestions being made are cancelled
        inFlightTrigger = nil
        instructing = mode
        instructionSuggested = false
        controller.log("\(mode.rawValue): instruction sent") // the words stay out of the log
        let request = ActivationRequest(query: "", trigger: .rizz, language: language)
        pendingQuestion = request
        latency.begin(request)
        answers.answer(request, context: AnswerContext(memories: memory.backendItems()), persona: persona)
    }

    /// The instruction came back: store a calibration, then ask for the suggestions that waited.
    private func instructionEnded(_ calibration: String?, answered: Bool) {
        guard let instructed = instructing else { return }
        instructing = nil
        if let calibration {
            modeSettings.setCalibration(calibration, for: instructed)
            controller.log("\(instructed.rawValue): calibration stored (\(calibration.count) characters)")
            say(language == .swedish ? "Okej." : "Okay.")
        }
        let suggested = instructionSuggested
        instructionSuggested = false
        if let trigger = deferredTrigger, answered, !suggested {
            deferredTrigger = nil
            requestSuggestions(trigger: trigger)
        }
        deferredTrigger = nil
    }

    /// A short confirmation in the AirPods. Not while paused: the audio belongs to someone else then.
    private func say(_ line: String) {
        if case .paused = state { return }
        speaker.enqueue(line, language: language)
    }

    private func speechDone() async {
        for _ in 0..<60 where speaker.isSpeaking || speaker.hasPendingSpeech {
            try? await Task.sleep(for: .milliseconds(50))
        }
    }

    /// D80: after the turn, never in its path: the backend looks for facts about the user and they are saved in
    /// Minne (shown, editable; sensitive categories never). Only the user's own words are sent (D56).
    private func extractMemories(from turn: AnswerTurn) {
        guard let memoryExtractor, turn.isOwnQuestion else { return }
        let body = MemoryExtraction.body(question: turn.question, answer: turn.answer, mode: mode.rawValue,
                                         memories: memory.backendItems(), language: language == .swedish ? "sv" : "en")
        Task { [weak self] in
            let found = await memoryExtractor.extract(body)
            guard let self, !found.isEmpty else { return }
            for fact in found { self.memory.add(fact, kind: .fact, source: .automatic) }
            self.controller.log("Minne: \(found.count) new item(s) from the last turn")
            self.refreshKeyterms()
        }
    }

    /// "det var fel", "dåligt svar" … as a whole utterance within 30 s of an answer (D80, D57).
    private func isComplaintAboutLastAnswer(_ text: String, now: Date = Date()) -> Bool {
        guard VoiceCommand.isComplaint(text), let last = lastAnswerAt else { return false }
        return now.timeIntervalSince(last) < 30
    }

    /// D80: after an answer and 3 s of quiet, the recogniser gets keyterms for the current topic.
    private func scheduleKeytermRefresh() {
        refreshKeyterms()
        keytermTask?.cancel()
        keytermTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard let self, !Task.isCancelled, !self.speaker.isSpeaking else { return }
            if let heard = self.lastHeardAt, Date().timeIntervalSince(heard) < 3 { return }
            await self.transcription.applyKeytermsIfQuiet()
        }
    }

    /// Which recogniser and microphone heard the turn (D74): cut sentences are traced to one of them.
    private func logTurn() {
        controller.log("Turn · \(mode.rawValue) · STT \(recognizerName) · mic \(microphone.source(for: mode).rawValue) · \(controller.config.rawValue)")
    }

    private func requestSuggestions(trigger: String) {
        guard let session = rizz else { return }
        if liveTurn != nil, liveTurn?.requestedAt == nil { liveTurn?.requestedAt = Date() }
        if instructing != nil {
            deferredTrigger = trigger // the instruction goes first, the suggestions follow it
            return
        }
        guard let persona = LiveRequest.suggestions(for: session, trigger: trigger, interests: modeSettings.interests,
                                                    profile: modeSettings.rizzProfile,
                                                    calibration: modeSettings.calibration(for: mode),
                                                    adultConfirmed: modeSettings.isAdultConfirmed) else { return }
        let request = ActivationRequest(query: "", trigger: .rizz, language: language)
        pendingQuestion = request
        inFlightTrigger = trigger
        latency.begin(request)
        answers.answer(request, context: AnswerContext(memories: memory.backendItems()), persona: persona)
    }

    func answerSuggestions(_ options: [String]) {
        latency.markFirstText(provider: answers.activeProvider.name)
        if instructing != nil {
            // The wearer asked for more ("ge mig tre", D72): all of them, shown and spoken, this time only.
            instructionSuggested = true
            rizz?.offer(options)
            showActivity()
            speakAllSuggestions()
            return
        }
        inFlightTrigger = nil
        if liveTurn != nil { liveTurn?.readyAt = Date() }
        rizz?.offer(Array(options.prefix(Self.suggestionsShown))) // D72: one suggestion, shown and spoken
        showActivity()
        speakSuggestion()
    }

    private func speakAllSuggestions() {
        guard let options = rizz?.suggestions, !study.someoneIsTalking() else { return }
        for line in options { speaker.enqueue(line, language: language) }
    }

    /// "nästa", or the button on the Live Activity. With one suggestion on screen (D72) it asks for a fresh one.
    func nextSuggestion() {
        guard let session = rizz else { return }
        if session.suggestions.count <= 1 {
            requestSuggestions(trigger: session.hasConversation ? "stall" : "opener")
            return
        }
        rizz?.next()
        showActivity()
        speakSuggestion()
    }

    /// Only in a pause, never over anyone. A missed moment stays on the Live Activity.
    private func speakSuggestion() {
        guard let line = rizz?.current, !study.someoneIsTalking(), !speaker.isSpeaking else { return }
        speaker.enqueue(line, language: language)
        logLiveTurn()
    }

    private func speechFinished() {
        if study.isActive, finishSingleTurn() { return }
        reopenRecognizerAfterSpeech()
        listenForHeadAnswerIfAsked()
    }

    /// D83: after a yes/no check question in Provläge, a nod or a shake answers it for 6 s. The voice works too.
    private func listenForHeadAnswerIfAsked() {
        guard study.isActive, mode == .prov, studyProfile.profile.checkQuestions == .yesNo,
              let answer = conversation.answers.last?.answer.trimmingCharacters(in: .whitespacesAndNewlines),
              answer.hasSuffix("?") else { return }
        guard headMotion.isAvailable else {
            controller.log("Head gestures: not supported by these AirPods, answer with the voice")
            return
        }
        headMotion.listen(for: 6) { [weak self] gesture in
            guard let self, self.study.isActive, self.study.phase == .listening else { return }
            let text = gesture == .nod ? "Ja" : "Nej"
            self.controller.log("Head gesture: \(gesture == .nod ? "nod" : "shake") → \(text)")
            self.activated(ActivationRequest(query: text, trigger: .tutor, language: self.language), persona: self.tutorPersona())
        }
    }

    /// D82: the recogniser opens again only when Lumen's voice has really stopped playing, plus 0.7 s for its echo.
    private func reopenRecognizerAfterSpeech() {
        ungateTask?.cancel()
        ungateTask = Task { [weak self] in
            guard let self else { return }
            var waited = 0
            while self.controller.playback.isSpeaking, waited < 600 {
                try? await Task.sleep(for: .milliseconds(50))
                waited += 1
            }
            try? await Task.sleep(for: .seconds(Self.echoTail))
            guard !Task.isCancelled, !self.speaker.isSpeaking else { return }
            self.transcription.setInputGated(false)
            if self.study.isActive { self.study.resumeListening() }
        }
    }

    /// Settings → Ekoreducering changed: a running session follows at once.
    func echoCancellationChanged() async {
        await controller.reevaluateVoiceProcessing()
    }

    /// D82: most of the words are something Lumen just said: its own voice came back.
    private func isOwnEcho(_ text: String, at date: Date) -> Bool {
        guard let share = echo.overlap(text, now: date), share >= EchoFilter.overlap else { return false }
        controller.log(String(format: "Echo filtered: %.0f %% of the words were Lumen's own", share * 100))
        return true
    }

    /// Rizzläge / Socialt läge: the wearer saying the suggestion out loud is its use, not Lumen's echo. Through
    /// AirPods Lumen is never heard by the microphone (D82, owner); out of the iPhone's own speaker it can be.
    private func isWearerUsingSuggestion(_ text: String, level: Double?) -> Bool {
        guard let session = rizz, session.usesSuggestion(text),
              !(controller.snapshot?.outputsToBuiltInSpeaker ?? false) else { return false }
        return RizzSpeaker.tag(levelDBFS: level, thresholdDBFS: modeSettings.speakerThresholdDBFS) == .user
    }

    /// The answer produced no speech (silent mode, empty answer): back to listening right away.
    private func studyAnswerEnded() {
        guard study.isActive, !mode.isLive, !speaker.hasPendingSpeech, !finishSingleTurn() else { return }
        transcription.setInputGated(false)
        study.resumeListening()
    }

    /// Item 8: saves the session's answers as a local note.
    @discardableResult
    func saveNote() -> Note? {
        guard let note = notes.save(conversation, language: language) else {
            controller.log("Save note: nothing to save")
            return nil
        }
        noteSavedAt = note.createdAt
        controller.log("Note saved: \(note.title)")
        return note
    }

    // MARK: - Activation (item 3)

    func askAboutLast() {
        if !activation.answerLast(conversation: conversation, language: language) {
            controller.log("Ask about last: nothing final in the transcript yet")
        }
    }

    /// Text mode (item 6): typed questions take the same path as spoken ones (`mode: text` to the backend).
    func submitText(_ text: String) {
        activation.submitText(text, language: language)
    }

    var canSendDraft: Bool { !draftQuestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    func sendDraft() {
        guard canSendDraft else { return }
        let text = draftQuestion
        draftQuestion = ""
        submitText(text)
    }

    private func activated(_ request: ActivationRequest, persona: PersonaRequest? = nil) {
        if VoiceCommand.isMusicHandOff(request.query) { return } // the final result already paused the session
        if request.trigger == .auto, FillerFilter.isOnlyFiller(request.query) { return } // D74
        if persona?.social == nil, deliverAhead(for: request) { return } // D80: ready the moment the pause is over
        discardAhead(reason: "a different turn")
        currentPersona = persona?.persona
        pendingQuestion = request
        answerNotice = nil
        // A new question interrupts the current answer and its speech (assignment item 5).
        speaker.interrupt()
        latency.begin(request)
        controller.log("Activation (\(request.trigger.rawValue)): \(request.query)")
        if !study.isActive { logTurn() }
        timeline = TurnTimeline(heardAt: lastHeardAt, requestAt: Date(), pauseEndAt: Date(), answeredAhead: false)
        answers.answer(request, context: context(for: request), persona: persona)
    }

    private func context(for request: ActivationRequest) -> AnswerContext {
        // Provläge sends the whole session's memory (the backend keeps the last 6 pairs).
        let qaLimit = study.isActive ? AnswerContext.qaLimit : 3
        let matched = commands.matches(in: request.query)
        if !matched.isEmpty {
            controller.log("Commands matched: \(matched.map(\.keyword).joined(separator: ", "))")
        }
        return AnswerContext(transcript: conversation.recentText(seconds: 60),
                             recentQA: conversation.recentQA(limit: qaLimit),
                             prepTerms: prep.backendTerms,
                             goals: goals.compact,
                             commands: matched.map { AnswerContext.Command(keyword: $0.keyword, instruction: $0.instruction) },
                             memories: memory.backendItems())
    }

    // MARK: - Answer ahead, deliver at the pause (D80)

    /// A sentence was heard: start its answer now, while the speaker is still pausing. Words that come before the
    /// pause is over replace it with a new call for the whole text. One call at a time.
    private func answerAhead(for raw: String) {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isListening, !isComparing, instructing == nil, !text.isEmpty, !FillerFilter.isOnlyFiller(text),
              VoiceChannel.parse(text).intent == nil, !VoiceCommand.isMusicHandOff(text), !VoiceCommand.isComplaint(text),
              CommandMatcher.parseSaveCommand(text) == nil else { return }
        if rizz != nil {
            liveSuggestionAhead(for: text)
            return
        }
        var persona: PersonaRequest?
        let request: ActivationRequest
        switch mode {
        case .standard:
            guard !study.isActive, QuestionGate(sensitivity: activation.settings.sensitivity).evaluate(text).fires else { return }
            request = ActivationRequest(query: text, trigger: .auto, language: language)
        case .prov:
            guard study.isActive, study.phase == .listening else { return }
            request = ActivationRequest(query: text, trigger: .tutor, language: language)
            persona = tutorPersona()
        case .interview:
            guard study.isActive, study.phase == .listening else { return }
            let speaker = RizzSpeaker.tag(levelDBFS: study.currentTurnLevelDBFS, thresholdDBFS: modeSettings.speakerThresholdDBFS)
            guard speaker == .other || VoiceCommand.isInterviewRequest(text) else { return }
            request = ActivationRequest(query: text, trigger: .overheard, language: language)
            persona = PersonaRequest(persona: "interview", setup: modeSettings.interviewSetup, turn: "question")
        case .rizz, .social:
            return
        }
        startAhead(request, persona: persona)
    }

    private func startAhead(_ request: ActivationRequest, persona: PersonaRequest?) {
        let key = AheadAnswer.key(request.query)
        if let current = ahead, !current.delivered {
            if current.key == key { return } // already being answered
            discardAhead(reason: "the words went on")
        }
        // Never cut an answer the user is hearing or about to hear.
        if ahead?.delivered == true || speaker.isSpeaking { return }
        if case .answering = answers.status { return }
        ahead = AheadAnswer(request: request, persona: persona, heardAt: Date())
        aheadStats.started += 1
        answers.answer(request, context: context(for: request), persona: persona)
    }

    /// The pause is over and the turn is the one answered ahead: play it back through the normal path at once.
    private func deliverAhead(for request: ActivationRequest) -> Bool {
        guard var current = ahead, !current.delivered, current.key == AheadAnswer.key(request.query) else { return false }
        current.delivered = true
        ahead = current
        aheadStats.delivered += 1
        currentPersona = current.persona?.persona
        pendingQuestion = current.request
        answerNotice = nil
        if speaker.isSpeaking { speaker.interrupt() }
        latency.begin(current.request)
        controller.log("Activation (\(current.request.trigger.rawValue)) · answered ahead: \(current.request.query)")
        logTurn()
        timeline = TurnTimeline(heardAt: current.heardAt, requestAt: current.heardAt, firstTokenAt: current.firstTokenAt,
                                doneAt: current.doneAt, pauseEndAt: Date(), answeredAhead: true)
        for event in current.events { replay(event) }
        if current.isFinished, ahead?.delivered == true { ahead = nil }
        return true
    }

    private func replay(_ event: AheadAnswer.Event) {
        switch event {
        case .started(let request, let source): answerStarted(request, source: source)
        case .reconstructed(let question): answerQuestionReconstructed(question)
        case .delta(let text): answerDelta(text)
        case .sentence(let sentence): answerSentence(sentence)
        case .completed(let latencyMs, let done): answerCompleted(latencyMs: latencyMs, done: done)
        case .skipped(let request): answerSkipped(request)
        case .report: answerReportRequested()
        }
    }

    /// Keeps an event of the answer made ahead. True: it was buffered and must not reach the screen or the voice.
    private func bufferAhead(_ event: AheadAnswer.Event) -> Bool {
        guard var current = ahead, !current.delivered else { return false }
        current.record(event, at: Date())
        ahead = current
        if case .sentence = event { prefetchIfStable() }
        return true
    }

    private func discardAhead(reason: String) {
        guard let current = ahead, !current.delivered else { return }
        ahead = nil
        answers.cancel()
        speaker.discardPrepared()
        aheadStats.discarded += 1
        if current.prefetched { aheadStats.prefetchWasted += 1 }
        controller.log("Answer ahead discarded (\(reason)) · \(aheadStats.summary())")
    }

    /// D80: the first sentence's voice is fetched only when the answer text is stable: its first sentence is complete
    /// and the speaker has been quiet for half the pause. A thrown-away answer then rarely costs TTS.
    private func prefetchIfStable(now: Date = Date()) {
        guard let current = ahead, !current.delivered, !current.prefetched, let first = current.firstSentence,
              let heard = lastHeardAt, now.timeIntervalSince(heard) >= modeSettings.pause(for: mode) / 2 else { return }
        if speaker.prepare(first, language: current.request.language) {
            ahead?.prefetched = true
            aheadStats.prefetched += 1
        }
    }

    private func schedulePrefetch() {
        prefetchTask?.cancel()
        let half = modeSettings.pause(for: mode) / 2
        prefetchTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(half))
            guard let self, !Task.isCancelled else { return }
            self.prefetchIfStable()
        }
    }

    /// Socialt läge / Rizzläge: a suggestion is made while the other person is still talking, so it is ready when the
    /// pause comes; during a long monologue at most every 3 s (D80).
    private func liveSuggestionAhead(for text: String, now: Date = Date()) {
        guard let session = rizz, instructing == nil else { return }
        let speaker = RizzSpeaker.tag(levelDBFS: study.currentTurnLevelDBFS, thresholdDBFS: modeSettings.speakerThresholdDBFS)
        guard speaker == .other else { return }
        if let last = liveAhead, now.timeIntervalSince(last.at) < Self.liveRefresh { return }
        var preview = session
        preview.add(.other, text: text, at: now)
        guard let persona = LiveRequest.suggestions(for: preview, trigger: "other_spoke", interests: modeSettings.interests,
                                                    profile: modeSettings.rizzProfile,
                                                    calibration: modeSettings.calibration(for: mode),
                                                    adultConfirmed: modeSettings.isAdultConfirmed) else { return }
        if inFlightTrigger != nil { aheadStats.discarded += 1 }
        liveAhead = (AheadAnswer.key(text), now)
        aheadStats.started += 1
        let request = ActivationRequest(query: "", trigger: .rizz, language: language)
        pendingQuestion = request
        inFlightTrigger = "other_spoke"
        latency.begin(request)
        answers.answer(request, context: AnswerContext(memories: memory.backendItems()), persona: persona)
    }

    static let liveRefresh: TimeInterval = 3

    /// D82.3: turn end → suggestion requested → ready → spoken, in ms from the end of the other person's turn.
    private func logLiveTurn(now: Date = Date()) {
        guard let turn = liveTurn else { return }
        liveTurn = nil
        func ms(_ date: Date?) -> String {
            guard let date else { return "–" }
            return "\(Int((date.timeIntervalSince(turn.endedAt) * 1000).rounded())) ms"
        }
        controller.log("Live turn timing · \(turn.who) · requested \(ms(turn.requestedAt)) · ready \(ms(turn.readyAt)) · spoken \(ms(now)) (from the end of the turn)")
    }

    private func logTimeline(now: Date = Date()) {
        guard let current = timeline else { return }
        timeline = nil
        controller.log(current.line(firstSoundAt: now) + " · " + aheadStats.summary(now: now))
    }

    // MARK: - AnswerSink (item 4)

    func answerStarted(_ request: ActivationRequest, source: String) {
        if request.trigger == .rizz { return } // suggestions have no answer of their own
        if bufferAhead(.started(request, source: source)) { return }
        conversation.beginAnswer(question: request.query, source: source, at: request.createdAt,
                                 isOwnQuestion: request.trigger.isUsersOwnWords)
        if study.isActive { study.answerStarted() }
    }

    func answerQuestionReconstructed(_ question: String) {
        if bufferAhead(.reconstructed(question)) { return }
        conversation.setAnswerQuestion(question)
    }

    func answerDelta(_ text: String) {
        if bufferAhead(.delta(text)) { return }
        if timeline?.firstTokenAt == nil { timeline?.firstTokenAt = Date() }
        latency.markFirstText(provider: answers.activeProvider.name)
        conversation.appendAnswerText(text)
    }

    func answerSentence(_ sentence: String) {
        if bufferAhead(.sentence(sentence)) { return }
        if case .paused = state { return } // a typed question while paused is shown, not spoken over the music
        if pendingQuestion?.trigger == .interviewPrep { return }
        speaker.enqueue(sentence, language: pendingQuestion?.language ?? language)
    }

    func answerCompleted(latencyMs: Double?, done: AnswerDone?) {
        if instructing != nil {
            latency.end()
            instructionEnded(done?.calibration, answered: true)
            return
        }
        if bufferAhead(.completed(latencyMs: latencyMs, done: done)) { return }
        if ahead?.delivered == true { ahead = nil }
        inFlightTrigger = nil
        if timeline?.doneAt == nil { timeline?.doneAt = Date() }
        if let turn = conversation.completeAnswer(latencyMs: latencyMs) {
            history.record(HistoryEntry(createdAt: turn.createdAt, question: turn.isOwnQuestion ? turn.question : nil,
                                        answer: turn.answer, summary: done?.summary,
                                        mode: mode.rawValue, persona: currentPersona))
            Task { await feedback?.sync(history.entries) }
            lastAnswerAt = Date()
            extractMemories(from: turn)
            scheduleKeytermRefresh()
        }
        if let fact = done?.memoryAdd {
            memory.add(fact)
        }
        if let latencyMs {
            controller.log("Answer · first text after \(Int(latencyMs)) ms" + (done?.usage?.model.map { " · \($0)" } ?? ""))
        }
        studyAnswerEnded()
    }

    func answerReportRequested() {
        if bufferAhead(.report) { return }
        if ahead?.delivered == true { ahead = nil }
        latency.end()
        conversation.cancelAnswer()
        Task { await reportPreviousTurn() }
        studyAnswerEnded()
    }

    /// "Rapportera" on an answer (D57). The question goes along only if it was the user's own.
    @discardableResult
    func report(_ turn: AnswerTurn, comment: String? = nil) async -> Bool {
        guard let feedback else { return false }
        do {
            try await feedback.send(type: "report", fragment: turn.isOwnQuestion ? turn.question : nil, answer: turn.answer,
                                    comment: comment, mode: mode.rawValue, persona: mode.isLive ? "social" : nil,
                                    timings: turn.latencyMs.map { ["first_text_ms": $0] })
            reportNotice = language == .swedish ? "Skickat" : "Sent"
            return true
        } catch {
            reportNotice = error.localizedDescription
            controller.log("Report failed: \(error.localizedDescription)")
            return false
        }
    }

    /// The spoken command: the last answer, or the suggestion on screen in Rizzläge. Confirms by voice.
    private func reportPreviousTurn() async {
        let suggestion = rizz?.current.map { AnswerTurn(question: "", answer: $0, source: "rizz", isOwnQuestion: false) }
        guard let turn = suggestion ?? conversation.answers.last else {
            reportNotice = language == .swedish ? "Inget svar att rapportera" : "No answer to report"
            return
        }
        if await report(turn), let notice = reportNotice {
            if case .paused = state { return }
            speaker.enqueue(notice, language: language)
        }
    }

    /// Settings → Feedback & suggestions.
    func sendFeedback(type: String, text: String) async -> Bool {
        guard let feedback else { return false }
        do {
            try await feedback.send(type: type, comment: text)
            return true
        } catch {
            controller.log("Feedback failed: \(error.localizedDescription)")
            return false
        }
    }

    func setSharing(_ sharing: Bool) {
        feedback?.settings.setSharing(sharing)
        Task { await feedback?.sync(history.entries) }
    }

    func answerSkipped(_ request: ActivationRequest) {
        if instructing != nil {
            latency.end()
            instructionEnded(nil, answered: true)
            return
        }
        if bufferAhead(.skipped(request)) { return }
        if ahead?.delivered == true { ahead = nil }
        latency.end()
        conversation.cancelAnswer()
        answerNotice = "Not a question — no answer (auto mode)"
        controller.log("Auto: backend says not a question: \(request.query)")
        studyAnswerEnded()
    }

    func answerFailed(_ message: String, wantsFallback: Bool) {
        if instructing != nil {
            latency.end()
            answerNotice = message
            controller.log("Instruction failed: \(message)")
            instructionEnded(nil, answered: false)
            return
        }
        if let current = ahead, !current.delivered {
            // The answer made ahead failed: at the pause the turn is asked again the normal way.
            ahead = nil
            controller.log("Answer ahead failed: \(message)")
            return
        }
        if ahead?.delivered == true { ahead = nil }
        inFlightTrigger = nil
        latency.end()
        conversation.cancelAnswer()
        answerNotice = message
        controller.log("Answer failed: \(message)" + (wantsFallback ? " · fallback requested (on-device engine not available on this iPhone)" : ""))
        studyAnswerEnded()
    }

    // MARK: - TranscriptSink (fed by TranscriptionCoordinator)

    func receivePartialTranscript(_ text: String, at date: Date = Date()) {
        conversation.updatePartial(text, at: date, overlapsPlayback: controller.playback.isSpeaking)
        if echo.isEcho(text, now: date) { return } // D82: Lumen's own voice
        if study.isActive { study.transcriptPartial(text) }
        guard !controller.playback.isSpeaking else { return }
        lastHeardAt = date
        schedulePrefetch()
        // A partial that already ends a sentence is enough to start the answer (D80).
        if let last = text.trimmingCharacters(in: .whitespacesAndNewlines).last, last == "?" || last == "!" {
            answerAhead(for: text)
        }
    }

    /// The recogniser committed words before the pause is over (D80): start the answer now.
    func receiveSentenceHeard(_ text: String, at date: Date) {
        guard !controller.playback.isSpeaking, !echo.isEcho(text, now: date) else { return }
        lastHeardAt = date
        schedulePrefetch()
        answerAhead(for: text)
    }

    func receiveFinalTranscript(_ text: String, at date: Date = Date()) {
        let before = conversation.finalSegments.count
        conversation.finalize(text, at: date, overlapsPlayback: controller.playback.isSpeaking)
        guard conversation.finalSegments.count > before, let segment = conversation.finalSegments.last else { return }
        finalObserver?(segment.text)
        if isComparing { return }
        if isOwnEcho(segment.text, at: date), !isWearerUsingSuggestion(segment.text, level: study.currentTurnLevelDBFS) {
            discardAhead(reason: "Lumen's own echo")
            return
        }
        if !segment.overlapsPlayback, VoiceCommand.isMusicHandOff(segment.text) {
            controller.log("Spoken pause: handing the audio back")
            Task { await controller.pause() }
            return
        }
        if !segment.overlapsPlayback, handleVoice(in: segment.text, at: date) {
            discardAhead(reason: "a voice command")
            return
        }
        if !segment.overlapsPlayback, isComplaintAboutLastAnswer(segment.text, now: date) {
            discardAhead(reason: "a complaint")
            study.discardTurnText()
            if study.isActive { study.resumeListening() }
            controller.log("Voice feedback: the last turn goes to /feedback")
            Task { await reportPreviousTurn() }
            return
        }
        if rizz != nil, RizzCommand.isNext(segment.text) {
            study.resumeListening()
            nextSuggestion()
            return
        }
        if rizz != nil, VoiceCommand.isReport(segment.text) {
            study.resumeListening()
            Task { await reportPreviousTurn() }
            return
        }
        if !segment.overlapsPlayback, saveSpokenCommand(segment.text) {
            return // "spara kommando …" is handled on the phone, never sent as a question
        }
        if study.isActive {
            // Provläge decides turns by silence, not by the question gate.
            study.transcriptFinal(segment.text, at: date)
            return
        }
        activation.segmentFinalized(segment, conversation: conversation, language: language,
                                    isPlaybackSpeaking: controller.playback.isSpeaking, now: date)
        scheduleQuestionTimer()
        if activation.pendingDueAt == nil { discardAhead(reason: "no question when the pause came") }
    }

    /// Voice-created command (D37): "spara kommando <ord>: <instruktion>". Confirms by voice.
    @discardableResult
    func saveSpokenCommand(_ text: String) -> Bool {
        guard let parsed = CommandMatcher.parseSaveCommand(text),
              let command = commands.save(keyword: parsed.keyword, instruction: parsed.instruction) else { return false }
        commandNotice = "Saved command \"\(command.keyword)\""
        controller.log("Command saved by voice: \(command.keyword) → \(command.instruction)")
        let confirmation = language == .swedish ? "Sparade kommandot \(command.keyword)." : "Saved the command \(command.keyword)."
        if case .paused = state { return true }
        speaker.enqueue(confirmation, language: language)
        return true
    }

    func receiveAnswer(question: String, answer: String, latencyMs: Double? = nil, source: String) {
        conversation.append(AnswerTurn(question: question, answer: answer, latencyMs: latencyMs, source: source))
    }
}
