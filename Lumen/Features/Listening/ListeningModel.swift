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
    /// A8.3: the Diagnostics turn rows of the answer in flight and of the answer made ahead.
    private var currentTurnID: UUID?
    private var aheadTurnID: UUID?
    /// A8.4: Provläge turns split from one utterance, asked one after another.
    private var studyQueue: [String] = []
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
    /// D81: who is speaking, by voice (the wearer's profile, "Talare 1/2"). Nil: by the level only, as before.
    let speakers: SpeakerIdentifier?
    /// D81: Provläge's questions as study cards, and the five-question test after a session.
    let studyCards: StudyCardStore?
    /// D81 (Kevin): cards and the test from the backend after a session. Nil: local cards only.
    let studyCardsClient: StudyCardsClient?
    /// D84 (Kevin): "Lumen, jag går i åk 9 …" → the profile and the subject's terms. Nil: the phone's reading only.
    let studyProfileClient: StudyProfileClient?
    /// D86: the exams the user added; the nearest is the start screen's card and Provläge's profile.
    let examPlans: ExamPlanStore?
    /// D86: Lyssnar is shown while a session runs; "Tillbaka" goes to Start with the session still on.
    var showsListeningScreen = true
    var isShowingAddExam = false
    /// D86 screen 6: what is wrong right now, in Swedish with what to do. Nil: nothing.
    private(set) var problem: LumenProblem?
    /// A5: the problems already said in the ear since the last answer that worked (each is said once).
    private var spokenProblems: Set<LumenProblem> = []
    /// A5: every failure with its code and time, newest last, for Diagnostik.
    struct Failure: Equatable, Sendable, Identifiable {
        let id = UUID()
        var at: Date
        var source: String
        var detail: String
    }
    private(set) var failures: [Failure] = []
    /// D87: what happens in a session, for the study-session recording in Diagnostik. Nil: nobody records.
    enum SessionEvent: Sendable {
        case heard(String)
        case asked(query: String, trigger: String)
        case answered(question: String, answer: String, firstTextMs: Double?, source: String)
        case spoke(String)
    }
    var sessionObserver: (@MainActor (SessionEvent, Date) -> Void)?
    /// D87: the wearer's Provläge turns (answered or not), for `context.recent_turns`; the exam they belong to.
    private(set) var studyTurns: [AnswerContext.Turn] = []
    private(set) var activeExamID: UUID?
    /// "Lägg till prov" → the microphone button: the next sentence is the exam, said aloud.
    private(set) var awaitingExamStatement = false
    /// D84: the practice exam inside Provläge, its uploaded paper and Kevin's `/exam`.
    let examMaterials: ExamMaterials?
    let examClient: ExamClient?
    private(set) var exam: ExamSession?
    private var examTimer: Task<Void, Never>?
    var isShowingExamSetup = false
    /// What Lumen has said of the current answer, for an interrupted turn (D81).
    private var spokenAnswer = ""
    private(set) var miniTest: MiniTest?
    /// The card whose answer the tutor is judging.
    private var gradingCardID: UUID?
    /// When the running Provläge session began, and the last one, so the mini test starts with its cards.
    private var provStartedAt: Date?
    private(set) var lastProvSessionStart: Date?
    /// "Lär dig min röst" is recording: what is said is the enrolment text, never a question.
    private(set) var isEnrollingVoice = false
    /// D81: battery and CPU per 10 minutes, in the log.
    private let resources = ResourceMeter()
    private var voiceWorkRunning = false
    /// Where the current turn's audio begins in the capture ring buffer (D81).
    private var turnAudioMark: Int64?
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
    /// A6: the user's own phrases per action (Settings › Röstkommandon) and the music players.
    let phrases: CommandPhraseStore
    let music: MusicRemote
    /// A9.1: which commands were used, and the one tip per session and day.
    let tips: CommandTipStore
    /// The tip on the screen, until the next answer.
    private(set) var tipNotice: String?
    private var tipTask: Task<Void, Never>?
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
         memoryExtractor: MemoryExtractor? = nil, studyProfile: StudyProfileStore? = nil,
         speakers: SpeakerIdentifier? = nil, studyCards: StudyCardStore? = nil, studyCardsClient: StudyCardsClient? = nil,
         studyProfileClient: StudyProfileClient? = nil, examMaterials: ExamMaterials? = nil, examClient: ExamClient? = nil,
         examPlans: ExamPlanStore? = nil, phrases: CommandPhraseStore? = nil, music: MusicRemote? = nil,
         tips: CommandTipStore? = nil) {
        self.tips = tips ?? CommandTipStore(defaults: UserDefaults(suiteName: "lumen.tips.\(UUID().uuidString)") ?? .standard)
        self.phrases = phrases ?? CommandPhraseStore(defaults: UserDefaults(suiteName: "lumen.phrases.\(UUID().uuidString)") ?? .standard,
                                                     book: CommandBook())
        self.music = music ?? MusicRemote(players: [])
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
        self.speakers = speakers
        self.studyCards = studyCards
        self.studyCardsClient = studyCardsClient
        self.studyProfileClient = studyProfileClient
        self.examMaterials = examMaterials
        self.examPlans = examPlans
        self.examClient = examClient
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
        transcription.onStatusChanged = { [weak self] status in self?.recognitionChanged(status) }
        activation.onDrop = { [weak self] text, reason in
            guard let self else { return }
            self.controller.turns.dropped(text, mode: self.mode.rawValue, trigger: "auto", reason: reason)
        }
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
        speaker.onSpeak = { [weak self] text in
            self?.echo.record(text, at: Date())
            self?.sessionObserver?(.spoke(text), Date())
            self?.spokenAnswer += text + " "
        }
        // D82 (owner): the app only hears itself when the sound goes out of the iPhone's own speaker. Echo
        // cancellation then, never with AirPods or headphones, so their microphone keeps its quality.
        controller.voiceProcessingPolicy = { [weak self] snapshot in
            (self?.microphone.echoCancellation ?? true) && snapshot.outputsToBuiltInSpeaker
        }
        speaker.onFinished = { [weak self] in self?.speechFinished() }
        speaker.onVoiceStats = { [weak self] stats in self?.controller.log("Röst: \(stats.summary)") } // A4
        speaker.onVoiceFallback = { [weak self] detail in
            self?.recordFailure(source: "tts", detail: detail)
            if self?.problem == nil { self?.report(problem: .voiceUnavailable) }
        }
        speaker.onVoiceRecovered = { [weak self] in
            if self?.problem == .voiceUnavailable { self?.problem = nil }
        }
        controller.keepsListeningWhenOutputLost = { [weak self] in !(self?.microphone.pauseWhenAirPodsLost ?? true) }
        controller.onOutputLost = { [weak self] in self?.report(problem: .airPodsDisconnected) }
        controller.onOutputRestored = { [weak self] in
            if self?.problem == .airPodsDisconnected { self?.problem = nil }
        }
        speakers?.onIdentified = { [weak self] identity, date in self?.voiceIdentified(identity, at: date) }
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
        tips.sessionStarted()
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
        let terms = KeytermBuilder.terms(commands: phrases.userPhrases + commands.commands.map(\.keyword),
                                         topic: recent.last?.question,
                                         answers: recent.map(\.answer),
                                         goals: goals.terms,
                                         memory: memory.facts.map(\.text),
                                         prep: (studyProfile.profile.terms ?? []) + prep.sttTerms)
        let rest = terms + prep.sttTerms + (studyProfile.profile.terms ?? [])
        // D87: in Provläge the active exam's words go first, so Scribe hears them right from the first word.
        let exam = mode == .prov ? ExamKeyterms.terms(profile: studyProfile.profile) : []
        transcription.setContextualStrings(ExamKeyterms.merged(exam: exam, rest: rest))
    }

    /// Raw capture for the Diagnostics recording (D78), the same audio the recogniser gets before any gate.
    func subscribeToAudio() -> (id: UUID, stream: AsyncStream<AudioChunk>) {
        controller.subscribeToChunks()
    }

    func unsubscribeFromAudio(_ id: UUID) {
        controller.unsubscribeFromChunks(id)
    }

    func stopListening() async {
        answers.sessionLength = nil
        activation.cancelPending()
        studyQueue.removeAll()
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
        case .paused(.outputDeviceLost):
            problem = .airPodsDisconnected
        case .error(let message) where message.localizedCaseInsensitiveContains("permission"):
            problem = .microphoneDenied
        case .listening:
            if problem == .microphoneDenied || problem == .airPodsDisconnected { problem = nil }
        default:
            break
        }
        switch state {
        case .listening:
            beginVoiceWork()
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
            endVoiceWork()
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
                                                                currentSuggestion: rizz?.index ?? 0,
                                                                title: activityTitle,
                                                                latestAnswer: conversation.answers.last.map { String($0.answer.prefix(120)) }))
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
        refreshKeyterms() // D87: before Scribe (re)connects for this mode
        await useMicrophone(for: newMode)
        if !isListening {
            if canResume { await resume() } else { await startListening() }
            guard isListening else { return }
        }
        answers.cancel()
        speaker.interrupt()
        conversation.cancelAnswer()
        study.endpointSilence = modeSettings.pause(for: newMode) // D80: the user's pause ends the turn
        if newMode == .prov { await transcription.applyKeytermsNow() } // D87: the exam's words from the first one
        if let style = newMode.liveStyle {
            rizz = RizzSession(style: style)
            study.stallSilence = Self.stallSilence
            study.speechDetector = { [weak self] in self?.transcription.vadSpeaking() } // D82.2
            applySpeechVolume()
        } else {
            study.stallSilence = nil
            study.speechDetector = nil
        }
        study.start()
        if newMode == .prov, miniTest == nil { provStartedAt = Date() }
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

    /// D84: "Lumen, jag går i åk 9 och ska snart ha prov i biologi". The phone's reading answers at once ("Biologi
    /// åk 9, sparat."); Kevin's `/study-profile` then adds the subject's terms and what the phone could not read.
    private func profileStatement(_ text: String) {
        var profile = studyProfile.profile
        let local = ProfileStatement.parse(text)
        if let local {
            local.apply(to: &profile)
            studyProfile.profile = profile
            studyProfileChanged()
            saveSpokenExam(profile)
            say(local.confirmation())
            controller.log("Profile by voice (phone): \(local.confirmation())")
        }
        guard let studyProfileClient else {
            if local == nil { say(language == .swedish ? "Jag uppfattade inte vad du läser." : "I did not catch what you study.") }
            return
        }
        let body = StudyProfileClient.body(text: text, profile: studyProfile.profile, swedish: language == .swedish)
        Task { [weak self] in
            let reply = await studyProfileClient.read(body)
            guard let self else { return }
            guard let reply else {
                if local == nil { self.say(self.language == .swedish ? "Jag uppfattade inte vad du läser." : "I did not catch what you study.") }
                return
            }
            var updated = self.studyProfile.profile
            reply.apply(to: &updated)
            self.studyProfile.profile = updated
            self.studyProfileChanged()
            self.saveSpokenExam(updated)
            self.controller.log("Profile by voice (server): \(reply.terms.count) terms")
            if local == nil {
                let heard = ProfileStatement(grade: updated.grade, course: updated.course.isEmpty ? nil : updated.course,
                                             subject: updated.subject.isEmpty ? nil : updated.subject, examDate: updated.examDate)
                if !heard.isEmpty { self.say(heard.confirmation()) }
            }
        }
    }

    /// D86: a said exam with a subject and a date is one of the saved exams too.
    private func saveSpokenExam(_ profile: StudyProfile) {
        guard let examPlans, !profile.subject.isEmpty, let date = profile.examDate, !profile.noExam else { return }
        examPlans.save(ExamPlan(grade: profile.grade, course: profile.course, area: .of(subject: profile.subject),
                                subject: profile.subject, date: date, topics: profile.topics ?? ""))
    }

    /// D87: a Provläge turn; answered or not is filled in when the answer is complete.
    private func recordStudyTurn(_ text: String) {
        studyTurns.append(AnswerContext.Turn(text: text, answered: false))
        if studyTurns.count > 10 { studyTurns.removeFirst(studyTurns.count - 10) }
    }

    /// The last three turns before `query` (the turn being answered is the fragment, not a recent turn).
    private func turnsBefore(_ query: String) -> [AnswerContext.Turn] {
        var turns = studyTurns
        if let last = turns.last, AheadAnswer.key(last.text) == AheadAnswer.key(query) { turns.removeLast() }
        return Array(turns.suffix(AnswerContext.turnLimit))
    }

    /// The exam being studied: the one chosen, else the nearest exam in the profile's subject.
    func currentExamID() -> UUID? {
        if let activeExamID, examPlans?.plans.contains(where: { $0.id == activeExamID }) == true { return activeExamID }
        let subject = studyProfile.profile.subject
        return examPlans?.upcoming().first { $0.subject.caseInsensitiveCompare(subject) == .orderedSame }?.id
    }

    /// D86 "Spara prov": kept with the others, and Provläge's profile from now on. The subject's terms follow.
    func saveExamPlan(_ plan: ExamPlan) {
        examPlans?.save(plan)
        useExamPlan(plan)
        controller.log("Exam saved: \(plan.name), \(plan.daysLeft()) days")
    }

    /// Provläge for this exam: its grade, subject, date and topics become the profile.
    func useExamPlan(_ plan: ExamPlan) {
        if activeExamID != plan.id { studyTurns = [] } // another exam: its turns are not this one's
        activeExamID = plan.id
        var profile = studyProfile.profile
        plan.apply(to: &profile)
        profile.onboarded = true
        profile.terms = nil
        studyProfile.profile = profile
        studyProfileChanged()
        guard let studyProfileClient else { return }
        let body = StudyProfileClient.body(text: "", profile: profile, swedish: language == .swedish)
        Task { [weak self] in
            guard let reply = await studyProfileClient.read(body), let self else { return }
            var updated = self.studyProfile.profile
            if !reply.terms.isEmpty { updated.terms = Array(reply.terms.prefix(50)) }
            self.studyProfile.profile = updated
            self.refreshKeyterms()
        }
    }

    /// D86 start screen: an exam row's microphone, or "Få A-svar till provet".
    func startProv(for plan: ExamPlan) async {
        useExamPlan(plan)
        selectedMode = .prov
        await startStudy()
    }

    /// "Lägg till prov" → "Eller säg det": listen, and the next sentence about an exam is saved as one.
    func listenForExamStatement() async {
        awaitingExamStatement = true
        if !isListening {
            if canResume { await resume() } else { await startListening() }
        }
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
        applySpeechVolume()
        answers.sessionLength = nil // A7: "svara kortare" lasts one session
        mode = .standard
    }

    /// Ends the session. After the silence timeout the microphone is released too ("sparläge").
    func endStudy(bySilence: Bool) {
        guard study.isActive || bySilence else { return }
        let endedProv = mode == .prov
        if endedProv, exam != nil { finishExam(speak: false) }
        study.stop()
        if endedProv { provSessionEnded() }
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
            // D81: the turn's audio, from a little before the onset hold.
            let written = controller.capture.ringBuffer.totalWritten
            turnAudioMark = max(0, written - Int64(0.3 * LumenAudioFormat.sampleRate))
        case .endOfTurn(let raw):
            defer { turnAudioMark = nil }
            if isEnrollingVoice {
                study.resumeListening() // the enrolment text, never a turn
                return
            }
            if speakers?.identity(near: Date(), window: 3) == nil { identifySpeech(at: Date()) }
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
            if mode == .prov, miniTest != nil {
                miniTestAnswer(text)
                return
            }
            if mode == .prov, exam != nil {
                controller.log("Provsession: not a command, not answered") // Auto off: only "Lumen, …" counts
                study.resumeListening()
                return
            }
            switch mode {
            case .interview: interviewTurn(text)
            case .rizz, .social: rizzTurn(text)
            case .standard, .prov:
                headMotion.stop() // answered with the voice
                // A8.4: several questions in one breath are separate turns, each with its own answer.
                var parts = QuestionSplitter.split(text)
                let first = parts.isEmpty ? text : parts.removeFirst()
                if !parts.isEmpty { controller.log("\(mode.rawValue): one turn split into \(parts.count + 1) parts") }
                studyQueue = parts
                activated(ActivationRequest(query: first, trigger: .tutor, language: language), persona: mode == .prov ? tutorPersona() : nil)
                if mode == .prov { recordStudyTurn(first) }
            }
        case .stalled:
            if let session = rizz { requestSuggestions(trigger: session.hasConversation ? "stall" : "opener") }
        case .bargeIn:
            // D81: with a voice profile, only the wearer's own voice stops Lumen; someone else talking does not.
            if let speakers, speakers.profiles.isEnrolled, speakers.isReady {
                study.speechStarted() // keep speaking until the voice is known (one embedding, tens of ms)
                let samples = controller.capture.ringBuffer.snapshot(lastSeconds: 1.2)
                Task { [weak self] in
                    let wearer = await speakers.isWearer(samples)
                    guard let self, self.speaker.isSpeaking || self.speaker.hasPendingSpeech else { return }
                    if wearer == false {
                        self.controller.log("Barge-in ignored: not the wearer's voice (D81)")
                        return
                    }
                    self.bargeIn()
                    self.study.resumeListening()
                }
                return
            }
            bargeIn()
        case .autoEnded:
            endStudy(bySilence: true)
        }
    }

    // MARK: - Intervjuläge (D42)

    /// D72: the interviewer's question gets the finished answer, read aloud, and nothing else: no feedback, no
    /// follow-up questions. The wearer's own words (louder, by input level) are never answered, unless they ask for
    /// something out loud ("klar", "sammanfatta", "ge mig feedback").
    private func interviewTurn(_ text: String) {
        let (speaker, why) = turnSpeaker(level: study.lastTurnLevelDBFS)
        if speaker == .user, !VoiceCommand.isInterviewRequest(text) {
            controller.log("Intervjuläge: own turn (\(why)), not answered")
            study.resumeListening()
            return
        }
        activated(ActivationRequest(query: text, trigger: .overheard, language: language),
                  persona: PersonaRequest(persona: "interview", setup: modeSettings.interviewPersonaSetup, turn: "question"))
    }

    /// Likely questions and model answers from the role or job ad. Long, so it is shown, not spoken.
    func prepareInterview() {
        activated(ActivationRequest(query: language == .swedish ? "Förbered mig inför intervjun" : "Prepare me for the interview",
                                    trigger: .interviewPrep, language: language),
                  persona: PersonaRequest(persona: "interview", setup: modeSettings.interviewPersonaSetup))
    }

    // MARK: - Rizzläge (D43)

    private func rizzTurn(_ text: String) {
        let (speaker, why) = turnSpeaker(level: study.lastTurnLevelDBFS)
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
        session.add(speaker, text: text, at: Date(), label: liveLabel())
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
            // A8: Lumen is speaking: the question waits for the end of the answer (speechFinished), never dropped.
            if self.controller.playback.isSpeaking || self.speaker.hasPendingSpeech { return }
            if case .answering = self.answers.status { return } // asked when this answer is over
            if !self.activation.fireDue(now: Date()) { self.scheduleQuestionTimer() } // the cooldown moved it
        }
    }

    /// "Lumen, …" in every mode. True when the words were for Lumen: they are never conversation.
    @discardableResult
    private func handleVoice(in text: String, at date: Date) -> Bool {
        let utterance = VoiceChannel.parse(text)
        guard let intent = utterance.intent ?? universalIntent(text) else { return false }
        study.discardTurnText()
        if let before = utterance.before, study.isActive { study.transcriptFinal(before, at: date) }
        perform(intent)
        return true
    }

    /// A7: "upprepa", "viska", "kortare", "utveckla" … as the whole utterance count without "Lumen", only in
    /// Provläge and Frågor (the speaker is the user there) and only with the setting on.
    private func universalIntent(_ text: String) -> VoiceIntent? {
        guard mode == .prov || mode == .standard, speaker.settings.universalCommands,
              let action = CommandBook.shared.table.universal(text) else { return nil }
        return action.level == 1 ? .command(action) : .instruction(action.instruction)
    }

    /// A9.1: a used command is never tipped.
    private func markUsed(_ intent: VoiceIntent) {
        switch intent {
        case .switchTo: tips.markUsed(.switchMode)
        case .pause: tips.markUsed(.musicHandOff)
        case .stopListening: tips.markUsed(.stop)
        case .music(let action), .command(let action): tips.markUsed(action)
        case .complaint: tips.markUsed(.wrong)
        case .instruction(let text):
            if let action = CommandAction.allCases.first(where: { $0.level == 2 && $0.instruction == text }) { tips.markUsed(action) }
            else if text.hasPrefix("förhör mig") { tips.markUsed(.quizMe) }
        case .remember, .forget, .rule: break
        }
    }

    /// A9.1: after an answer, in a natural pause, at most one tip per session and per day. Never during an exam
    /// session, a mini test, Intervjuläge's question or while anything is heard or said.
    private func scheduleTip() {
        tipTask?.cancel()
        guard tips.enabled, !tips.tippedThisSession, conversation.answers.count >= 2 else { return }
        tipTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.tipPause))
            guard let self, !Task.isCancelled, self.isListening else { return }
            let quietFor = self.lastHeardAt.map { Date().timeIntervalSince($0) } ?? .infinity
            var busy = self.exam != nil || self.miniTest != nil || self.speaker.isSpeaking || self.speaker.hasPendingSpeech
                || self.activation.pendingDueAt != nil || self.activation.hasQueued || quietFor < Self.tipPause
            if case .answering = self.answers.status { busy = true }
            guard let action = self.tips.next(for: self.mode, busy: busy) else { return }
            let text = CommandTips.tip(action, table: CommandBook.shared.table)
            self.tips.tipped(action)
            self.tipNotice = text
            self.controller.log("Tip: \(action.rawValue)")
            self.say(text)
        }
    }

    static let tipPause: TimeInterval = 4

    /// The listening screen's line: the three most useful commands for the mode, from the command table.
    func commandsLine(for shown: ConversationMode) -> String {
        CommandTips.line(for: shown, table: CommandBook.shared.table)
    }

    private func perform(_ intent: VoiceIntent) {
        let now = Date()
        if let last = lastVoice, last.intent == intent, now.timeIntervalSince(last.at) < 5 { return }
        lastVoice = (intent, now)
        markUsed(intent)
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
        case .music(let action):
            controller.log("Voice: music \(action.rawValue)")
            Task { await musicByVoice(action) }
        case .complaint:
            controller.log("Voice feedback: the last turn goes to /feedback")
            Task { await reportPreviousTurn() }
        case .command(let action):
            controller.log("Voice: command \(action.rawValue)")
            runCommand(action)
        }
    }

    /// A7 level 1: done on the phone, no API call. Confirmed briefly, only when nothing else is being said.
    func runCommand(_ action: CommandAction) {
        func confirm(_ line: String?) {
            guard let line, !speaker.isSpeaking, !speaker.hasPendingSpeech else { return }
            say(line)
        }
        switch action {
        case .repeatAnswer:
            repeatLastAnswer()
        case .whisper, .louder:
            let settings = speaker.settings
            if action == .louder, settings.speechGain >= 1 {
                confirm("Det är redan högsta volymen i Lumen. Höj på telefonen.")
                return
            }
            settings.speechGain = action == .whisper ? settings.speechGain * 0.6 : settings.speechGain / 0.6
            applySpeechVolume()
            controller.log("Voice gain \(String(format: "%.2f", settings.speechGain))")
            confirm(action.confirmation)
        case .shorter, .longer:
            answers.sessionLength = action == .shorter ? .short : .long
            controller.log("Session length \(answers.sessionLength?.rawValue ?? "-")")
            confirm(action.confirmation)
        case .saveAnswer:
            confirm(saveNote() != nil ? action.confirmation : "Det finns inget svar att spara.")
        case .nextExam:
            if let plan = examPlans?.nearest() {
                say("\(plan.name), \(plan.whenLine()).")
            } else {
                say("Du har inget prov inlagt.")
            }
        default:
            break
        }
    }

    /// A7 "upprepa": the last answer's audio again from memory (no TTS call). Recorded while the answer played.
    private func repeatLastAnswer() {
        do {
            transcription.setInputGated(true) // our own voice again: the recogniser must not hear it
            if try controller.playback.replayRecordedSpeech() {
                controller.log("Repeat: the last answer from memory")
                reopenRecognizerAfterSpeech()
                return
            }
        } catch {
            controller.log("Repeat failed: \(error.localizedDescription)")
        }
        transcription.setInputGated(false)
        if let last = conversation.answers.last?.answer, !last.isEmpty {
            controller.log("Repeat: nothing kept, the text is spoken again")
            speaker.enqueue(last, language: language)
        } else {
            say("Det finns inget svar att upprepa.")
        }
    }

    /// A7: Lumen's loudness = the mode's level (Rizzläge speaks quietly, D43) × the user's "viska"/"högre".
    private func applySpeechVolume() {
        controller.playback.speechVolume = (rizz != nil ? Self.rizzVolume : 1) * Float(speaker.settings.speechGain)
    }

    /// A6: "nästa låt" / "förra låten" hand the audio to the music and skip; "pausa musiken" is true already while
    /// Lumen listens (the music waits for us, D58); "tillbaka till Lumen" while listening only confirms.
    func musicByVoice(_ action: CommandAction) async {
        switch action {
        case .backToLumen:
            if isListening { say(action.confirmation ?? "") } else { await resume() }
        case .pauseMusic:
            if isListening {
                say(action.confirmation ?? "")
            } else {
                music.perform(.pauseMusic)
            }
        case .nextTrack, .previousTrack:
            guard isListening else {
                music.perform(action)
                return
            }
            let controllable = music.players.contains(where: \.isAvailable)
            say(controllable ? (action.confirmation ?? "") : "Musiken spelar. Tryck två gånger på AirPods för att byta låt.")
            await speechDone()
            await controller.pause() // the music comes back when Lumen lets go
            try? await Task.sleep(for: .milliseconds(800))
            music.perform(action)
        default:
            break
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
        if target == .interview, !modeSettings.hasInterviewSetup {
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
        if exam != nil {
            examCommand(text) // D84: in the exam session only exam commands count
            return
        }
        if MiniTest.isCheckQuestionRequest(text), study.isActive, mode == .prov {
            // D86: one check question; the wearer's answer is an ordinary Provläge turn.
            activated(ActivationRequest(query: MiniTest.checkQuestionQuery(swedish: language == .swedish), trigger: .tutor, language: language),
                      persona: tutorPersona())
            return
        }
        if MiniTest.isStartCommand(text) {
            Task { await startMiniTest() }
            return
        }
        if ProfileStatement.isAboutSchool(text) {
            profileStatement(text) // D84: in every mode
            return
        }
        if rizz != nil {
            liveInstruction(text)
        } else if study.isActive, mode == .interview {
            activated(ActivationRequest(query: text, trigger: .overheard, language: language),
                      persona: PersonaRequest(persona: "interview", setup: modeSettings.interviewPersonaSetup, turn: "question"))
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
        if let speakers, speakers.profiles.isEnrolled, speakers.identity(near: turn.createdAt, window: 8)?.isOther == true {
            controller.log("Minne: not the wearer's voice (D81), nothing extracted")
            return
        }
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
        controller.playback.stopRecordingSpeech()
        if study.isActive, finishSingleTurn() { return }
        reopenRecognizerAfterSpeech()
        listenForHeadAnswerIfAsked()
        if !study.isActive { askWaitingQuestionIfIdle() }
        scheduleTip()
    }

    /// A8: a question that waited (cooldown, Lumen speaking, or split from the same utterance) goes now that the
    /// answer before it is over. Frågor only; Provläge asks its split turns when it would listen again.
    private func askWaitingQuestionIfIdle() {
        guard !study.isActive, isListening, !speaker.isSpeaking, !speaker.hasPendingSpeech else { return }
        if case .answering = answers.status { return }
        if activation.pendingDueAt != nil {
            if !activation.fireDue(now: Date()) { scheduleQuestionTimer() }
            return
        }
        activation.fireNextQueued(now: Date())
    }

    /// A8.4: the next turn split from the same utterance, instead of listening again. True: it was asked.
    private func askNextStudyPart() -> Bool {
        guard study.isActive, mode == .prov || mode == .standard, !studyQueue.isEmpty else { return false }
        let next = studyQueue.removeFirst()
        controller.log("\(mode.rawValue): next part of the same turn: \(next)")
        activated(ActivationRequest(query: next, trigger: .tutor, language: language), persona: mode == .prov ? tutorPersona() : nil)
        if mode == .prov { recordStudyTurn(next) }
        return true
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
            if self.study.isActive, !self.askNextStudyPart() { self.study.resumeListening() }
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
        if !askNextStudyPart() { study.resumeListening() }
    }

    // MARK: - Voice profile and speakers (D81)

    /// Settings → "Lär dig min röst": about 10 s of the wearer reading aloud.
    static let enrollSeconds: Double = 10

    func enrollVoice() async -> SpeakerIdentifier.EnrollResult? {
        guard let speakers, consent.isGranted else { return nil }
        isEnrollingVoice = true
        defer { isEnrollingVoice = false }
        if !isListening {
            if canResume { await resume() } else { await startListening() }
        }
        guard isListening else { return nil }
        speakers.loader.loadIfNeeded()
        let mark = controller.capture.ringBuffer.totalWritten
        try? await Task.sleep(for: .seconds(Self.enrollSeconds))
        let samples = controller.capture.ringBuffer.snapshot(since: mark)
        let result = await speakers.enroll(samples)
        controller.log("Voice profile: \(result)")
        return result
    }

    func deleteVoiceProfile() {
        speakers?.deleteProfile()
        controller.log("Voice profile deleted")
    }

    /// The stretch that just ended goes to the embedder; the result comes back through `voiceIdentified`.
    private func identifySpeech(at date: Date) {
        guard let speakers, speakers.isWanted, speakers.isReady else { return }
        let ring = controller.capture.ringBuffer
        var samples = turnAudioMark.map { ring.snapshot(since: $0) } ?? ring.snapshot(lastSeconds: 4)
        let maximum = Int(SpeakerIdentifier.maximumSeconds * LumenAudioFormat.sampleRate)
        if samples.count > maximum { samples = Array(samples.suffix(maximum)) }
        speakers.identify(samples, at: date)
    }

    private func voiceIdentified(_ identity: VoiceIdentity, at date: Date) {
        labelTranscript(identity, at: date)
    }

    private func labelTranscript(_ identity: VoiceIdentity, at date: Date) {
        guard speakers?.showsLabels == true, let label = SpeakerLabeler.text(identity, swedish: language == .swedish) else { return }
        conversation.label(label, near: date)
    }

    /// "Talare 1" for Socialt läge / Rizzläge (Kevin D81), when the labels are on and the voice is known.
    private func liveLabel() -> String? {
        guard let speakers, speakers.showsLabels, let identity = speakers.identity(near: Date()), identity.isOther else { return nil }
        return SpeakerLabeler.text(identity, swedish: true)
    }

    /// The voice when it is known and there is a profile to compare with; otherwise the level, as before D81.
    private func turnSpeaker(level: Double?) -> (speaker: RizzSpeaker, why: String) {
        if let speakers, speakers.profiles.isEnrolled, let identity = speakers.identity(near: Date()), identity != .uncertain {
            return identity.isWearer ? (.user, "voice profile → wearer") : (.other, "voice → not the wearer")
        }
        let threshold = modeSettings.speakerThresholdDBFS
        return (RizzSpeaker.tag(levelDBFS: level, thresholdDBFS: threshold), RizzSpeaker.reason(levelDBFS: level, thresholdDBFS: threshold))
    }

    /// The words just heard were the wearer's, by the voice profile. False when not known.
    private func isWearersVoice(near date: Date = Date()) -> Bool {
        guard let speakers, speakers.profiles.isEnrolled else { return false }
        return speakers.identity(near: date)?.isWearer == true
    }

    private func bargeIn() {
        controller.log("\(mode.rawValue): barge-in — stopping the answer")
        answers.cancel()
        speaker.interrupt()
        // Kevin D81: what was said goes along as `interrupted`, so the next answer never repeats it.
        conversation.interruptAnswer(said: spokenAnswer)
        spokenAnswer = ""
        latency.end()
        transcription.setInputGated(false)
    }

    private func beginVoiceWork() {
        guard !voiceWorkRunning else { return }
        voiceWorkRunning = true
        speakers?.sessionStarted()
        resources.start { [weak self] from, to in self?.logResources(from: from, to: to) }
    }

    private func endVoiceWork() {
        voiceWorkRunning = false
        resources.stop()
    }

    private func logResources(from: ResourceSample, to: ResourceSample) {
        var line = "Resources · " + ResourceSample.line(from: from, to: to)
        if let speakers {
            let stats = speakers.takeStats()
            line += " · voice \(stats.count) embeddings, avg \(Int(stats.averageMs)) ms"
            line += " · labels \(speakers.showsLabels ? "on" : "off") · profile \(speakers.profiles.isEnrolled ? "yes" : "no")"
        }
        controller.log(line)
    }

    // MARK: - D86 screens

    /// Offline and transport errors are "Ingen internetanslutning"; every other failure is "Försök igen om en minut".
    nonisolated static func problem(for error: AnswerError?) -> LumenProblem? {
        switch error {
        case .offline?: .offline
        case .cancelled?, nil: nil
        default: .overloaded // credits out, the provider down, too slow, anything else: "Jag kan inte svara just nu"
        }
    }

    /// Shown on the card, and said in the ear once (in Apple's voice) until an answer has worked again (A5).
    /// A11: the recogniser is not running while we listen: after 3 s the screen says so (never "Lyssnar") and the ear
    /// hears it once; it clears when recognition runs again. Short gaps (a reconnect) say nothing.
    private var hearingTask: Task<Void, Never>?

    var isHearing: Bool {
        switch transcription.status {
        case .running, .preparing, .probing: true
        case .idle: !isListening
        case .failed, .unavailable: false
        }
    }

    private func recognitionChanged(_ status: TranscriptionCoordinator.Status) {
        hearingTask?.cancel()
        if status.isRunning {
            if problem == .cannotHear {
                problem = nil
                spokenProblems.remove(.cannotHear)
                controller.log("Recognition is back")
            }
            return
        }
        hearingTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard let self, !Task.isCancelled, self.isListening, !self.isHearing else { return }
            self.controller.log("Not hearing: \(String(describing: self.transcription.status))")
            self.report(problem: .cannotHear)
        }
    }

    private func report(problem new: LumenProblem?) {
        guard let new else { return }
        problem = new
        guard let line = new.spoken, !spokenProblems.contains(new) else { return }
        spokenProblems.insert(new)
        if case .paused = state { return }
        speaker.announce(line, language: language)
    }

    #if DEBUG
    /// A2/A5 screenshots only.
    func showProblemForScreenshot(_ shown: LumenProblem) { problem = shown }
    #endif

    /// A5: an answer worked: the problem is over, and the next one is said again.
    private func answerWorked() {
        spokenProblems.removeAll()
        if problem == .overloaded || problem == .offline { problem = nil }
    }

    private func recordFailure(source: String, detail: String) {
        failures.append(Failure(at: Date(), source: source, detail: detail))
        if failures.count > 30 { failures.removeFirst(failures.count - 30) }
        controller.log("Fel (\(source)): \(detail)")
    }

    /// The card's button.
    func act(on problem: LumenProblem) {
        switch problem {
        case .microphoneDenied:
            ErrorCard.openSettings()
        case .airPodsDisconnected:
            Task { await controller.pause() }
            self.problem = nil
        case .voiceUnavailable:
            self.problem = nil
        case .overloaded:
            self.problem = nil
            if let question = conversation.answers.last?.question ?? pendingQuestion?.query, !question.isEmpty {
                activated(ActivationRequest(query: question, trigger: pendingQuestion?.trigger ?? .text, language: language),
                          persona: mode == .prov ? tutorPersona() : nil)
            }
        case .offline, .cannotHear:
            self.problem = nil
        }
    }

    /// The short notices under the answers, in Swedish.
    var visibleNotices: [String] {
        [studyNotice, reportNotice].compactMap { $0 }
    }

    /// The Live Activity's title: the exam in Provläge, else the mode.
    private var activityTitle: String {
        if study.isActive, mode == .prov, let plan = examPlans?.upcoming().first(where: {
            $0.subject.caseInsensitiveCompare(studyProfile.profile.subject) == .orderedSame
        }) { return plan.name }
        return (study.isActive ? mode : .standard).shortName
    }

    /// Start's round buttons: Frågor listens at once; the other modes go through their gates and start screens.
    func startMode(_ target: ConversationMode) async {
        if study.isActive || isListening {
            await switchMode(to: target)
            return
        }
        selectedMode = target
        if target == .standard {
            if canResume { await resume() } else { await startListening() }
        } else {
            await toggleSelectedMode()
        }
        showsListeningScreen = true
    }

    /// "Byt läge": the same checks as the screen and the voice; listening goes on.
    func switchMode(to target: ConversationMode) async {
        if target == .rizz, !modeSettings.isAdultConfirmed {
            selectedMode = .rizz
            isShowingAgeGate = true
            return
        }
        if target.isLive, !modeSettings.hasConfirmedLiveStart(target) {
            selectedMode = target
            isShowingLiveStart = true
            return
        }
        if target == .interview, !modeSettings.hasInterviewSetup {
            selectedMode = .interview
            isShowingInterviewSetup = true
            return
        }
        await switchByVoice(to: target)
    }

    /// "Avsluta" (app, lock screen, voice): ends the mode and the microphone.
    func endSession() async {
        if study.isActive { endStudy(bySilence: false) }
        await stopListening()
        problem = nil
    }

    /// "Öva mer på": what Provläge or the exam session found weak, else the cards answered wrong, else the topics.
    func practiseHint(for plan: ExamPlan) -> String? {
        let prefix = "Provträning: öva på uppgifter som "
        if let fact = memory.facts.last(where: { $0.text.hasPrefix(prefix) }) {
            return String(fact.text.dropFirst(prefix.count)).trimmingCharacters(in: CharacterSet(charactersIn: "\"…"))
        }
        if let cards = studyCards?.current().filter({ $0.wrong > $0.right && ($0.subject ?? plan.subject) == plan.subject }), !cards.isEmpty {
            return cards.prefix(2).map(\.question).joined(separator: " och ")
        }
        return plan.topics.isEmpty ? nil : plan.topics
    }

    // MARK: - The exam session (D84)

    /// Starts Provläge with the uploaded exam. Nothing is answered except "Lumen, …" exam commands.
    func startExam() async {
        guard let examMaterials, examMaterials.isReady else { return }
        isShowingExamSetup = false
        if !(study.isActive && mode == .prov) {
            selectedMode = .prov
            await startStudy()
            guard study.isActive else { return }
        }
        miniTest = nil
        exam = ExamSession(paper: examMaterials.paper)
        controller.log("Provsession started (\(examMaterials.paper.tasks.count) tasks)")
        say(language == .swedish
            ? "Provsession, \(examMaterials.paper.tasks.count) uppgifter. Säg Lumen, uppgift ett. Eller Lumen, starta provtid nittio minuter."
            : "Exam session, \(examMaterials.paper.tasks.count) tasks. Say Lumen, task one.")
    }

    private func examCommand(_ text: String) {
        guard var session = exam else { return }
        if let speakers, speakers.profiles.isEnrolled, speakers.identity(near: Date())?.isOther == true {
            controller.log("Provsession: a command in someone else's voice, ignored")
            return
        }
        guard let command = ExamSession.command(text) else {
            say("Säg uppgift, ledtråd, rätta, nästa, starta provtid eller hur gick det.")
            return
        }
        switch command {
        case .task(let no):
            if let task = session.go(to: no) { say(ExamSession.spoken(task)) } else { say("Hittar ingen uppgift \(no).") }
        case .next:
            if let task = session.next() { say(ExamSession.spoken(task)) } else { say("Det var sista uppgiften.") }
        case .hint:
            guard let task = session.currentTask, let level = session.nextHintLevel(), let examClient else {
                say("Säg först vilken uppgift, till exempel uppgift tre.")
                return
            }
            Task { [weak self] in
                let hint = await examClient.hint(task: task, level: level)
                self?.say(hint ?? "Jag fick ingen ledtråd just nu.")
            }
        case .grade(let answer):
            guard let task = session.currentTask, let examClient else {
                say("Säg först vilken uppgift, till exempel uppgift tre.")
                return
            }
            Task { [weak self] in
                guard let graded = await examClient.grade(task: task, answer: answer) else {
                    self?.say("Jag kunde inte rätta just nu.")
                    return
                }
                guard let self, var current = self.exam else { return }
                current.graded(graded.points)
                self.exam = current
                let got = ExamSession.number(graded.points.total)
                let of = ExamSession.number((graded.max ?? task.points).total)
                self.say("\(got) av \(of) poäng. \(graded.feedback)")
                self.controller.log("Provsession: task \(task.no) graded \(got)/\(of)")
            }
        case .startTimer(let minutes):
            session.startTimer(minutes: minutes, at: Date())
            say("Provtid \(minutes) minuter. Lycka till.")
            startExamTimer()
        case .howDidItGo:
            speakExamSummary(of: session)
        case .end:
            exam = session
            finishExam(speak: true)
            return
        }
        exam = session
    }

    private func startExamTimer() {
        examTimer?.cancel()
        examTimer = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(10))
                guard let self, var session = self.exam, !Task.isCancelled else { return }
                if let warning = session.warning(at: Date()) { self.say(warning) }
                self.exam = session
                if session.minutesLeft(at: Date()) == 0 { return }
            }
        }
    }

    private func speakExamSummary(of session: ExamSession) {
        let results = session.resultList
        guard !results.isEmpty else {
            say("Inga uppgifter rättade än. Säg rätta och ditt svar.")
            return
        }
        guard let examClient else { return }
        let boundaries = session.paper.boundaries
        Task { [weak self] in
            let summary = await examClient.summary(results: results, boundaries: boundaries)
            self?.say(summary?.spoken ?? "Jag kunde inte räkna ihop just nu.")
        }
    }

    /// The exam is over: the tasks without full marks go to Minne as kinds of tasks to practise.
    private func finishExam(speak: Bool) {
        examTimer?.cancel()
        examTimer = nil
        guard let session = exam else { return }
        exam = nil
        let weak = session.weakTaskTypes()
        for fact in weak { memory.add(fact, kind: .fact, source: .automatic) }
        if !weak.isEmpty { refreshKeyterms() }
        controller.log("Provsession ended · \(session.results.count) graded · \(weak.count) kinds of task to practise saved")
        if speak { speakExamSummary(of: session) }
    }

    // MARK: - Study cards and the mini test (D81)

    /// A Provläge answer becomes a card; during the mini test the answer is the tutor's verdict.
    private func studyCardOrGrade(_ turn: AnswerTurn) {
        if let id = gradingCardID, var test = miniTest {
            gradingCardID = nil
            test.graded(turn.answer)
            studyCards?.mark(id, right: test.results[id] ?? false)
            miniTest = test
            askMiniTestQuestion()
            return
        }
        guard mode == .prov, miniTest == nil, pendingQuestion?.trigger == .tutor, let studyCards else { return }
        if studyCards.add(question: turn.question, answer: turn.answer, profile: studyProfile.profile) != nil {
            controller.log("Study card saved (\(studyCards.cards.count) in all)")
        }
    }

    private func provSessionEnded() {
        lastProvSessionStart = provStartedAt ?? lastProvSessionStart
        provStartedAt = nil
        if miniTest != nil {
            miniTest = nil
            gradingCardID = nil
            return
        }
        guard let studyCards, let start = lastProvSessionStart,
              studyCards.current().contains(where: { $0.createdAt >= start }) else { return }
        fetchStudyCards(since: start)
        studyNotice = language == .swedish
            ? "Minitest: fem frågor om det du nyss frågade. Tryck på Minitest eller säg \"Lumen, minitest\"."
            : "Mini test: five questions on what you just asked. Tap Mini test or say \"Lumen, mini test\"."
    }

    /// Kevin's `/study-cards`: the session's questions and answers → better cards and a five-question test.
    private func fetchStudyCards(since start: Date) {
        guard let studyCardsClient, let studyCards else { return }
        let turns = conversation.answers.filter { $0.createdAt >= start && $0.isOwnQuestion && $0.interrupted != true }
            .map { (question: $0.question, answer: $0.answer) }
        guard let body = StudyCardsRequest.body(turns: turns, profile: studyProfile.profile.setupText(), swedish: language == .swedish) else { return }
        let profile = studyProfile.profile
        Task { [weak self] in
            guard let reply = await studyCardsClient.cards(body) else { return }
            studyCards.addRemote(reply, profile: profile)
            self?.controller.log("Study cards: \(reply.cards.count) cards, \(reply.test.count) test questions from the backend")
        }
    }

    /// Five questions by voice, inside Provläge (the backend's test for the last session, else its cards first).
    func startMiniTest() async {
        guard let studyCards else { return }
        let cards = studyCards.takeTest(sessionStart: provStartedAt ?? lastProvSessionStart)
        guard !cards.isEmpty else {
            studyNotice = language == .swedish ? "Inga studiekort än: ställ några frågor i Provläge först."
                                               : "No study cards yet: ask a few questions in Provläge first."
            say(studyNotice ?? "")
            return
        }
        if !(study.isActive && mode == .prov) {
            selectedMode = .prov
            await startStudy()
            guard study.isActive else { return }
        }
        studyNotice = nil
        miniTest = MiniTest(cards: cards)
        gradingCardID = nil
        controller.log("Mini test started (\(cards.count) cards)")
        askMiniTestQuestion()
    }

    private func askMiniTestQuestion() {
        guard let test = miniTest else { return }
        if let question = test.question(swedish: language == .swedish) {
            say(question)
            return
        }
        say(test.summary(swedish: language == .swedish))
        controller.log("Mini test done: \(test.rightCount) of \(test.cards.count)")
        miniTest = nil
    }

    private func miniTestAnswer(_ text: String) {
        guard var test = miniTest, let card = test.current else { return }
        if MiniTest.isSkip(text) {
            test.skip()
            studyCards?.mark(card.id, right: false)
            miniTest = test
            study.resumeListening()
            askMiniTestQuestion()
            return
        }
        guard let query = test.gradingQuery(for: text, swedish: language == .swedish) else { return }
        gradingCardID = card.id
        activated(ActivationRequest(query: query, trigger: .tutor, language: language), persona: tutorPersona())
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
        // A8 (owner, 2026-11-08): Frågor answers the wearer's own questions too. D81's "Auto never answers the
        // wearer" made Lumen silent when Aron asked, with a voice profile. The voice is only logged now.
        if request.trigger == .auto, isWearersVoice() { controller.log("Auto: the wearer's own voice (answered, A8)") }
        if request.trigger == .auto, FillerFilter.isOnlyFiller(request.query) {
            controller.turns.dropped(request.query, mode: mode.rawValue, trigger: request.trigger.rawValue, reason: "filler")
            return
        } // D74
        if persona?.social == nil, deliverAhead(for: request) { return } // D80: ready the moment the pause is over
        discardAhead(reason: "a different turn")
        controller.turns.finish(currentTurnID, outcome: .interrupted, reason: "a newer turn: \(request.query)")
        currentPersona = persona?.persona
        pendingQuestion = request
        answerNotice = nil
        // A new question interrupts the current answer and its speech (assignment item 5).
        speaker.interrupt()
        spokenAnswer = ""
        latency.begin(request)
        controller.log("Activation (\(request.trigger.rawValue)): \(request.query)")
        sessionObserver?(.asked(query: request.query, trigger: request.trigger.rawValue), Date())
        if !study.isActive { logTurn() }
        timeline = TurnTimeline(heardAt: lastHeardAt, requestAt: Date(), pauseEndAt: Date(), answeredAhead: false)
        let sent = self.context(for: request)
        currentTurnID = controller.turns.begin(fragment: request.query, mode: mode.rawValue, trigger: request.trigger.rawValue,
                                               transcript: sent.transcript)
        answers.answer(request, context: sent, persona: persona)
    }

    private func context(for request: ActivationRequest) -> AnswerContext {
        // Provläge sends the whole session's memory (the backend keeps the last 6 pairs).
        let qaLimit = study.isActive ? AnswerContext.qaLimit : 3
        let matched = commands.matches(in: request.query)
        if !matched.isEmpty {
            controller.log("Commands matched: \(matched.map(\.keyword).joined(separator: ", "))")
        }
        if study.isActive, mode == .prov {
            // D87: the last three turns and the active exam in every Provläge call.
            return AnswerContext(transcript: conversation.recentText(seconds: 60),
                                 recentQA: conversation.recentQA(limit: qaLimit),
                                 prepTerms: prep.backendTerms + (studyProfile.profile.terms ?? []),
                                 goals: goals.compact,
                                 commands: matched.map { AnswerContext.Command(keyword: $0.keyword, instruction: $0.instruction) },
                                 memories: memory.backendItems(),
                                 recentTurns: turnsBefore(request.query),
                                 examID: currentExamID()?.uuidString)
        }
        return AnswerContext(transcript: conversation.recentText(seconds: 60),
                             recentQA: conversation.recentQA(limit: qaLimit),
                             prepTerms: prep.backendTerms + (studyProfile.profile.terms ?? []), // D84: the subject's terms
                             goals: goals.compact,
                             commands: matched.map { AnswerContext.Command(keyword: $0.keyword, instruction: $0.instruction) },
                             memories: memory.backendItems())
    }

    // MARK: - Answer ahead, deliver at the pause (D80)

    /// A sentence was heard: start its answer now, while the speaker is still pausing. Words that come before the
    /// pause is over replace it with a new call for the whole text. One call at a time.
    private func answerAhead(for raw: String) {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isListening, !isComparing, !isEnrollingVoice, instructing == nil, !text.isEmpty, !FillerFilter.isOnlyFiller(text),
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
            let speaker = turnSpeaker(level: study.currentTurnLevelDBFS).speaker
            guard speaker == .other || VoiceCommand.isInterviewRequest(text) else { return }
            request = ActivationRequest(query: text, trigger: .overheard, language: language)
            persona = PersonaRequest(persona: "interview", setup: modeSettings.interviewPersonaSetup, turn: "question")
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
        let sent = self.context(for: request)
        aheadTurnID = controller.turns.begin(fragment: request.query, mode: mode.rawValue, trigger: request.trigger.rawValue,
                                             transcript: sent.transcript, ahead: true)
        answers.answer(request, context: sent, persona: persona)
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
        // Toby T1 finding 3: the answer-ahead path reports `asked` too.
        sessionObserver?(.asked(query: current.request.query, trigger: current.request.trigger.rawValue), Date())
        controller.turns.finish(currentTurnID, outcome: .interrupted, reason: "a newer turn: \(current.request.query)")
        currentTurnID = aheadTurnID
        aheadTurnID = nil
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

    /// A8.3: the turn row an answer event belongs to: the answer made ahead while it is buffered, else the one in flight.
    private var eventTurnID: UUID? {
        if let current = ahead, !current.delivered { return aheadTurnID }
        return currentTurnID
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
        controller.turns.finish(aheadTurnID, outcome: .discarded, reason: reason)
        aheadTurnID = nil
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
        let speaker = turnSpeaker(level: study.currentTurnLevelDBFS).speaker
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
        tipTask?.cancel()
        tipNotice = nil
        conversation.beginAnswer(question: request.query, source: source, at: request.createdAt,
                                 isOwnQuestion: request.trigger.isUsersOwnWords)
        controller.playback.startRecordingSpeech() // A7 "upprepa"
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
        activation.answerDelivered() // A8.2: later words are a new turn
        if case .paused = state { return } // a typed question while paused is shown, not spoken over the music
        if pendingQuestion?.trigger == .interviewPrep { return }
        let spoken = pendingQuestion?.language ?? language
        if sentence.contains("\n") {
            // D84: a poem or a song comes in lines; each line is one unit, so the breaks are the rhythm. The source
            // line is shown, never read.
            for unit in ReadAloud.units(sentence) where !ReadAloud.isSourceLine(unit) { speaker.enqueue(unit, language: spoken) }
            return
        }
        if ReadAloud.isSourceLine(sentence) { return }
        speaker.enqueue(sentence, language: spoken)
    }

    func answerCompleted(latencyMs: Double?, done: AnswerDone?) {
        if instructing != nil {
            latency.end()
            instructionEnded(done?.calibration, answered: true)
            return
        }
        controller.turns.setStatus(eventTurnID, status: done?.retract == true ? "retract" : "ok", isQuestion: true)
        if bufferAhead(.completed(latencyMs: latencyMs, done: done)) { return }
        if done?.retract == true {
            controller.turns.finish(currentTurnID, outcome: .silent, reason: "the backend withdrew it")
            // Kevin: the model said [[TYST]] after it had begun: nothing of it is kept or said.
            speaker.interrupt()
            conversation.cancelAnswer()
            latency.end()
            if ahead?.delivered == true { ahead = nil }
            controller.log("Answer withdrawn by the backend (retract)")
            studyAnswerEnded()
            askWaitingQuestionIfIdle()
            return
        }
        if ahead?.delivered == true { ahead = nil }
        inFlightTrigger = nil
        if timeline?.doneAt == nil { timeline?.doneAt = Date() }
        if let turn = conversation.completeAnswer(latencyMs: latencyMs) {
            activation.answerDelivered()
            var notSpoken: String? = speaker.settings.speakAnswers ? nil : "shown, voice off"
            if case .paused = state { notSpoken = "shown, paused" }
            controller.turns.finish(currentTurnID, outcome: .answered, reason: notSpoken)
            answerWorked()
            sessionObserver?(.answered(question: turn.question, answer: turn.answer, firstTextMs: latencyMs, source: turn.source), Date())
            history.record(HistoryEntry(createdAt: turn.createdAt, question: turn.isOwnQuestion ? turn.question : nil,
                                        answer: turn.answer, summary: done?.summary,
                                        mode: mode.rawValue, persona: currentPersona))
            Task { await feedback?.sync(history.entries) }
            lastAnswerAt = Date()
            extractMemories(from: turn)
            scheduleKeytermRefresh()
            studyCardOrGrade(turn)
            showActivity()
            if mode == .prov, let index = studyTurns.lastIndex(where: { AheadAnswer.key($0.text) == AheadAnswer.key(turn.question) }) {
                studyTurns[index].answered = true
            }
        }
        if let fact = done?.memoryAdd {
            memory.add(fact)
        }
        if let latencyMs {
            controller.log("Answer · first text after \(Int(latencyMs)) ms" + (done?.usage?.model.map { " · \($0)" } ?? ""))
        }
        controller.turns.finish(currentTurnID, outcome: .silent, reason: "no answer text")
        studyAnswerEnded()
        askWaitingQuestionIfIdle()
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
        controller.turns.setStatus(eventTurnID, status: "not_question", isQuestion: false)
        if bufferAhead(.skipped(request)) { return }
        if ahead?.delivered == true { ahead = nil }
        latency.end()
        conversation.cancelAnswer()
        answerNotice = "Not a question — no answer (auto mode)"
        controller.log("Auto: backend says not a question: \(request.query)")
        controller.turns.finish(currentTurnID, outcome: .silent, reason: "backend: not a question")
        studyAnswerEnded()
        askWaitingQuestionIfIdle()
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
            controller.turns.setStatus(aheadTurnID, status: message, isQuestion: nil)
            controller.turns.finish(aheadTurnID, outcome: .failed, reason: "ahead; asked again at the pause")
            aheadTurnID = nil
            controller.log("Answer ahead failed: \(message)")
            return
        }
        if ahead?.delivered == true { ahead = nil }
        inFlightTrigger = nil
        latency.end()
        conversation.cancelAnswer()
        answerNotice = nil // D86: the problem card says it in Swedish; the raw message is in Diagnostik's log
        controller.log("Answer failed: \(message)" + (wantsFallback ? " · fallback requested (on-device engine not available on this iPhone)" : ""))
        if let error = answers.lastError, error != .cancelled { recordFailure(source: "answer", detail: error.localizedDescription) }
        report(problem: Self.problem(for: answers.lastError))
        controller.turns.setStatus(currentTurnID, status: message, isQuestion: nil)
        controller.turns.finish(currentTurnID, outcome: .failed)
        studyAnswerEnded()
        askWaitingQuestionIfIdle()
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
        guard !controller.playback.isSpeaking, !echo.isEcho(text, now: date), !isEnrollingVoice else { return }
        identifySpeech(at: date) // D81: beside the answer, never before it
        lastHeardAt = date
        schedulePrefetch()
        answerAhead(for: text)
    }

    func receiveFinalTranscript(_ text: String, at date: Date = Date()) {
        let before = conversation.finalSegments.count
        conversation.finalize(text, at: date, overlapsPlayback: controller.playback.isSpeaking)
        guard conversation.finalSegments.count > before, let segment = conversation.finalSegments.last else { return }
        finalObserver?(segment.text)
        sessionObserver?(.heard(segment.text), date)
        if isComparing || isEnrollingVoice { return }
        if awaitingExamStatement, ProfileStatement.isAboutSchool(segment.text) {
            awaitingExamStatement = false
            discardAhead(reason: "an exam said aloud")
            profileStatement(segment.text)
            return
        }
        if let identity = speakers?.identity(near: date, window: 4) { labelTranscript(identity, at: date) }
        if isOwnEcho(segment.text, at: date), !isWearerUsingSuggestion(segment.text, level: study.currentTurnLevelDBFS) {
            discardAhead(reason: "Lumen's own echo")
            return
        }
        if !segment.overlapsPlayback, VoiceCommand.isMusicHandOff(segment.text) {
            controller.log("Spoken pause: handing the audio back")
            Task { await controller.pause() }
            return
        }
        if !segment.overlapsPlayback, let action = VoiceCommand.musicAction(segment.text) {
            discardAhead(reason: "a music command")
            study.discardTurnText()
            Task { await musicByVoice(action) }
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
