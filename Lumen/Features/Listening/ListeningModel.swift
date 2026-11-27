import Foundation
import NaturalLanguage
import Observation
import UIKit
import UserNotifications

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
    /// D80: the answer being made before the pause is over. Spoken only when the pause comes and the words did not go on.
    private var ahead: AheadAnswer?
    /// A8.3: the Diagnostics turn rows of the answer in flight and of the answer made ahead.
    private var currentTurnID: UUID?
    private var aheadTurnID: UUID?
    /// D221 (A137, G7 step 7a): the turns split from one utterance or heard while a turn was answered, asked one
    /// after another. Frågor and Provläge share it.
    let turnQueue = TurnQueue()
    private(set) var aheadStats = AheadStats()
    /// The turn being timed, logged at the first sound (D80).
    private var timeline: TurnTimeline?
    /// When the last words were heard (partial or final), for the half-pause TTS prefetch.
    private var lastHeardAt: Date?
    private var prefetchTask: Task<Void, Never>?
    /// When the last answer was completed, so a complaint right after it can be reported (D80).
    private(set) var lastAnswerAt: Date?
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
    /// A42: "Ändra" on Start's exam card (the exam is changed there, not in Inställningar).
    var editingExam: ExamPlan?
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
    /// A29 (Toby T7): moments a test can wait for instead of reading log text. A separate observer, so the switches
    /// over `SessionEvent` in the tests and the study recording stay exhaustive.
    enum ListeningEvent: String, Sendable {
        case micOpen = "mic open"
        case micGated = "mic gated"
        case moreWindowOpen = "more window open"
        case moreWindowClosed = "more window closed"
    }
    var listeningEventObserver: (@MainActor (ListeningEvent, Date) -> Void)?
    /// D87: the exam the Provläge turns belong to. The turns themselves are `provMode.turns` (G7 step 7a).
    private(set) var activeExamID: UUID?
    /// "Lägg till prov" → the microphone button: the next sentence is the exam, said aloud.
    private(set) var awaitingExamStatement = false
    /// D84: the practice exam inside Provläge, its uploaded paper and Kevin's `/exam`.
    let examMaterials: ExamMaterials?
    let examClient: ExamClient?
    /// D199 step 6a (A121): the exam session is `ExamSessionController` now; the checks here read it as before.
    var exam: ExamSession? { examSession.session }
    var examSession: ExamSessionController { provMode.exam }
    /// D199 step 6c (A126): Provläge behind `ListeningModeController`. It holds the parts that have left this file
    /// (the exam session, the practice exam by voice, the mini test) and the order a turn is offered to them in.
    let provMode = ProvModeController()
    /// A16: the practice exam read aloud one question at a time (K15), in Provläge.
    /// D199 step 6b (A125): the practice exam by voice is `PracticeExamController` now; the screen and the checks
    /// here read its run and its result as before.
    var practice: PracticeRun? { practiceExam.run }
    var practiceExam: PracticeExamController { provMode.practice }
    /// A16: the last run's result for the listening screen (right, wrong, what to practise).
    var practiceResult: PracticeRun.Summary? { practiceExam.result }
    /// A16: right and wrong per concept from practice runs, sent as `concept_stats` in Provläge.
    @ObservationIgnored private var conceptStats = ConceptStats.load()
    /// A19 (K17): what came up per exam and concept, right or wrong, for `/study-plan`.
    @ObservationIgnored private var studyHistory = StudyHistory.load()
    /// A49 (D123): Sömnläge, its nights and the morning report.
    @ObservationIgnored let sleep = SleepController()
    /// A48 (D122, K35): the phone tools (set by AppContainer; nil in most tests: no tools offered).
    @ObservationIgnored var phoneTools: (any PhoneToolRunning)?
    /// A53 (D126, K37): "Mina svar", on the phone only, and the endpoint that helps write them.
    var myAnswers: MyAnswerStore?
    /// D142 (A78–A81): the repetition mode, the new standard (no microphone).
    var repetition: RepetitionModel?
    /// A145 (K101): "Radera konto" in Inställningar. Set by AppContainer.
    var accountDeletion: AccountDeletionModel?
    @ObservationIgnored var myAnswersClient: MyAnswersClient?
    /// A59 (K36): Spotify control through the server, for testers.
    var spotifyConnection: SpotifyConnection?
    /// A54 (D127, K39): the logo vote.
    @ObservationIgnored var logoVoteClient: LogoVoteClient?
    /// A53: Mina svar is open (from Start's exam card or Inställningar), for this exam; the editor for one answer.
    var showingMyAnswers: MyAnswersRoute?
    /// A48: the question Lumen asked before a tool changes something ("Ska jag lägga in …?"); shown with Ja / Nej.
    var pendingToolConfirm: String? { tools.pendingConfirm }
    /// D221 (G7 step 7d): the tool call, the confirm question and the second call are `PhoneToolsController`.
    let tools = PhoneToolsController()
    /// D233 (A151): the quiet tone while an answer searches the web.
    let searchTone = SearchToneController()
    @ObservationIgnored private var lastSent: (request: ActivationRequest, persona: PersonaRequest?)?
    /// A38 (K31): the days with a quiz answer, and the streak they make (shown on Start).
    @ObservationIgnored private var quizDays = QuizDays.load()
    private(set) var streak = QuizDays.load().streak()
    let studyPlanClient: StudyPlanClient?
    /// D199 step 6e (A128): today's plan, the reminders, the summary at "avsluta" and the links are
    /// `StudyPlanController` in `provMode` now. Start reads the plan through the functions further down, as before.
    var canAskForReminders: Bool { provMode.studyPlan.canAskForReminders }
    var isShowingExamSetup = false
    /// What Lumen has said of the current answer, for an interrupted turn (D81).
    private var spokenAnswer = ""
    /// D199 step 6c (A126): the mini test is `MiniTestController` in `provMode` now; the checks here read it as before.
    var miniTest: MiniTest? { provMode.miniTest.test }
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
    /// A21.3: when Lumen's own speech should be over at the latest; the recogniser opens then even without its end.
    @ObservationIgnored private var ownSpeech = OwnSpeechDeadline()
    @ObservationIgnored private var gateWatchdog: Task<Void, Never>?
    /// A21.3: how often the safety timer had to open the recogniser, for Diagnostics.
    private(set) var gateWatchdogOpens = 0
    /// A20.1: the learned speaking pace per context, and the signals that change it.
    let paces = SpeechPaceStore()
    @ObservationIgnored private var paceSignals = PaceSignals()
    @ObservationIgnored private var noteTask: Task<Void, Never>?
    /// A20.2: the silent quiz in Provläge (nod = ja, shake = nej). Nil: not running.
    /// D199 step 6d (A127): the quiz is `SilentQuizController` in `provMode` now; the screen reads it here as before.
    var silentQuiz: SilentQuiz? { provMode.silentQuiz.quiz }
    static let echoTail: TimeInterval = 0.7
    /// A72: when Lumen's last sentence began playing.
    @ObservationIgnored private var lastSentenceStartedAt: Date?
    /// The Diagnostics recording (D78) sees every final as it arrives.
    var finalObserver: (@MainActor (String) -> Void)?
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
    /// D199 step 1 (A111): Intervjuläge's own decisions, out of this file. The audio engine stays here.
    let interviewMode: InterviewModeController
    /// The running live session, Rizzläge or Socialt läge. Gone when it ends, and the words with it.
    /// D199 step 2 (A113): the live session of Socialt läge and Rizzläge (the conversation, the suggestions, the
    /// instructions and their timing) is `LiveModeController` now. The views read the session here, as before.
    var rizz: RizzSession? { liveMode.session }
    let liveMode: LiveModeController
    let socialMode: SocialModeController
    /// D199 step 3 (A114): Rizzläge's own rules (its style, and D63's age check, never true since D112) on the same
    /// live session.
    let rizzMode: RizzModeController
    /// D199 step 5 (A120): Frågor's own decisions (the question gate at the pause, the name alone, the hands-free turn)
    /// and the "Mer?" window with its two levels, which Provläge shares. The activation and the echo stay here.
    let standardMode = StandardModeController()
    /// A15: the 5 s window is open: the screen shows "Säg ja för mer".
    var isOfferingMore: Bool { standardMode.more.isOpen }
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
    /// A9.3: learned answer settings (K10), shown in Minne and sent with every answer.
    let preferences: PreferenceStore
    /// A9.2: the last app command done for the backend, so "nej" / "ångra" within 5 s takes it back.
    @ObservationIgnored private var lastAppCommand: (command: AppCommand, previousMode: ConversationMode, wasListening: Bool, at: Date)?
    static let undoWindow: TimeInterval = 5
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
    /// The flow: Historik straight from Lyssnar's ⋯ menu (it was Tillbaka → Inställningar → a long scroll).
    var isShowingHistory = false
    /// Kelly Ke93 (2): the activation words' row on Lyssnar once there has been an answer (this pass or ever), or
    /// when words are set. The very first listening shows only "Fråga vad du vill."
    var showsActivationWords: Bool {
        !activation.settings.phrase.isEmpty || !conversation.answers.isEmpty || !history.entries.isEmpty
    }

    /// Kelly (D269 a): what is heard right now, in grey under the badge, so one sees one is heard. Not Lumen's own
    /// voice; the end of it when it is long (two lines). Gone when the words are final (the answer comes).
    var heardLine: String? {
        guard let partial = conversation.partial, !partial.overlapsPlayback else { return nil }
        let text = partial.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        return text.count > Self.heardLineLimit ? "…" + String(text.suffix(Self.heardLineLimit)) : text
    }
    static let heardLineLimit = 120

    /// Deangelo 2026-11-27: the network, the battery and the low power mode, watched while EarMind listens. Set by the
    /// app (`SystemDeviceConditions`); nil in tests that do not need it.
    @ObservationIgnored var deviceConditions: (any DeviceConditions)? {
        didSet { deviceConditions?.onChange = { [weak self] in self?.conditionsTick += 1 } }
    }
    private(set) var conditionsTick = 0

    /// The one line on Lyssnar when something is not as it should be (no AirPods, no network, low battery, low power
    /// mode), with the way on in it. Nil while all is well, and while not listening.
    var listeningCondition: ListeningCondition? {
        _ = conditionsTick
        #if DEBUG
        if let shown = screenshotCondition { return shown }
        #endif
        guard isListening else { return nil }
        let outputs = controller.session.snapshot?.outputs ?? []
        let conditions = deviceConditions
        let code = language == .swedish ? "sv" : "en"
        return ListeningCondition.current(externalOutput: outputs.isEmpty || outputs.contains(where: \.isExternalOutput),
                                          online: conditions?.isOnline ?? true,
                                          phoneModel: (answers.offline as? OnDeviceAnswerProvider)?.isAvailable(for: code) ?? false,
                                          batteryPercent: conditions?.batteryPercent, charging: conditions?.isCharging ?? false,
                                          lowPowerMode: conditions?.isLowPowerMode ?? false)
    }

    #if DEBUG
    /// The pictures of each line, without a phone in that state.
    var screenshotCondition: ListeningCondition?
    #endif

    /// Historik: the row whose answer is being read again, while it is read (its button shows ■).
    private(set) var readingAgain: UUID?
    @ObservationIgnored private var readingAgainTask: Task<Void, Never>?
    /// Kelly B2: the page with the listening modes ("Fler lägen") is open on Start. Here and not in the view, so
    /// Avsluta on Lyssnar comes back to the page with Starta EarMind, where the listening was started.
    var showsMoreModes = false
    var isShowingNotes = false
    var isShowingPrep = false
    var isShowingCommands = false
    var isShowingDiagnostics = false
    /// Text mode (item 6): the question being typed. Works without the microphone.
    var draftQuestion = ""

    var state: SessionState { controller.state }
    var isListening: Bool { controller.state.isListening }
    /// A26 R4 (Kelly): true only while a start is under way, so the badge says "Startar …" then and "Pausad" otherwise.
    private(set) var isStarting = false
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
         tips: CommandTipStore? = nil, preferences: PreferenceStore? = nil, studyPlanClient: StudyPlanClient? = nil) {
        self.studyPlanClient = studyPlanClient
        self.preferences = preferences ?? PreferenceStore(defaults: UserDefaults(suiteName: "lumen.prefs.\(UUID().uuidString)") ?? .standard)
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
        self.interviewMode = InterviewModeController(settings: modes)
        let live = LiveModeController(settings: modes)
        self.liveMode = live
        self.socialMode = SocialModeController(live: live, settings: modes)
        let rizzController = RizzModeController(live: live, settings: modes)
        self.rizzMode = rizzController
        // The remembered mode. Rizzläge only if the 18+ question was answered; the gate is never skipped.
        self.selectedMode = modes.lastMode == .rizz && rizzController.needsAgeConfirmation ? .standard : modes.lastMode
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
            self.lastSentenceStartedAt = Date() // A72
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
        transcription.onInputGate = { [weak self] gated in
            self?.listeningEventObserver?(gated ? .micGated : .micOpen, Date()) // A29
        }
        speaker.onSpeak = { [weak self] text in
            self?.lastSpokeTextAt = Date() // A63
            self?.ownSpeechStarted(text)
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
        // A45 (Deangelo N3): the iPhone's own voice or recogniser standing in is a calm line once per session, not an
        // error card. The failure is still recorded for Diagnostik.
        speaker.onVoiceFallback = { [weak self] detail in
            self?.recordFailure(source: "tts", detail: detail)
            self?.noteFallback(what: "the voice")
        }
        transcription.onFallback = { [weak self] reason in
            self?.recordFailure(source: "stt", detail: reason)
            self?.noteFallback(what: "speech recognition")
        }
        controller.keepsListeningWhenOutputLost = { [weak self] in !(self?.microphone.pauseWhenAirPodsLost ?? true) }
        controller.onOutputLost = { [weak self] in self?.report(problem: .airPodsDisconnected) }
        controller.onOutputRestored = { [weak self] in
            if self?.problem == .airPodsDisconnected || self?.problem == .airPodsLostPaused { self?.problem = nil }
            self?.conditionsTick += 1 // the AirPods are back: "Inga AirPods" goes
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
        interviewMode.host = self // D199
        liveMode.host = self
        standardMode.host = self
        provMode.host = self
        turnQueue.host = self
        #if LUMEN_TESTMODE
        debugAudio.host = self
        #endif
        tools.host = self
        searchTone.host = self
        pagePhoto.host = self
        flipCards.host = self
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

    // MARK: A94: the listening consent comes when a mode that listens is first started

    /// A94 (Kelly Ke55): the first start no longer asks about listening (it never listens, D142). A mode under
    /// Fler lägen that is started without the listening consent shows `ConsentView` first (RootView's sheet); the
    /// microphone starts only after "Jag förstår".
    var asksForListeningConsent = false
    @ObservationIgnored private var afterListeningConsent: (@MainActor () async -> Void)?

    private func askForListeningConsent(then start: @escaping @MainActor () async -> Void) {
        afterListeningConsent = start
        asksForListeningConsent = true
    }

    /// A166: the question about sharing the history is not needed before the first answer. It is held from the press
    /// that gives the listening consent until that listening is over; until it is answered nothing is shared.
    private(set) var holdsSharingQuestion = false

    /// A166: the sharing question may be shown: nothing holds it, and nothing listens or is about to.
    var sharingQuestionIsFree: Bool { !holdsSharingQuestion && !isActiveSession && !isStarting }

    /// A166 (D266): "Jag förstår, starta EarMind" in the first start: the consent, and Standardläget listens at once
    /// (iOS asks about the microphone). One press from the consent to the first question.
    func firstStartConsentGiven() async {
        holdsSharingQuestion = true
        consent.grant()
        beginFreshPass()
        await startMode(.standard)
        // The flow: after Avsluta (or without the microphone), the page where EarMind starts again. Set after the
        // start, so Start does not first push the page under Lyssnar.
        showsMoreModes = true
    }

    /// "Jag förstår, starta EarMind" on the consent sheet: the consent, then the start that asked for it.
    func listeningConsentGiven() {
        holdsSharingQuestion = true // A166
        consent.grant()
        asksForListeningConsent = false
        let start = afterListeningConsent
        afterListeningConsent = nil
        if let start { Task { await start() } }
    }

    /// The sheet was closed without the consent: nothing starts.
    func listeningConsentDeclined() {
        asksForListeningConsent = false
        afterListeningConsent = nil
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
            askForListeningConsent { await self.startListening() }
            return
        }
        tips.sessionStarted()
        fallbackNotedThisSession = false // A45: a new session may say it once again
        fallbackNotice = nil
        Task { await prepareBackend() }
        refreshKeyterms()
        isStarting = true
        defer { isStarting = false }
        await useMicrophone(for: mode)
        await controller.start()
        logMicrophone()
        updateDebugAudio() // A76
        if !isListening, case .error(let message) = state, message.localizedCaseInsensitiveContains("permission") {
            problem = .microphoneDenied // A12: shown on Start as well, not only on the first-question screen
        }
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
    func refreshKeyterms() {
        let recent = conversation.answers.suffix(2)
        // A162: the user's own activation words are words Scribe should hear right.
        let activationWords = activation.settings.phrase.isEmpty ? [] : [activation.settings.phrase]
        let terms = KeytermBuilder.terms(commands: activationWords + phrases.userPhrases + commands.commands.map(\.keyword),
                                         topic: recent.last?.question,
                                         answers: recent.map(\.answer),
                                         goals: goals.terms,
                                         memory: memory.facts.map(\.text),
                                         prep: (studyProfile.profile.terms ?? []) + prep.sttTerms)
        let rest = terms + prep.sttTerms + (studyProfile.profile.terms ?? [])
        // D87: in Provläge the active exam's words go first, so Scribe hears them right from the first word.
        let exam = mode == .prov ? quizTerms + ExamKeyterms.terms(profile: studyProfile.profile) : [] // A62: the quiz answer first
        // A14 (Toby T6): the short words Scribe mishears most when they stand alone, per mode.
        let spoken: [String] = switch mode {
        case .prov, .standard: standardMode.spokenKeyterms // D199 step 5; Provläge has the same words
        case .social: socialMode.spokenKeyterms // D199 step 2
        case .rizz: rizzMode.spokenKeyterms // D199 step 3
        case .interview: interviewMode.spokenKeyterms
        }
        // A75: the name first, with the most weight Scribe and the phone's recogniser give (the first keyterms).
        // A97 (D172): both names, "Lumen" and "EarMind".
        transcription.setContextualStrings(ExamKeyterms.merged(exam: WakeWord.names + exam, rest: spoken + rest))
    }

    /// Raw capture for the Diagnostics recording (D78), the same audio the recogniser gets before any gate.
    func subscribeToAudio() -> (id: UUID, stream: AsyncStream<AudioChunk>) {
        controller.subscribeToChunks()
    }

    func unsubscribeFromAudio(_ id: UUID) {
        controller.unsubscribeFromChunks(id)
    }

    func stopListening() async {
        if isListening { cue(.stop) } // A34: before the graph stops
        listeningStoppedAt = Date() // A60 (Toby T8b finding 1): what Scribe hands over after this is not used
        #if LUMEN_TESTMODE
        debugAudio.stop() // A76: the last, shorter piece is finished
        #endif
        stopListeningForExamStatement()
        answers.sessionLength = nil
        activation.cancelPending()
        turnQueue.clear()
        ownSpeechEnded()
        answers.cancel()
        speaker.interrupt()
        conversation.cancelAnswer()
        await controller.stop()
        holdsSharingQuestion = false // A166: the first listening is over
    }

    func resume() async {
        await controller.resume()
        updateDebugAudio() // A76
    }

    /// One tap to switch to music and back (D33): screen button, Live Activity and Control. Never starts a
    /// session: the microphone is only switched on from the app.
    /// `fromScreen`: the Pausa button on Lyssnar, which says what it does. An AirPods press during the "Mer?" window
    /// means "mer" (A15); the button on the screen pauses, and the window closes.
    func togglePause(fromScreen: Bool = false) async {
        if isOfferingMore {
            if !fromScreen {
                standardMode.more.take(by: "AirPods press") // A15: the press means "mer" while the window is open
                return
            }
            standardMode.more.close(why: "pause")
        }
        if isListening {
            cue(.stop) // A34
            await controller.pause()
        } else if canResume {
            await controller.resume()
        }
    }

    /// A34 (D109): the sounds. Kelly chooses their character (SYSTEM.md); until then short soft tones from the
    /// playback graph, local, no calls. Only into headphones: out of the iPhone's own speaker the microphone would hear
    /// them (echo filter, VAD), so then there is no sound.
    enum ListeningCue: String {
        case start, stop, hm

        var tone: (frequency: Double, duration: Double) {
            switch self {
            case .start: (880, 0.07)
            case .stop: (587, 0.09)
            case .hm: (330, 0.12)
            }
        }
    }

    @ObservationIgnored private var cuedListening = false

    private func cue(_ kind: ListeningCue) {
        guard speaker.settings.listeningCues, !(controller.snapshot?.outputsToBuiltInSpeaker ?? false) else { return }
        try? controller.playback.playTestTone(frequency: kind.tone.frequency, duration: kind.tone.duration)
        controller.log("Cue: \(kind.rawValue) (A34)")
    }

    private func sessionStateChanged(_ state: SessionState) {
        if state.isListening, !cuedListening { cue(.start) } // A34: started or resumed
        cuedListening = state.isListening
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
            problem = .airPodsLostPaused // Deangelo 2026-11-27: paused, so the card says so and how to go on
        case .error(let message) where message.localizedCaseInsensitiveContains("permission"):
            problem = .microphoneDenied
        case .listening:
            if problem == .microphoneDenied || problem == .airPodsDisconnected || problem == .airPodsLostPaused { problem = nil }
        default:
            break
        }
        switch state {
        case .listening:
            beginVoiceWork()
            showActivity()
            deviceConditions?.startWatching() // the network, the battery, the low power mode (Deangelo 2026-11-27)
            conditionsTick += 1
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
            deviceConditions?.stopWatching()
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

    /// Historik (Deangelo 2026-11-27): one tap reads an answer again in the AirPods, in its own language, with the
    /// chosen voice or the phone's own (no network, no credits). Nothing is sent but the voice's request.
    func readAgain(_ entry: HistoryEntry) {
        readingAgainTask?.cancel()
        readingAgain = entry.id
        speaker.readAgain(entry.answer, language: Self.spokenLanguage(of: entry.answer, otherwise: language))
        let id = entry.id
        readingAgainTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300)) // the voice has begun
            while let self, !Task.isCancelled, self.readingAgain == id, self.speaker.isSpeaking {
                try? await Task.sleep(for: .milliseconds(200))
            }
            guard let self, !Task.isCancelled, self.readingAgain == id else { return }
            self.readingAgain = nil
        }
    }

    func stopReadingAgain() {
        readingAgainTask?.cancel()
        readingAgain = nil
        speaker.interrupt()
    }

    /// The language an answer is written in (Swedish or English), else the one EarMind listens in.
    nonisolated static func spokenLanguage(of text: String, otherwise fallback: TranscriptionLanguage) -> TranscriptionLanguage {
        let recognizer = NLLanguageRecognizer()
        recognizer.languageConstraints = [.swedish, .english]
        recognizer.processString(text)
        switch recognizer.dominantLanguage {
        case .english?: return .english
        case .swedish?: return .swedish
        default: return fallback
        }
    }

    /// A26 R5: ▶ on a voice's row plays that voice without choosing it.
    func previewVoice(_ choice: VoiceChoice) {
        speaker.preview(choice, language: language)
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
        case .interview, .rizz, .social:
            // D199 step 4: the mode says which screen its button opens.
            if let screen = modeController(for: selectedMode)?.startScreen() { show(screen) }
        }
    }

    /// D199 step 4 (A119): each mode's controller. None has a start block of its own but the three with a start
    /// screen.
    func modeController(for mode: ConversationMode) -> (any ListeningModeController)? {
        switch mode {
        case .interview: interviewMode
        case .social: socialMode
        case .rizz: rizzMode
        case .standard: standardMode // D199 step 5
        case .prov: provMode // D199 step 6c
        }
    }

    /// D199 step 4: what must be shown in the app before `target` can start; nil when nothing is missing.
    func startBlock(for target: ConversationMode) -> ModeStartBlock? {
        modeController(for: target)?.startBlock()
    }

    /// The sheet for a start block (the views watch these flags).
    private func show(_ block: ModeStartBlock) {
        switch block {
        case .ageQuestion: isShowingAgeGate = true
        case .liveStartScreen: isShowingLiveStart = true
        case .interviewSetup: isShowingInterviewSetup = true
        }
    }

    /// The picker moved: Rizzläge asks for the age the first time it is opened (D63).
    func modeSelected() {
        if startBlock(for: selectedMode) == .ageQuestion { show(.ageQuestion) } // D199 step 4
    }

    func answerAgeGate(confirmed: Bool) {
        isShowingAgeGate = false
        if confirmed {
            rizzMode.confirmAge()
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
            askForListeningConsent { await self.startHandsFree(newMode) }
            return
        }
        if !ModeAccess.isOpen(newMode) {
            controller.log("\(newMode.rawValue) needs a subscription (D83, flag off today)")
            return
        }
        if startBlock(for: newMode) == .ageQuestion { // D199 step 4
            controller.log("Rizzläge refused: no age confirmation")
            show(.ageQuestion)
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
        study.unfinishedHold = newMode == .prov || newMode == .standard ? UnfinishedQuestion.hold : 0 // A21.2
        if newMode == .prov { await transcription.applyKeytermsNow() } // D87: the exam's words from the first one
        if let style = newMode.liveStyle {
            liveMode.begin(style: style)
            study.stallSilence = Self.stallSilence
            study.speechDetector = { [weak self] in self?.transcription.vadSpeaking() } // D82.2
            applySpeechVolume()
        } else {
            study.stallSilence = nil
            study.speechDetector = nil
        }
        applyPace()
        if silentQuiz != nil, newMode != .prov { provMode.silentQuiz.end(speak: false) }
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
            // Ke35 (Toby T8b finding 6): no five questions first. Defaults (Automatiskt), changed in Inställningar
            // or by voice ("kortare"); the subject is asked in the first quiz (A22).
            var profile = studyProfile.profile
            profile.onboarded = true
            studyProfile.profile = profile
        }
        if examPlans?.upcoming().isEmpty != false, !provAskedForExam {
            // Ke35: at most one question, and only without an exam: "Har du prov snart?". "Inte nu" starts anyway.
            provAskedForExam = true
            startsProvAfterExamStep = true
            isShowingAddExam = true
            return
        }
        if let plan = examPlans?.upcoming().first {
            await startProv(for: plan)
        } else {
            await startStudy()
        }
    }

    /// A66 (Toby T8c finding 1): at most one sheet each time the app is opened. The first start's share question is
    /// that opening's sheet; "EarMind kan mer än svara" and the logo vote wait for later openings.
    @ObservationIgnored var openingSheetShown = false

    /// Ke35: Provläge asked for the exam once in this run of the app.
    @ObservationIgnored private var provAskedForExam = false
    /// Ke35: the exam step was opened by Starta in Provläge; when it closes (saved or "Inte nu"), Provläge starts.
    @ObservationIgnored var startsProvAfterExamStep = false

    /// Ke35: after "Har du prov snart?" from Starta in Provläge: with the exam if one was saved, else without.
    func startProvAfterExamStep() async {
        guard startsProvAfterExamStep else { return }
        startsProvAfterExamStep = false
        if let plan = examPlans?.upcoming().first {
            await startProv(for: plan)
        } else {
            await startStudy()
        }
        showsListeningScreen = problem != .microphoneDenied || isActiveSession
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

    /// The exam being studied: the one chosen, else the nearest exam in the profile's subject.
    func currentExamID() -> UUID? {
        if let activeExamID, examPlans?.plans.contains(where: { $0.id == activeExamID }) == true { return activeExamID }
        let subject = studyProfile.profile.subject
        return examPlans?.upcoming().first { $0.subject.caseInsensitiveCompare(subject) == .orderedSame }?.id
    }

    /// D86 "Spara prov": kept with the others, and Provläge's profile from now on. The subject's terms follow.
    func saveExamPlan(_ plan: ExamPlan) {
        examPlans?.save(plan)
        updateWidget() // A44
        useExamPlan(plan)
        controller.log("Exam saved: \(plan.name), \(plan.daysLeft()) days")
    }

    /// Provläge for this exam: its grade, subject, date and topics become the profile.
    func useExamPlan(_ plan: ExamPlan) {
        if activeExamID != plan.id { provMode.forgetTurns() } // another exam: its turns are not this one's
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
    func startProv(for plan: ExamPlan, answersOnly: Bool = false, sayPlan: Bool = true) async {
        useExamPlan(plan)
        selectedMode = .prov
        provAnswersOnly = answersOnly
        await startStudy()
        askSubjectIfOnlyArea(plan)
        if sayPlan, !answersOnly, awaitingSubject == nil { provMode.studyPlan.sayPrompt(for: plan) }
    }

    /// A24: an exam that is only an area ("NO", from the first start) waits for its subject; the quiz can wait for it.
    @ObservationIgnored private var awaitingSubject: (planID: UUID, area: ExamPlan.Area, quizAfter: Bool)?

    private func askSubjectIfOnlyArea(_ plan: ExamPlan) {
        guard study.isActive, mode == .prov, let area = SubjectQuestion.area(of: plan) else {
            awaitingSubject = nil
            return
        }
        awaitingSubject = (plan.id, area, false)
        controller.log("Provläge: the exam is only an area (\(area.title)), the subject is asked for (A24)")
        say(SubjectQuestion.prompt(for: area))
    }

    /// The answer to "Vilket ämne i NO …?". True: it was the subject (saved, and the quiz starts if it waited).
    private func subjectAnswered(_ text: String) -> Bool {
        guard let waiting = awaitingSubject else { return false }
        awaitingSubject = nil
        guard let subject = SubjectQuestion.subject(in: text, area: waiting.area),
              var plan = examPlans?.plans.first(where: { $0.id == waiting.planID }) else {
            if waiting.quizAfter { askForQuiz() } // not a subject: the words are a turn of their own, then the quiz
            return false
        }
        plan.subject = subject
        saveExamPlan(plan)
        controller.log("Provläge: the subject is \(subject) (A24)")
        if waiting.quizAfter { askForQuiz() } // before `say`: the quiz's request interrupts speech
        say("Bra, \(plan.name.lowercased()).")
        return true
    }

    /// D97 (owner): "Få A-svar till provet" answers the student's questions and never quizzes; "Förhör mig" does both.
    private(set) var provAnswersOnly = false

    func startAnswersOnly(for plan: ExamPlan) async {
        await startProv(for: plan, answersOnly: true)
    }

    /// A18 (Kelly Ke9): Start's one blue button says what it does, "Förhör mig", the same words as the voice command.
    /// Provläge for the exam, and the first quiz question at once.
    func startQuiz(for plan: ExamPlan) async {
        beginFreshPass()
        await startProv(for: plan, sayPlan: false)
        guard study.isActive, mode == .prov else { return }
        if awaitingSubject != nil {
            awaitingSubject?.quizAfter = true // A24: the subject first, then the quiz
            return
        }
        askForQuiz()
    }

    /// A33 (D109): the first start asks aloud after the first answer; the next utterance is the answer (a short one
    /// is enough: "biologi på fredag"), read on the phone and by `/study-profile`. "Nej" declines.
    @ObservationIgnored private var examAskedAloud = false
    private(set) var examQuestionDeclined = false

    func askAboutExamByVoice(firstStart: Bool = true) async {
        examQuestionDeclined = false
        await listenForExamStatement()
        examAskedAloud = true
        examAskedAt = Date()
        // A47: from Start the student asked to add one; the first start asks whether there is one at all.
        say(firstStart ? "Har du prov snart? Säg vilket ämne och när." : "Vilket prov? Säg ämnet och när det är.")
    }

    /// A60 (Toby T8b finding 1): when the question was asked; the answer must come within `examAnswerWindow`.
    @ObservationIgnored private var examAskedAt: Date?
    nonisolated static let examAnswerWindow: TimeInterval = 30
    /// A60: when listening was stopped. Scribe's last words arrive after that and are not a turn, a command or a
    /// profile (they became "Hur, sparat" and a word in the ear after Avsluta).
    @ObservationIgnored private var listeningStoppedAt: Date?

    /// A60: the exam step was closed (skipped, saved or "Inte nu"): the next sentence is an ordinary one again.
    func stopListeningForExamStatement() {
        awaitingExamStatement = false
        examAskedAloud = false
        examAskedAt = nil
    }

    /// The utterance answers "Har du prov snart?": in time, and not a question of its own ("Hur många ben har en
    /// spindel?"), unless it is about school.
    nonisolated static func answersExamQuestion(_ text: String, askedAt: Date?, at date: Date) -> Bool {
        guard let askedAt, date.timeIntervalSince(askedAt) < examAnswerWindow else { return false }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasSuffix("?"), !ProfileStatement.isAboutSchool(trimmed) { return false }
        return true
    }

    /// "Lägg till prov" → "Eller säg det": listen, and the next sentence about an exam is saved as one.
    func listenForExamStatement() async {
        awaitingExamStatement = true
        if !isListening {
            if canResume { await resume() } else { await startListening() }
        }
    }

    /// D83: `persona: "tutor"` + `persona_setup` with the profile, on every Provläge call.
    /// It is made by `ProvModeController` since G7 step 7a.
    func tutorPersona() -> PersonaRequest? {
        provMode.tutorPersona()
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
        if let session = rizz, !session.offered.isEmpty {
            let lines = ownLinesAreReliable ? session.ownLines.joined(separator: "\n") : ""
            history.record(HistoryEntry(question: lines.isEmpty ? nil : lines, answer: "",
                                        summary: String(localized: "\(mode == .rizz ? String(localized: "Rizzläge") : String(localized: "Socialt läge")): \(session.offered.count) förslag."),
                                        suggestions: session.offered, mode: mode.rawValue, persona: "social"))
        }
        liveMode.end() // D199 step 2: the session, the early request, the instruction and its triggers
        applySpeechVolume()
        answers.sessionLength = nil // A7: "svara kortare" lasts one session
        mode = .standard
    }

    /// Ends the session. After the silence timeout the microphone is released too ("sparläge").
    func endStudy(bySilence: Bool) {
        guard study.isActive || bySilence else { return }
        let endedProv = mode == .prov
        if endedProv, exam != nil { examSession.end(speak: false) }
        if endedProv, practice != nil { practiceExam.finish(speak: false) }
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
            turnStartedAt = Date()
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
            if isOwnEcho(raw, at: Date(), startedAt: turnStartedAt), !isWearerUsingSuggestion(raw, level: study.lastTurnLevelDBFS) {
                discardAhead(reason: "Lumen's own echo")
                study.resumeListening()
                return
            }
            // A162 (D259): the user's own activation words. The question just asked is answered; the words are not.
            if answerForActivationWords(in: raw) { return }
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
            if pendingToolConfirm != nil, tools.confirmTurn(text) { return } // A48: "ja" before the filler filter
            // A16: the practice exam comes before the filler filter, "ja" can be an answer (D199 steps 6b and 6c).
            if mode == .prov, provMode.takesUnfiltered(text) { return }
            if !mode.isLive, FillerFilter.isOnlyFiller(text) {
                controller.log("\(mode.rawValue): filler only, not sent")
                discardAhead(reason: "filler")
                study.resumeListening()
                return
            }
            switch mode {
            case .interview: interviewMode.turn(text) // D199
            case .social: socialMode.turn(text) // D199 step 2
            case .rizz: rizzMode.turn(text) // D199 step 3
            case .standard:
                headMotion.stop() // answered with the voice
                provMode.silentQuiz.answeredByVoice() // A20.2: "ja" / "nej" by voice; A38
                standardMode.turn(text) // D199 step 5
            case .prov:
                // D199 step 6c: the mini test, then the exam session, then the ordinary turn to the tutor.
                provMode.turn(text)
            }
        case .stalled:
            liveMode.stalled()
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

    // D72: the interviewer's question gets the finished answer; the wearer's own words are not answered. The turn,
    // the ahead request and "Lumen, …" are `InterviewModeController` now (D199 step 1).

    /// Likely questions and model answers from the role or job ad. Long, so it is shown, not spoken.
    func prepareInterview() {
        interviewMode.prepare()
    }

    // MARK: - Rizzläge (D43)

    // The live turn, the instructions and the suggestions are `LiveModeController` (D199 step 2). Rizzläge's own rules
    // (its style, D63's age check) are `RizzModeController` (step 3); the screens' flags stay here until step 4.

    // MARK: - Voice (D74)

    // The question gate's timer at the pause (D78, A68, A72) is `StandardModeController` now (D199 step 5).

    /// A162 (D259): "Säg [ … ] så aktiveras vår AI". When the user's own words are heard in a finished turn, the
    /// question that was just asked is answered as usual: what came before the words in the same turn, else what
    /// follows them, else the last thing heard before this turn. The words themselves are never sent, and a turn
    /// with them is never an ordinary turn. Not in Socialt and Rizz, which give suggestions, not answers. True
    /// when the words were heard.
    private func answerForActivationWords(in raw: String) -> Bool {
        let phrase = activation.settings.phrase
        guard !phrase.isEmpty, !mode.isLive, let match = ActivationPhrase.match(phrase, in: raw) else { return false }
        discardAhead(reason: "the activation words")
        let earlier = conversation.finalSegments
            .filter { !$0.overlapsPlayback && ActivationPhrase.match(phrase, in: $0.text) == nil }
            .map(\.text)
        if let question = ActivationPhrase.question(for: match, earlier: earlier) {
            controller.log("Activation words heard: answering the question just asked (\(question.count) characters)")
            activation.answer(heard: question, language: language)
        } else {
            controller.log("Activation words heard, but no question before them")
        }
        study.resumeListening()
        return true
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

    /// A13.3: the "Förhör mig" button on Provläge's empty screen: the same as saying "Lumen, förhör mig".
    func askForQuiz() {
        tips.markUsed(.quizMe)
        instruct("förhör mig")
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
            var busy = self.exam != nil || self.practice != nil || self.miniTest != nil || self.speaker.isSpeaking || self.speaker.hasPendingSpeech
                || self.activation.pendingDueAt != nil || self.activation.hasQueued || quietFor < Self.tipPause
                || self.transcription.hasWaitingWords || self.transcription.vadSpeaking() == true // A56 (Toby T5b finding 3)
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
            // A9.3: these presets are also corrections of the answer just given.
            if ["förklara enklare", "ge ett exempel"].contains(text) { learnCorrection(text == "ge ett exempel" ? "mer exempel" : "enklare") }
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
            learnCorrection("det där var fel")
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
                confirm("Det är redan högsta volymen i EarMind. Höj på telefonen.")
                return
            }
            settings.speechGain = action == .whisper ? settings.speechGain * 0.6 : settings.speechGain / 0.6
            applySpeechVolume()
            controller.log("Voice gain \(String(format: "%.2f", settings.speechGain))")
            confirm(action.confirmation)
        case .shorter, .longer:
            learnCorrection(action == .shorter ? "kortare" : "längre")
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
        // A17: the kept audio for 120 s; after that the same text is read again (no new answer is made).
        if let last = lastAnswerAt, Date().timeIntervalSince(last) > Self.repeatAudioAge,
           let text = conversation.answers.last?.answer, !text.isEmpty {
            controller.log("Repeat: older than \(Int(Self.repeatAudioAge)) s, the same text is spoken again")
            speaker.enqueue(text, language: language)
            return
        }
        do {
            transcription.setInputGated(true) // our own voice again: the recogniser must not hear it
            ownSpeechStarted(conversation.answers.last?.answer ?? "") // A21.3
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

    static let repeatAudioAge: TimeInterval = 120

    // MARK: - A15 "Mer?" after a short answer

    // The window, "ja" from the partial (A65) and the developed answer (A56, A67) are `MoreWindow` in
    // `StandardModeController.swift` (D199 step 5). `isOfferingMore` above reads it for the screen.

    /// A62 (K40): the answer key of the last answer, sent back with the next call in Provläge; its words go first among
    /// Scribe's keyterms while the question is asked ("Nilen", not "Nilan").
    @ObservationIgnored private var lastQuizKey: QuizKey?
    @ObservationIgnored private var quizTerms: [String] = []

    private func quizKeyArrived(_ key: QuizKey?) {
        lastQuizKey = key
        guard mode == .prov, let key else {
            quizTerms = [] // taken out at the next reconnect, no reconnect for that
            return
        }
        quizTerms = key.terms
        refreshKeyterms()
        guard !transcription.isConnectedKeyterm(key.answer) else { return } // already heard right: no reconnect
        Task { await transcription.applyQuizKeytermsNow() }
    }

    /// A17: the voice profile says someone else spoke (nil without a profile or when unknown).
    func isOtherVoice(near date: Date) -> Bool? {
        guard let speakers, speakers.profiles.isEnrolled, let identity = speakers.identity(near: date, window: 4) else { return nil }
        return !identity.isWearer
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
        if let block = startBlock(for: target) { // D199 step 4: the mode says what is missing
            say(block.spokenLine(for: target))
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
        if current != nil { conversation.markModeSwitch(to: target.shortName) } // Ke35: "Bytte till …" on Lyssnar
        say(VoiceChannel.spokenName(target))
    }

    private func pauseByVoice() async {
        guard isListening else { return }
        say(language == .swedish ? "Pausar." : "Pausing.")
        await speechDone()
        await controller.pause()
    }

    private func stopByVoice() async {
        if silentQuiz != nil {
            provMode.silentQuiz.end() // A20.2: the first "sluta" ends the quiz, the next one Provläge
            return
        }
        if practice != nil {
            practiceExam.finish(speak: true) // A16: the first "avsluta" ends the practice exam with its result
            return
        }
        if provMode.studyPlan.summarizeBeforeEnding() { return } // A19.2: the summary first, then Lumen stops
        say(language == .swedish ? "Slutar lyssna." : "Stopping.")
        await speechDone()
        await stopListening()
    }

    /// What follows the name when it is not a command. Socialt läge and Rizzläge: the D69 instruction path.
    /// The other modes: a question to Lumen.
    func instruct(_ text: String) {
        // A16: "Lumen, nästa" in the practice exam works as well as "nästa". D84: in the exam session only exam
        // commands count (D199 steps 6a–6c).
        if provMode.takesInstruction(text, inProv: mode == .prov) { return }
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
        if SilentQuiz.isStartCommand(text), study.isActive, mode == .prov {
            startSilentQuiz() // A20.2: "Lumen, tyst förhör" closing a turn before its final arrived
            return
        }
        if PracticeRun.isStartCommand(text), examMaterials?.isReady == true {
            Task { await startPracticeExam() } // A16: "Lumen, kör övningsprovet"
            return
        }
        if ProfileStatement.isAboutSchool(text) {
            profileStatement(text) // D84: in every mode
            return
        }
        if rizz != nil {
            liveInstruction(text)
        } else if study.isActive, mode == .interview {
            interviewMode.instruction(text) // D199
        } else if study.isActive, mode == .prov, StudyProfileVoice.apply(text, to: &studyProfile.profile) {
            // D83: "Lumen, korta förklaringar", "Lumen, provet är på fredag" …
            studyProfileChanged()
            controller.log("Provläge profile changed by voice")
            say(language == .swedish ? "Uppdaterat." : "Updated.")
        } else if mode == .standard {
            standardMode.instruction(text) // D199 step 5
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
        switch mode { // D199 steps 2 and 3
        case .social: socialMode.instruction(text)
        case .rizz: rizzMode.instruction(text)
        case .standard, .prov, .interview: liveMode.instruction(text) // as before: the session decides, not the mode
        }
    }

    /// A short confirmation in the AirPods. Not while paused: the audio belongs to someone else then.
    func say(_ line: String) {
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

    func answerSuggestions(_ options: [String]) {
        liveMode.suggestionsArrived(options) // D199 step 2
    }

    /// "nästa", or the button on the Live Activity. With one suggestion on screen (D72) it asks for a fresh one.
    func nextSuggestion() {
        liveMode.nextSuggestion()
    }

    /// The voice has taken the last sentence. Its sound may still be playing for many seconds (Toby T7: 2.8–13.3 s),
    /// so everything that waits for the student (the "Mer?" window, a tip, a nod, a waiting question) starts when the
    /// recogniser opens again, in `recognizerOpenAfterSpeech` (A21/T7).
    private func speechFinished() {
        controller.playback.stopRecordingSpeech()
        if study.isActive, finishSingleTurn() { return }
        reopenRecognizerAfterSpeech()
    }

    /// Lumen's sound is over and the recogniser hears again: now the student can answer (Toby T7 findings 1–2).
    private func recognizerOpenAfterSpeech(askedNext: Bool) {
        if !askedNext {
            provMode.listenForHeadAnswerIfAsked() // D83 (G7 step 7a)
            provMode.silentQuiz.afterSpeech() // D199 step 6d
            watchForNoteTaking()
            scheduleTip()
            standardMode.more.offerIfShort()
        }
        if !study.isActive { standardMode.askWaitingQuestionIfIdle() }
    }

    // The queue of split turns (A8.4, A21.1) is `TurnQueue`, and the nod that answers a check question (D83) is in
    // `ProvModeController` (G7 step 7a).

    /// D82: the recogniser opens again only when Lumen's voice has really stopped playing, plus 0.7 s for its echo.
    private func reopenRecognizerAfterSpeech() {
        ungateTask?.cancel()
        ungateTask = Task { [weak self] in
            guard let self else { return }
            // A72 (Toby T14 finding 1): how long the player still plays after the voice's queue is done, logged so
            // T15 shows where the 4–6 s after the speech go (the player's real end, or a late `onFinished`).
            let finishedAt = Date()
            var waited = 0
            while self.controller.playback.isSpeaking, waited < 600 {
                try? await Task.sleep(for: .milliseconds(50))
                waited += 1
            }
            let sinceSentence = self.lastSentenceStartedAt.map { Int(finishedAt.timeIntervalSince($0) * 1000) } ?? -1
            self.controller.log("Recogniser reopens: voice done \(sinceSentence) ms after its last sentence began, player quiet \(waited * 50) ms later, + \(Int(Self.echoTail * 1000)) ms tail (A72)")
            try? await Task.sleep(for: .seconds(Self.echoTail))
            guard !Task.isCancelled, !self.speaker.isSpeaking else { return } // A21.3: the safety timer opens it then
            self.ownSpeechEnded()
            self.transcription.setInputGated(false)
            var askedNext = false
            if self.study.isActive {
                askedNext = self.turnQueue.askNext()
                if !askedNext { self.study.resumeListening() }
            }
            self.recognizerOpenAfterSpeech(askedNext: askedNext)
        }
    }

    // MARK: - A20.1 the pace adapts

    /// The learned pace for the current mode and subject goes to the voice.
    func applyPace() {
        let factor = paces.factor(mode: mode, subject: prefSubject)
        speaker.paceFactor = Float(factor)
        paceSignals.reset()
    }

    /// True when the pace changed. "Snabbare" at full speed is not a pace request: it stays "kortare" (A7).
    @discardableResult
    private func changePace(_ request: SpeechPace.Request, why: String) -> Bool {
        let current = paces.factor(mode: mode, subject: prefSubject)
        let next = request == .slower ? SpeechPace.slower(than: current) : SpeechPace.faster(than: current)
        guard next != current else {
            if request == .slower, why == "asked" { say("Jag pratar redan så långsamt jag kan.") ; return true }
            return false
        }
        paces.set(next, mode: mode, subject: prefSubject)
        speaker.paceFactor = Float(next)
        controller.log(String(format: "Pace %.2f → %.2f (%@, A20)", current, next, why))
        say(next < current ? "Jag pratar lite långsammare." : "Jag pratar snabbare igen.")
        return true
    }

    /// Provläge: a long silence after a long answer looks like writing it down (A20.1).
    private func watchForNoteTaking() {
        noteTask?.cancel()
        guard study.isActive, mode == .prov, silentQuiz == nil, exam == nil, practice == nil, miniTest == nil,
              let answer = conversation.answers.last?.answer,
              answer.split(separator: " ").count >= 25 else { return }
        let answersBefore = conversation.answers.count
        noteTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(SpeechPace.noteSilence))
            guard let self, !Task.isCancelled, self.isListening, self.conversation.answers.count == answersBefore,
                  !self.study.isUserSpeaking else { return }
            self.controller.log("Long silence after an answer: note-taking (A20)")
            if self.paceSignals.tookNotes() { self.changePace(.slower, why: "note-taking") }
        }
    }

    // MARK: - A20.2 Tyst förhör

    /// The button on Lyssnar and "Lumen, tyst förhör". The quiz itself is `SilentQuizController` (D199 step 6d).
    func startSilentQuiz() {
        provMode.silentQuiz.start()
    }

    // MARK: - A21.3 the recogniser never stays closed for Lumen's voice longer than that voice should last

    private func ownSpeechStarted(_ text: String) {
        ownSpeech.spoke(text, rate: Double(speaker.settings.rate), at: Date())
        armGateWatchdog()
    }

    private func ownSpeechEnded() {
        ownSpeechEndedAt = Date() // A28: what starts later than the tail is the wearer, not Lumen's echo
        ownSpeech.reset()
        gateWatchdog?.cancel()
        gateWatchdog = nil
    }

    private func armGateWatchdog() {
        gateWatchdog?.cancel()
        gateWatchdog = Task { [weak self] in
            var quietSince: Date?
            while true {
                guard let deadline = self?.ownSpeech.deadline else { return }
                let wait = deadline.timeIntervalSinceNow
                if wait <= 0 { break }
                try? await Task.sleep(for: .seconds(min(wait, ListeningModel.quietPoll)))
                if Task.isCancelled { return }
                // A56 (Toby T5b finding 2): the voice may report its end before its last sentence started (the
                // gate closed again and nothing opened it until this deadline, 56 s). When nothing plays, nothing
                // waits to be said and no answer streams, for `quietToReopen`, the recogniser opens as usual.
                guard let model = self else { return }
                if model.ownSpeechLooksOver {
                    let since = quietSince ?? Date()
                    quietSince = since
                    if Date().timeIntervalSince(since) >= ListeningModel.quietToReopen {
                        model.controller.log("Lumen's voice is quiet but the input stayed gated: opened as after speech (A56)")
                        model.reopenRecognizerAfterSpeech()
                        return
                    }
                } else {
                    quietSince = nil
                }
            }
            self?.ownSpeechOverdue()
        }
    }

    static let quietPoll: TimeInterval = 0.5
    static let quietToReopen: TimeInterval = 1.0

    /// The input is gated for Lumen's voice, but nothing plays or waits to be said, and no answer streams.
    /// A63 (Toby T12): with `two_level` the stream goes on after the short answer is spoken (`more_delta`, never
    /// spoken), so a streaming answer counts as over when Lumen has had nothing new to say for `streamQuiet`.
    private var ownSpeechLooksOver: Bool {
        guard transcription.isInputGated, !controller.playback.isSpeaking, !speaker.isSpeaking, !speaker.hasPendingSpeech else { return false }
        if case .answering = answers.status {
            return lastSpokeTextAt.map { Date().timeIntervalSince($0) >= Self.streamQuiet } ?? false
        }
        return true
    }

    /// A68: Lumen is saying something, or an answer streams that still gives it things to say (a stream that only
    /// sends the developed part, `more_delta`, for `streamQuiet` is not in the way of a new question).
    var lumenIsBusyAnswering: Bool {
        if controller.playback.isSpeaking || speaker.hasPendingSpeech { return true }
        if case .answering = answers.status {
            // Nothing said yet for this call: its answer is coming, the question waits for it.
            guard let spoke = lastSpokeTextAt, let asked = answerRequestedAt, spoke >= asked else { return true }
            return Date().timeIntervalSince(spoke) < Self.streamQuiet
        }
        return false
    }

    /// A70 (Toby T14): why a waiting question is held, for the log.
    var busyReason: String {
        var parts: [String] = []
        if controller.playback.isSpeaking { parts.append("playback speaking") }
        if speaker.hasPendingSpeech { parts.append("speech pending") }
        if case .answering = answers.status {
            let spoke = lastSpokeTextAt.map { String(format: "%.1f s ago", Date().timeIntervalSince($0)) } ?? "never"
            let asked = answerRequestedAt.map { String(format: "%.1f s ago", Date().timeIntervalSince($0)) } ?? "never"
            parts.append("answer streaming (spoke \(spoke), call \(asked), ahead \(ahead != nil))")
        }
        return parts.isEmpty ? "nothing" : parts.joined(separator: ", ")
    }

    // MARK: - A76 (D140) the test mode: the audio and what happened, for us

    /// The kept audio, the pieces and the upload are `DebugAudioController` (D221, G7 step 7d). The screens and
    /// AppContainer use the test mode through the model, as before.
    ///
    /// A142 (D218 point 4): only in the builds for us and our testers (`LUMEN_TESTMODE`: Debug and Beta). The App Store
    /// build (Release) has no test mode: no switch, nothing kept and nothing sent.
    #if LUMEN_TESTMODE
    let debugAudio = DebugAudioController()

    /// The test mode switch (Inställningar, or on for a test account by K43's flag).
    var testMode: TestModeSettings? {
        get { debugAudio.testMode }
        set { debugAudio.testMode = newValue }
    }

    /// True while the microphone's audio is being kept for us (the indicator says "Testläge · ljud skickas").
    var isRecordingDebugAudio: Bool { debugAudio.isRecording }

    var debugAudioClient: DebugAudioClient? {
        get { debugAudio.client }
        set { debugAudio.client = newValue }
    }

    /// Starts or stops keeping the audio to match the switch, the server and the listening.
    func updateDebugAudio() {
        debugAudio.update()
    }

    #if DEBUG
    /// The screenshots (Kelly Ke48): Lyssnar as it looks while the audio is sent; nothing is recorded.
    func stageTestModeForScreenshot() { debugAudio.stageForScreenshot() }
    #endif

    /// The switch in Settings: the tester's own choice goes to the server (K43 `opt_in`/`opt_out`).
    func testModeSwitched() async {
        await debugAudio.switched()
    }
    #else
    /// The App Store build: there is no test mode, so the screens show no switch and no badge.
    var testMode: TestModeSettings? { nil }
    var isRecordingDebugAudio: Bool { false }
    func updateDebugAudio() {}
    func testModeSwitched() async {}
    #endif

    /// A74: the questions asked in the last minute (Standardläge), so a late copy is not answered again.
    @ObservationIgnored private var repeatGuard = RepeatGuard()
    /// T17 finding 5: the question asked again after an empty answer ahead (once).
    @ObservationIgnored private var emptyRetried: String?
    /// T57 (Toby): the answer made ahead was refused because the server's model is down, and when.
    @ObservationIgnored private var aheadRefused: (error: AnswerError, at: Date)?
    /// The pause comes within a second or two of the words; for this long the turn is not sent to the server again.
    static let aheadRefusalMemory: TimeInterval = 10
    /// T15b finding 6: the whole utterance whose first question was asked alone (once per utterance).
    @ObservationIgnored private var splitRetried: String?

    /// A68: when the current `/answer` call was sent.
    @ObservationIgnored private var answerRequestedAt: Date?

    /// A63: when Lumen was last given text to say.
    @ObservationIgnored private var lastSpokeTextAt: Date?
    static let streamQuiet: TimeInterval = 2.5

    /// The voice did not report its end within its estimated length + 2 s: open the recogniser anyway (A21.3).
    private func ownSpeechOverdue() {
        let started = ownSpeech.startedAt
        ownSpeech.reset()
        gateWatchdog = nil
        guard isListening, transcription.isInputGated else { return }
        gateWatchdogOpens += 1
        let seconds = started.map { Int(Date().timeIntervalSince($0).rounded()) } ?? 0
        controller.log("STT input opened by the safety timer: no end of Lumen's speech after \(seconds) s "
            + "(playback speaking \(controller.playback.isSpeaking), speaker speaking \(speaker.isSpeaking)) (A21)")
        ungateTask?.cancel()
        transcription.setInputGated(false)
        var askedNext = false
        if study.isActive, study.phase != .listening {
            askedNext = turnQueue.askNext()
            if !askedNext { study.resumeListening() }
        }
        recognizerOpenAfterSpeech(askedNext: askedNext)
    }

    /// Settings → Ekoreducering changed: a running session follows at once.
    func echoCancellationChanged() async {
        await controller.reevaluateVoiceProcessing()
    }

    /// D82: most of the words are something Lumen just said: its own voice came back.
    /// A28: when the last own speech ended (after its echo tail), and when the current study turn began.
    @ObservationIgnored private var ownSpeechEndedAt: Date?
    @ObservationIgnored private var turnStartedAt: Date?

    private func isOwnEcho(_ text: String, at date: Date, startedAt: Date? = nil, overlapsPlayback: Bool = false) -> Bool {
        guard let share = echo.overlap(text, now: date), share >= EchoFilter.overlap else { return false }
        if let startedAt, !EchoFilter.mayBeEcho(startedAt: startedAt, speaking: speaker.isSpeaking || ownSpeech.deadline != nil,
                                                overlapsPlayback: overlapsPlayback, lastSpeechEnd: ownSpeechEndedAt) {
            controller.log(String(format: "Not echo: %.0f %% of the words were Lumen's, but said after Lumen stopped (A28)", share * 100))
            return false
        }
        controller.log(String(format: "Echo filtered: %.0f %% of the words were Lumen's own", share * 100))
        return true
    }

    /// Rizzläge / Socialt läge: the wearer saying the suggestion out loud is its use, not Lumen's echo. Through
    /// AirPods Lumen is never heard by the microphone (D82, owner); out of the iPhone's own speaker it can be.
    private func isWearerUsingSuggestion(_ text: String, level: Double?) -> Bool {
        liveMode.isWearerUsingSuggestion(text, level: level) // D199 step 2
    }

    /// The answer produced no speech (silent mode, empty answer): back to listening right away.
    private func studyAnswerEnded() {
        guard study.isActive, !mode.isLive, !speaker.hasPendingSpeech, !finishSingleTurn() else { return }
        transcription.setInputGated(false)
        if !turnQueue.askNext() { study.resumeListening() }
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
    func liveLabel() -> String? {
        guard let speakers, speakers.showsLabels, let identity = speakers.identity(near: Date()), identity.isOther else { return nil }
        return SpeakerLabeler.text(identity, swedish: true)
    }

    /// The voice when it is known and there is a profile to compare with; otherwise the level, as before D81.
    func turnSpeaker(level: Double?) -> (speaker: RizzSpeaker, why: String) {
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
        if let first = resources.first, let session = ResourceSample.sessionLine(from: first, to: to) {
            line += " · " + session // A47 (D121): battery per hour over the whole session
        }
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

    /// Toby T8b finding 4: Starta was pressed and nothing started, and nothing on the screen says why (no problem
    /// card, no sheet that asks something first: the listening consent, the age, a mode's own start screen).
    var startDidNotTake: Bool {
        !isActiveSession && problem == nil && !asksForListeningConsent && !isShowingAgeGate && !isShowingLiveStart
            && !isShowingInterviewSetup && !isShowingAddExam && !isShowingStudyOnboarding
    }

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
        case .airPodsLostPaused:
            // "Lyssna vidare": on with the phone's speaker (the line "Inga AirPods anslutna" says so).
            self.problem = nil
            Task { await controller.resume() }
        case .voiceUnavailable:
            self.problem = nil
        case .overloaded, .offline:
            self.problem = nil
            askFailedQuestionAgain()
        case .cannotHear:
            self.problem = nil
        }
    }

    /// The card's "Försök igen": the question whose answer failed, asked again. It is the one asked last
    /// (`pendingQuestion`); an earlier, answered question is never asked again in its place.
    private func askFailedQuestionAgain() {
        let failed = pendingQuestion
        guard let question = failed?.query ?? conversation.answers.last?.question,
              !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        repeatGuard.forget(question) // it was never answered (A74 is about answered questions)
        activated(ActivationRequest(query: question, trigger: failed?.trigger ?? .text, language: failed?.language ?? language),
                  persona: mode == .prov ? tutorPersona() : nil)
    }

    /// The short notices under the answers, in Swedish.
    var visibleNotices: [String] {
        [studyNotice, reportNotice, fallbackNotice].compactMap { $0 }
    }

    /// A45: "Lumen hör och pratar lite sämre just nu", once per session, while a stand-in engine is used.
    private(set) var fallbackNotice: String?
    @ObservationIgnored private var fallbackNotedThisSession = false
    nonisolated static var fallbackLine: String { String(localized: "EarMind hör och pratar lite sämre just nu") }

    private func noteFallback(what: String) {
        guard !fallbackNotedThisSession else { return }
        fallbackNotedThisSession = true
        fallbackNotice = Self.fallbackLine
        controller.log("Stand-in engine for \(what): said once on Lyssnar (A45)")
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
        // A12: without the microphone Start stays, with the card that says why and opens Settings.
        showsListeningScreen = problem != .microphoneDenied || isActiveSession
    }

    /// A53 (K37): what `/my-answers suggest` knows about the exam (subject, grade, name, course goals, its terms).
    func myAnswersContext(for examID: UUID?) -> MyAnswersClient.Context {
        let plan = examPlans?.plans.first { $0.id == examID } ?? examPlans?.nearest()
        let profile = studyProfile.profile
        return MyAnswersClient.Context(subject: plan?.subject ?? (profile.subject.isEmpty ? nil : profile.subject),
                                       grade: (plan?.grade ?? profile.grade)?.rawValue,
                                       exam: plan?.name,
                                       goals: goals.compact,
                                       terms: Array((profile.terms ?? []).prefix(50)))
    }

    /// Ke35 (Toby T8b finding 3): a new start from Start begins with an empty Lyssnar; the old answers are in Historik.
    /// Switching mode while Lumen listens keeps them.
    func beginFreshPass() {
        guard !isActiveSession else { return }
        conversation.clear()
        standardMode.more.forget()
    }

    /// A50 (D124): Start's big button starts the chosen mode. Provläge goes to the nearest exam when there is one,
    /// like "Förhör mig" without the quiz's first question.
    func startSelectedMode() async {
        beginFreshPass()
        if selectedMode == .prov, !(study.isActive || isListening), let plan = examPlans?.upcoming().first {
            await startProv(for: plan)
            showsListeningScreen = problem != .microphoneDenied || isActiveSession
            return
        }
        await startMode(selectedMode)
    }

    /// "Byt läge": the same checks as the screen and the voice; listening goes on.
    func switchMode(to target: ConversationMode) async {
        if let block = startBlock(for: target) { // D199 step 4: the mode says what is missing, the app shows it
            selectedMode = target
            show(block)
            return
        }
        await switchByVoice(to: target)
    }

    /// "Avsluta" (app, lock screen, voice): ends the mode and the microphone.
    func endSession() async {
        if !provMode.studyPlan.isSummarizing, provMode.studyPlan.summarizeBeforeEnding() { return } // A19.2; a second tap ends at once
        provMode.studyPlan.cancelSummary()
        await endNow()
    }

    private func endNow() async {
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
            return cards.prefix(2).map(\.question).joined(separator: String(localized: " och "))
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
        provMode.miniTest.drop()
        examSession.begin(paper: examMaterials.paper) // D199 step 6a
    }

    // The commands, the exam time and the summary are `ExamSessionController` (D199 step 6a).

    // MARK: - The practice exam by voice (A16, K15)

    /// "Kör övningsprovet": Provläge reads the uploaded practice exam one question at a time.
    func startPracticeExam() async {
        guard let examMaterials, let run = PracticeRun(paper: examMaterials.paper) else { return }
        isShowingExamSetup = false
        if !(study.isActive && mode == .prov) {
            selectedMode = .prov
            await startStudy()
            guard study.isActive, mode == .prov else { return }
        }
        provMode.miniTest.drop()
        examSession.drop() // D199 step 6a: as before, without a summary
        provMode.silentQuiz.end()
        practiceExam.begin(run) // D199 step 6b
    }

    // The turn, the grading and the result are `PracticeExamController` (D199 step 6b).

    func dismissPracticeResult() {
        practiceExam.dismissResult()
    }

    #if DEBUG
    /// A30 (Kelly Ke20): screenshots of Lyssnar while listening in a mode, and of the practice exam on Lyssnar,
    /// without a microphone or network. Debug builds only (`ScreenshotStage`).
    var screenshotShows: ConversationMode?

    func stagePracticeForScreenshot(_ run: PracticeRun?, result: PracticeRun.Summary?) {
        screenshotShows = .prov
        practiceExam.stage(run, result: result)
    }
    #endif


    // MARK: - A photographed page (A36, D115)

    /// The reading, the practice questions and what starts afterwards are `PagePhotoController` (D221, G7 step 7d).
    let pagePhoto = PagePhotoController()

    /// What "Fota sidan" is doing, for the exam card ("Läser sidan …"); nil when nothing is.
    var pagePhotoStatus: String? { pagePhoto.status }
    var isReadingPage: Bool { pagePhoto.isReading }

    func studyPhotographedPage(_ image: UIImage, for plan: ExamPlan) async {
        await pagePhoto.study(image, for: plan)
    }

    func clearPagePhotoStatus() {
        pagePhoto.clearStatus()
    }

    // MARK: - Study plan, summary and links (A19: K17, K19)

    /// Asks `/study-plan` for every upcoming exam: what is due today, and the days up to the exam (local reminders).
    /// The plan itself is `StudyPlanController` (D199 step 6e).
    func refreshStudyPlan(askForReminders: Bool = false) async {
        await provMode.studyPlan.refresh(askForReminders: askForReminders)
    }

    /// A43 (K33): how ready the student is for the exam, when the backend could count it.
    func readiness(for plan: ExamPlan) -> StudyPlanAPI.Readiness? {
        provMode.studyPlan.readiness(for: plan)
    }

    /// "I dag: 10 min Biologi (cellandning, klorofyll)" when the plan has a pass today.
    func todayLine(for plan: ExamPlan) -> String? {
        provMode.studyPlan.todayLine(for: plan)
    }

    /// A43: what the student already knows for the exam: right the last two times or more (K33 counts three in a
    /// row as full, two as most of it). At most six, by name.
    func knownConcepts(for plan: ExamPlan) -> [String] {
        Self.known(studyHistory.history(for: plan.id))
    }

    nonisolated static func known(_ history: [String: [StudyHistory.Entry]], limit: Int = 6) -> [String] {
        let known = history.filter { _, entries in entries.count >= 2 && entries.suffix(2).allSatisfy(\.ok) }.map(\.key)
        return Array(known.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }.prefix(limit))
    }

    #if DEBUG
    /// A38/A43: the plan's reply and the quiz days for the Simulator screenshots (no network there).
    func stageStudyPlanForScreenshot(_ plan: ExamPlan, reply: StudyPlanAPI.ExamPlanReply, quizDays days: [String]) {
        provMode.studyPlan.stage(plan, reply: reply)
        quizDays = QuizDays(days: days)
        streak = quizDays.streak()
    }
    #endif

    /// A49: "Sov": Lumen's own listening ends first (one microphone user at a time), then the night starts.
    func startSleep() async {
        if isListening || study.isActive { await endSession() }
        sleep.start()
        controller.log("Sleep mode started (A49)")
    }

    // MARK: - A48 (D122, K35): phone tools

    /// The model asked for a tool (`AnswerSink`). The tools are `PhoneToolsController` (D221, G7 step 7d).
    func answerToolCall(_ call: PhoneToolCall) {
        tools.answer(call)
    }

    /// "Ja" / "Nej" on Lyssnar, or the voice.
    func confirmTool(_ yes: Bool) {
        tools.confirm(yes)
    }

    /// A38 (K31): a quiz answer today (Förhör mig, the practice exam, the mini test, the silent quiz, flip cards).
    /// The day's first one keeps the streak and takes away today's reminder.
    func noteQuizAnswer(at date: Date = Date()) {
        guard quizDays.record(date) else { return }
        quizDays.save()
        streak = quizDays.streak(today: date)
        LumenNotifications.cancelToday(date)
        updateWidget(now: date) // A44
        controller.log("Quiz day: streak \(streak.current) (A38)")
    }

    // Today's line, the summary at "avsluta" and the link are `StudyPlanController` (D199 step 6e).

    // MARK: - Study cards and the mini test (D81)

    /// A Provläge answer becomes a card; during the mini test the answer is the tutor's verdict.
    private func studyCardOrGrade(_ turn: AnswerTurn) {
        if provMode.miniTest.graded(by: turn.answer) { return } // D199 step 6c: the tutor's verdict on a card
        // A38: an answer to Lumen's own check question in Förhör mig counts for the streak.
        if mode == .prov, study.isActive, turn.isOwnQuestion,
           let index = conversation.answers.firstIndex(where: { $0.id == turn.id }), index > 0,
           conversation.answers[index - 1].answer.trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix("?") {
            noteQuizAnswer()
        }
        guard mode == .prov, miniTest == nil, pendingQuestion?.trigger == .tutor, let studyCards else { return }
        if studyCards.add(question: turn.question, answer: turn.answer, profile: studyProfile.profile) != nil {
            controller.log("Study card saved (\(studyCards.cards.count) in all)")
        }
    }

    private func provSessionEnded() {
        lastProvSessionStart = provStartedAt ?? lastProvSessionStart
        provStartedAt = nil
        if provMode.miniTest.endWithSession() { return } // D199 step 6c
        guard let studyCards, let start = lastProvSessionStart,
              studyCards.current().contains(where: { $0.createdAt >= start }) else { return }
        fetchStudyCards(since: start)
        studyNotice = language == .swedish
            ? "Minitest: fem frågor om det du nyss frågade. Tryck på Minitest eller säg ”Lumen, minitest”."
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

    // MARK: - A46 (N6): flip cards, on the screen without the voice

    /// The deck and what an answered card counts as are `FlipCardsController` (D221, G7 step 7d).
    let flipCards = FlipCardsController()

    /// The exam's study cards as flip cards, nil when there is none.
    func flipDeck(for plan: ExamPlan) -> FlipDeck? {
        flipCards.deck(for: plan)
    }

    /// One flip card answered: it counts like a quiz answer (the card, the tutor's concept stats, the study plan).
    func recordFlip(_ card: StudyCard, knew: Bool, for plan: ExamPlan) {
        flipCards.record(card, knew: knew, for: plan)
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
        provMode.miniTest.begin(cards: cards) // D199 step 6c
    }

    // The questions, the skip and the tutor's grading are `MiniTestController` in `ProvModeController.swift`.

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

    func activated(_ request: ActivationRequest, persona: PersonaRequest? = nil) {
        let activatedAt = Date() // A72 part 3: how long it takes from here to the request
        if VoiceCommand.isMusicHandOff(request.query) { return } // the final result already paused the session
        // A8 (owner, 2026-11-08): Frågor answers the wearer's own questions too. D81's "Auto never answers the
        // wearer" made Lumen silent when Aron asked, with a voice profile. The voice is only logged now.
        if request.trigger == .auto, isWearersVoice() { controller.log("Auto: the wearer's own voice (answered, A8)") }
        if request.trigger == .auto, FillerFilter.isOnlyFiller(request.query) {
            controller.turns.dropped(request.query, mode: mode.rawValue, trigger: request.trigger.rawValue, reason: "filler")
            return
        } // D74
        if request.trigger == .auto {
            // A74 (Aron's phone test): the same question within 60 s is not answered a second time.
            if let earlier = repeatGuard.repeats(request.query, at: Date()) {
                controller.log("Auto: the same question as \"\(earlier)\" within 60 s, not asked again (A74)")
                controller.turns.dropped(request.query, mode: mode.rawValue, trigger: request.trigger.rawValue, reason: "repeat")
                return
            }
            repeatGuard.record(request.query, at: Date())
        }
        if persona?.social == nil, deliverAhead(for: request) { return } // D80: ready the moment the pause is over
        discardAhead(reason: "a different turn")
        controller.turns.finish(currentTurnID, outcome: .interrupted, reason: "a newer turn: \(request.query)")
        currentPersona = persona?.persona
        pendingQuestion = request
        answerNotice = nil
        // A new question interrupts the current answer and its speech (assignment item 5).
        let interruptAt = Date()
        speaker.interrupt()
        let interruptMs = Int(Date().timeIntervalSince(interruptAt) * 1000)
        spokenAnswer = ""
        latency.begin(request)
        let totalMs = Int(Date().timeIntervalSince(activatedAt) * 1000)
        if totalMs >= 200 {
            // A72 part 3 (Toby T15b): 8–20 s passed between "a different turn" and this line with nothing logged.
            controller.log("Activation was held \(totalMs) ms on the phone: stopping the voice \(interruptMs) ms"
                           + (controller.playback.lastSlowStop.map { " (\($0))" } ?? "") + " (A72)")
        }
        controller.log("Activation (\(request.trigger.rawValue)): \(request.query)")
        sessionObserver?(.asked(query: request.query, trigger: request.trigger.rawValue), Date())
        if !study.isActive { logTurn() }
        timeline = TurnTimeline(heardAt: lastHeardAt, requestAt: Date(), pauseEndAt: Date(), answeredAhead: false)
        let sent = self.context(for: request)
        lastSent = (request, persona) // A48: a tool call belongs to this request
        currentTurnID = controller.turns.begin(fragment: request.query, mode: mode.rawValue, trigger: request.trigger.rawValue,
                                               transcript: sent.transcript)
        answerRequestedAt = Date() // A68
        // T57 (Toby): the answer made ahead for this turn (on the words heard so far) was refused a moment ago
        // because the server's model is down. The finished turn gets that same no, and the server is not asked again.
        let refused = aheadRefused
        aheadRefused = nil
        if let refused, Date().timeIntervalSince(refused.at) < Self.aheadRefusalMemory {
            answers.answer(request, context: sent, persona: persona, refusedJustNow: refused.error)
            return
        }
        answers.answer(request, context: sent, persona: persona)
    }

    private func context(for request: ActivationRequest) -> AnswerContext {
        var context = baseContext(for: request)
        context.sessionEnd = provMode.studyPlan.isSummary(request) // A19.2
        context.qaLog = ConsentPolicy.allowsQALog(consent.record) // A48 (D116, K30)
        // A48 (K35): tools in Standardläge and Provläge, never on an answer fetched ahead (it may never be asked).
        let isAhead = ahead?.request.id == request.id
        if let phoneTools, mode == .standard || mode == .prov, !isAhead {
            context.toolsAvailable = phoneTools.available.map(\.rawValue)
        }
        if let round = tools.round(for: request) { context.toolRound = round }
        // A56 (K13, D100, Toby T7b): the short answer is spoken and the developed one comes in the same call, ready
        // for "ja" in the Mer? window without a new call.
        context.twoLevel = MoreWindow.applies(to: mode)
        context.connections = spotifyConnection?.connections ?? [] // A59 (K36)
        context.utteranceSeconds = transcription.lastUtteranceSeconds // A74 (K42.5)
        context.capabilities = LumenCapability.grantedPermissions() // A77 (K44): "kan du …?" answered from what is allowed
        if mode == .prov { context.quizKey = lastQuizKey } // A62 (K40): the student's answer is compared by sound
        // A53 (K37, D126): "Mina svar" for the exam, in Provläge only, when "Säg mina svar" is on.
        if mode == .prov, let myAnswers {
            context.savedAnswers = myAnswers.payload(for: currentExamID())
        }
        return context
    }

    private func baseContext(for request: ActivationRequest) -> AnswerContext {
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
                                 recentTurns: provMode.turnsBefore(request.query),
                                 examID: currentExamID()?.uuidString,
                                 preferences: preferences.settings, prefProfile: preferences.profile,
                                 prefSubject: prefSubject, prefExam: prefExam,
                                 conceptStats: conceptStats.backendItems) // A16
        }
        return AnswerContext(transcript: conversation.recentText(seconds: 60),
                             recentQA: conversation.recentQA(limit: qaLimit),
                             prepTerms: prep.backendTerms + (studyProfile.profile.terms ?? []), // D84: the subject's terms
                             goals: goals.compact,
                             commands: matched.map { AnswerContext.Command(keyword: $0.keyword, instruction: $0.instruction) },
                             memories: memory.backendItems(),
                             preferences: preferences.settings, prefProfile: preferences.profile,
                             prefSubject: prefSubject, prefExam: prefExam)
    }

    /// A9.3: the subject and exam a setting's scope is checked against (K10 `pref_context`).
    private var prefSubject: String? {
        let subject = studyProfile.profile.subject.trimmingCharacters(in: .whitespaces)
        return mode == .prov && !subject.isEmpty ? subject : nil
    }

    private var prefExam: String? {
        guard mode == .prov, let id = currentExamID() else { return nil }
        return examPlans?.plans.first { $0.id == id }?.name
    }

    /// The context of the last answer, for a learned setting's scope (K10.2, K13.2).
    private var lastAnswerScope: PrefScope {
        let subject = prefSubject
        let kind: String? = subject.map { $0.lowercased().hasPrefix("matem") } == true
            ? "math" : answers.lastAnswerType.map { $0 == "study" ? "explanation" : "fact" }
        return PrefScope(mode: mode.backendName, subject: subject, exam: prefExam, answerType: kind)
    }

    /// A56 (K13.2): the answer to "Mer?" teaches the backend the default length for this context.
    func sendLengthSignal(yes: Bool) {
        guard let extractor = memoryExtractor else { return }
        let context = lastAnswerScope
        let current = preferences.settings
        Task { [weak self] in
            guard let reply = await extractor.lengthSignal(yes: yes, context: context, settings: current), let self,
                  let settings = reply.settings else { return }
            self.preferences.replace(with: settings)
            if let learned = reply.setting?.text { self.controller.log("Learned length: \(learned) (A56, K13)") }
        }
    }

    /// A9.3: "kortare", "enklare", "mer exempel", "det där var fel" right after an answer become a learned setting
    /// for the context of that answer (K10.2). The phone's own effect (A7) happens as before.
    func learnCorrection(_ text: String) {
        guard let extractor = memoryExtractor, let last = lastAnswerAt, Date().timeIntervalSince(last) < 120 else { return }
        let context = lastAnswerScope
        let current = preferences.settings
        Task { [weak self] in
            guard let reply = await extractor.correct(text: text, context: context, settings: current), let self else { return }
            guard reply.skipped == nil, let settings = reply.settings else { return }
            self.preferences.replace(with: settings)
            self.controller.log("Learned setting: \(reply.setting?.text ?? "-")")
        }
    }

    // MARK: - Answer ahead, deliver at the pause (D80)

    /// A sentence was heard: start its answer now, while the speaker is still pausing. Words that come before the
    /// pause is over replace it with a new call for the whole text. One call at a time.
    private func answerAhead(for raw: String) {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isListening, !isComparing, !isEnrollingVoice, !liveMode.isInstructing, !text.isEmpty, !FillerFilter.isOnlyFiller(text),
              VoiceChannel.parse(text).intent == nil, !VoiceCommand.isMusicHandOff(text), !VoiceCommand.isComplaint(text),
              CommandMatcher.parseSaveCommand(text) == nil else { return }
        if rizz == nil, UnfinishedQuestion.looksUnfinished(text) { return } // A21.2: the rest may still come
        if rizz != nil {
            liveMode.suggestionAhead(for: text) // D199 step 2
            return
        }
        var persona: PersonaRequest?
        let request: ActivationRequest
        switch mode {
        case .standard:
            guard let ahead = standardMode.aheadRequest(for: text) else { return } // D199 step 5
            request = ahead.request
            persona = ahead.persona
        case .prov:
            guard let ahead = provMode.aheadRequest(for: text) else { return } // D199 step 6c
            request = ahead.request
            persona = ahead.persona
        case .interview:
            guard let ahead = interviewMode.aheadRequest(for: text) else { return } // D199
            request = ahead.request
            persona = ahead.persona
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
        answerRequestedAt = Date() // A68
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
        case .searching(let date): searchTone.searching(since: date) // A151: the wait counts from the search
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
        // Toby 1 T17 finding 5: an answer ahead that ended without a word ("empty_answer") would be delivered as
        // silence at the pause. Drop it, so the turn is asked again the normal way, as a failed one is.
        // Socialt and Rizz answer with suggestions, not text: only ordinary answers can be "empty".
        if case .completed(_, let done) = event, done?.answered != false, current.persona?.social == nil,
           !current.events.contains(where: \.carriesWords) {
            ahead = nil
            answers.cancel()
            aheadStats.discarded += 1
            controller.turns.finish(aheadTurnID, outcome: .failed, reason: "ahead ended empty; asked again at the pause")
            aheadTurnID = nil
            controller.log("Answer ahead ended without words: asked again at the pause (T17)")
            return true
        }
        current.record(event, at: Date())
        ahead = current
        if case .sentence = event { prefetchIfStable() }
        return true
    }

    func discardAhead(reason: String) {
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

    /// D80: a live suggestion asked for while the other person talks, at most this often (`LiveModeController`).
    static let liveRefresh: TimeInterval = 3

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
        standardMode.more.close(why: "a new answer")
        conversation.beginAnswer(question: request.query, source: source, at: request.createdAt,
                                 isOwnQuestion: request.trigger.isUsersOwnWords)
        controller.playback.startRecordingSpeech() // A7 "upprepa"
        if study.isActive { study.answerStarted() }
        searchTone.answerBegan() // A151
    }

    func answerQuestionReconstructed(_ question: String) {
        if bufferAhead(.reconstructed(question)) { return }
        conversation.setAnswerQuestion(question)
    }

    /// D233 (A151): the answer searches the web. While it is made ahead of the pause nothing may sound (D80); the
    /// moment is kept and the tone's wait counts from it when the answer is delivered.
    func answerSearching() {
        let now = Date()
        if bufferAhead(.searching(at: now)) { return }
        searchTone.searching(since: now)
    }

    func answerDelta(_ text: String) {
        if bufferAhead(.delta(text)) { return }
        searchTone.firstWord() // A151
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
        if liveMode.isInstructing {
            latency.end()
            liveMode.instructionEnded(done?.calibration, answered: true)
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
            standardMode.askWaitingQuestionIfIdle()
            return
        }
        if ahead?.delivered == true { ahead = nil }
        liveMode.requestEnded() // D199 step 2: no suggestions are being made any more
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
            if !provMode.studyPlan.isSummarizing { studyCardOrGrade(turn) } // A19.2: the summary is its own card
            showActivity()
            if mode == .prov { provMode.turnAnswered(turn.question) } // D87
            if let link = done?.resource { provMode.studyPlan.linkArrived(link, for: turn) }
            quizKeyArrived(done?.quizKey) // A62 (K40)
            standardMode.more.answerEnded(developed: done?.more, of: turn) // A56 (K13), A67
            if let tool = done?.serverTool { controller.log("Server tool: \(tool.name) \(tool.status) (A59, K36)") }
            if let saved = done?.savedAnswer {
                conversation.markSaved(saved.id, text: saved.text, on: turn.id) // A53: "Ditt svar" on Lyssnar
                controller.log("Mina svar: the saved answer was said (\(saved.via ?? "?"))")
            }
            if provMode.studyPlan.isSummarizing { provMode.studyPlan.summaryArrived(turn) }
        }
        if let fact = done?.memoryAdd {
            memory.add(fact)
        }
        if let latencyMs {
            controller.log("Answer · first text after \(Int(latencyMs)) ms" + (done?.usage?.model.map { " · \($0)" } ?? ""))
        }
        controller.turns.finish(currentTurnID, outcome: .silent, reason: "no answer text")
        studyAnswerEnded()
        standardMode.askWaitingQuestionIfIdle()
    }

    /// A9.2 / K10.1: "kan vi byta till frågor" in the user's own words. The app does it and confirms; "nej" or
    /// "ångra" within 5 s takes it back. Outside Provläge and Frågor the backend only sends it after "Lumen".
    func answerAppCommand(_ command: AppCommand) {
        lastAppCommand = (command, mode, isListening, Date())
        controller.log("App command: \(command.action) \(command.mode ?? "")")
        tips.markUsed(command.action == "switch_mode" ? .switchMode : command.action == "stop" ? .stop : .musicHandOff)
        switch command.action {
        case "switch_mode":
            guard let name = command.mode, let target = ConversationMode(backendName: name) else { return }
            Task { await switchByVoice(to: target) }
        case "pause":
            Task { await pauseByVoice() }
        case "stop":
            Task { await stopByVoice() }
        case "resume":
            Task { await resume() }
        default:
            lastAppCommand = nil
        }
    }

    /// A9.2: true when the words took the last app command back.
    private func undoAppCommandIfAsked(_ text: String, at date: Date) -> Bool {
        guard let last = lastAppCommand, date.timeIntervalSince(last.at) <= Self.undoWindow, UndoWords.matches(text) else { return false }
        lastAppCommand = nil
        controller.log("App command undone: \(last.command.action)")
        Task {
            switch last.command.action {
            case "switch_mode":
                await switchByVoice(to: last.previousMode)
            case "pause":
                await resume()
            case "stop":
                if last.wasListening { await startMode(last.previousMode) }
            case "resume":
                await pauseByVoice()
            default:
                break
            }
            say(language == .swedish ? "Okej, ångrat." : "Okay, undone.")
        }
        return true
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
        if liveMode.isInstructing {
            latency.end()
            liveMode.instructionEnded(nil, answered: true)
            return
        }
        controller.turns.setStatus(eventTurnID, status: "not_question", isQuestion: false)
        if bufferAhead(.skipped(request)) { return }
        if ahead?.delivered == true { ahead = nil }
        // Toby 1 T15b finding 6: "Vilka är de största? Barieneva-" was refused as a whole. Ask the first clear question
        // on its own once, instead of losing the turn.
        if let first = QuestionSplitter.firstClearQuestion(in: request.query), splitRetried != request.query {
            splitRetried = request.query
            controller.turns.finish(currentTurnID, outcome: .silent, reason: "not a question as a whole; first question asked alone")
            controller.log("Auto: not a question as a whole; asking the first question alone: \(first)")
            repeatGuard.forget(request.query)
            activated(ActivationRequest(query: first, trigger: request.trigger, language: request.language,
                                        gate: request.gate))
            return
        }
        latency.end()
        conversation.cancelAnswer()
        answerNotice = "Not a question — no answer (auto mode)"
        cue(.hm) // A34: heard, and chose to stay quiet
        controller.log("Auto: backend says not a question: \(request.query)")
        controller.turns.finish(currentTurnID, outcome: .silent, reason: "backend: not a question")
        studyAnswerEnded()
        standardMode.askWaitingQuestionIfIdle()
    }

    func answerFailed(_ message: String, wantsFallback: Bool) {
        provMode.studyPlan.endAfterSummary(reason: "the summary failed") // A19.2: never stuck
        if liveMode.isInstructing {
            latency.end()
            answerNotice = message
            controller.log("Instruction failed: \(message)")
            liveMode.instructionEnded(nil, answered: false)
            return
        }
        if let current = ahead, !current.delivered {
            // The answer made ahead failed: at the pause the turn is asked again the normal way.
            // T57 (Toby): unless the server's model is down (and the phone's own could not answer): then the turn
            // gets the same no at the pause, without asking the server once more.
            if let error = answers.lastError, OnDeviceReason(error) == .serverDown {
                aheadRefused = (error, Date())
            }
            ahead = nil
            controller.turns.setStatus(aheadTurnID, status: message, isQuestion: nil)
            controller.turns.finish(aheadTurnID, outcome: .failed, reason: "ahead; asked again at the pause")
            aheadTurnID = nil
            controller.log("Answer ahead failed: \(message)")
            return
        }
        // Toby 1 T17 finding 5: the answer made ahead was already delivered at the pause and then came back empty
        // (`empty_answer`, after 23 s): ask the turn once more the normal way instead of going quiet.
        if ahead?.delivered == true, case .backend(_, let failure)? = answers.lastError, failure.code == "empty_answer",
           let question = pendingQuestion, emptyRetried != question.query {
            emptyRetried = question.query
            ahead = nil
            controller.turns.finish(currentTurnID, outcome: .failed, reason: "empty answer ahead; asked again")
            controller.log("Answer ahead came back empty: asked again the normal way (T17)")
            repeatGuard.forget(question.query)
            activated(question)
            return
        }
        if ahead?.delivered == true { ahead = nil }
        // The flow: a question that got no answer is not a repeat when it is asked again (A74 counts answered ones).
        if let failed = pendingQuestion { repeatGuard.forget(failed.query) }
        liveMode.requestEnded() // D199 step 2: no suggestions are being made any more
        latency.end()
        conversation.cancelAnswer()
        answerNotice = nil // D86: the problem card says it in Swedish; the raw message is in Diagnostik's log
        controller.log("Answer failed: \(message)" + (wantsFallback ? " · fallback requested (on-device engine not available on this iPhone)" : ""))
        if let error = answers.lastError, error != .cancelled { recordFailure(source: "answer", detail: error.localizedDescription) }
        report(problem: Self.problem(for: answers.lastError))
        controller.turns.setStatus(currentTurnID, status: message, isQuestion: nil)
        controller.turns.finish(currentTurnID, outcome: .failed)
        studyAnswerEnded()
        standardMode.askWaitingQuestionIfIdle()
    }

    // MARK: - TranscriptSink (fed by TranscriptionCoordinator)

    func receivePartialTranscript(_ text: String, at date: Date = Date()) {
        conversation.updatePartial(text, at: date, overlapsPlayback: controller.playback.isSpeaking)
        if echo.isEcho(text, now: date) { return } // D82: Lumen's own voice
        if study.isActive { study.transcriptPartial(text) }
        guard !controller.playback.isSpeaking else { return }
        lastHeardAt = date
        if !text.isEmpty { activation.speechContinues(now: date) } // A21.2: a held half question waits for the rest
        standardMode.more.takeFromPartialIfStable(text)
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
        if !isListening, let stopped = listeningStoppedAt, date.timeIntervalSince(stopped) < 10 {
            controller.log("Words handed over after listening stopped: not used (A60)")
            return
        }
        if awaitingExamStatement, examAskedAloud, !segment.overlapsPlayback,
           Self.answersExamQuestion(segment.text, askedAt: examAskedAt, at: date) {
            // A33: the answer to the question Lumen asked aloud.
            stopListeningForExamStatement()
            discardAhead(reason: "the answer about an exam")
            study.discardTurnText()
            if ExamAnswer.isDecline(segment.text) {
                examQuestionDeclined = true
                say("Okej. Du kan lägga till ett prov på Start när du vill.")
            } else {
                profileStatement(ExamAnswer.statement(segment.text))
            }
            return
        }
        if awaitingExamStatement, ProfileStatement.isAboutSchool(segment.text) {
            awaitingExamStatement = false
            discardAhead(reason: "an exam said aloud")
            profileStatement(segment.text)
            return
        }
        if let identity = speakers?.identity(near: date, window: 4) { labelTranscript(identity, at: date) }
        if isOwnEcho(segment.text, at: date, startedAt: segment.startedAt, overlapsPlayback: segment.overlapsPlayback),
           !isWearerUsingSuggestion(segment.text, level: study.currentTurnLevelDBFS) {
            discardAhead(reason: "Lumen's own echo")
            return
        }
        // A24: the answer to "Vilket ämne i NO är provet i?".
        if awaitingSubject != nil, study.isActive, mode == .prov, !segment.overlapsPlayback, subjectAnswered(segment.text) {
            discardAhead(reason: "the exam's subject")
            study.discardTurnText()
            return
        }
        // A14: Scribe sometimes puts "Lumen." in a segment of its own; the command is the next segment.
        // Toby 1 T17c finding 9: "Hej, Lumen." alone is the name alone too.
        if WakeWord.matches(VoiceChannel.normalized(segment.text)) || VoiceChannel.isGreetedNameAlone(segment.text),
           !segment.overlapsPlayback {
            standardMode.nameAlone(at: date) // A75: "Ja?", then 8 s for the question (D199 step 5)
            return
        }
        if VoiceChannel.parse(segment.text).intent == nil, let miss = VoiceChannel.nearMissName(in: segment.text) {
            controller.log("Name-like word not taken: \(miss) (A75)") // grows WakeWord.variantsByName
        }
        // A75: the segment after "Ja?" is said to Lumen (D199 step 5).
        if standardMode.takesAfterName(segment.text, at: date) { return }
        // A15, A65: "ja" / "mer" in the "Mer?" window gets the long answer; "nej" or anything else closes it.
        if standardMode.more.takes(segment.text, at: date) { return }
        // A17: "igen" / "en gång till" / "va?" from the wearer: exactly the same answer again, within the time rules.
        switch AgainRule.judge(segment.text, lastAnswerAt: lastAnswerAt, now: date, isOtherVoice: isOtherVoice(near: date)) {
        case .repeatAnswer?:
            controller.log("Again: the last answer is repeated (A17)")
            discardAhead(reason: "igen")
            study.discardTurnText()
            tips.markUsed(.repeatAnswer)
            if mode == .prov || mode == .standard, paceSignals.repeated(at: date) { changePace(.slower, why: "two repeats in 10 min") }
            repeatLastAnswer()
            return
        case .notForLumen?:
            controller.log("'Igen' not for Lumen (time or voice, A17)")
        case nil:
            break
        }
        noteTask?.cancel() // A20.1: the student spoke, so the silence after the answer was not note-taking
        if !segment.overlapsPlayback, study.isActive, mode == .prov || mode == .standard, isOtherVoice(near: date) != true,
           let request = SpeechPace.request(segment.text), changePace(request, why: "asked") {
            discardAhead(reason: "a pace request")
            study.discardTurnText()
            return
        }
        if !segment.overlapsPlayback, study.isActive, mode == .prov, exam == nil, practice == nil, miniTest == nil,
           SilentQuiz.isStartCommand(segment.text) {
            discardAhead(reason: "silent quiz")
            study.discardTurnText()
            startSilentQuiz()
            return
        }
        if undoAppCommandIfAsked(segment.text, at: date) {
            discardAhead(reason: "an undo")
            study.discardTurnText()
            return
        }
        if !segment.overlapsPlayback, VoiceCommand.isMusicHandOff(segment.text) {
            controller.log("Spoken pause: handing the audio back")
            Task { await controller.pause() }
            return
        }
        if !segment.overlapsPlayback, let action = VoiceCommand.musicAction(segment.text) {
            controller.log("Voice: music \(action.rawValue) (unnamed)") // A14 / Toby T6 finding 8
            tips.markUsed(action)
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
            if study.phase != .listening, mode == .prov || mode == .standard, exam == nil, practice == nil, miniTest == nil,
               !study.isPartOfLastTurn(segment.text, at: date) {
                turnQueue.heardWhileAnswering(segment.text) // A21.1: never dropped because a turn is being answered
                return
            }
            // Provläge decides turns by silence, not by the question gate.
            study.transcriptFinal(segment.text, at: date)
            return
        }
        standardMode.heard(segment, at: date) // D199 step 5: the question gate at the pause
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

/// D199: what a mode's controller may use (`ListeningModeHost`). Nothing here touches the audio engine.
extension ListeningModel: ListeningModeHost {
    func modeLog(_ line: String) { controller.log(line) }
}

/// D199 step 2: what the live session uses (`LiveModeHost`): the model's own calls, unchanged.
extension ListeningModel: LiveModeHost {
    var vadIsRunning: Bool { transcription.vadIsRunning }
    var outputsToBuiltInSpeaker: Bool { controller.snapshot?.outputsToBuiltInSpeaker ?? false }
    var voiceIsSpeaking: Bool { speaker.isSpeaking }

    func sendLive(_ request: ActivationRequest, persona: PersonaRequest) {
        pendingQuestion = request
        latency.begin(request)
        answers.answer(request, context: AnswerContext(memories: memory.backendItems()), persona: persona)
    }

    func markLiveFirstText() { latency.markFirstText(provider: answers.activeProvider.name) }
    func showLiveActivity() { showActivity() }
    func speakLive(_ line: String) { speaker.enqueue(line, language: language) }
    func sayLive(_ line: String) { say(line) }
    func aheadStarted() { aheadStats.started += 1 }
    func aheadDiscarded() { aheadStats.discarded += 1 }
}

/// D199 step 5 (A120): what Frågor and the "Mer?" window use (`StandardModeHost`): the model's own calls, unchanged.
extension ListeningModel: StandardModeHost {
    var hasRunningExercise: Bool { exam != nil || practice != nil || miniTest != nil || silentQuiz != nil }
    var playbackIsSpeaking: Bool { controller.playback.isSpeaking }
    var hasPendingSpeech: Bool { speaker.hasPendingSpeech }
    var hasWaitingWords: Bool { transcription.hasWaitingWords }

    func commitWaitingWords() { transcription.commit() }
    func voice(in text: String, at date: Date) -> Bool { handleVoice(in: text, at: date) }
    func listeningEvent(_ event: ListeningEvent) { listeningEventObserver?(event, Date()) }
    func markMoreUsed() { tips.markUsed(.moreDetail) }
    func queueTurns(_ parts: [String]) { turnQueue.putFirst(parts) }

    func sayDeveloped(_ text: String, after last: AnswerTurn) {
        let turn = AnswerTurn(question: last.question, answer: text, source: "cloud", isOwnQuestion: last.isOwnQuestion)
        conversation.append(turn)
        lastAnswerAt = Date()
        history.record(HistoryEntry(createdAt: turn.createdAt, question: turn.isOwnQuestion ? turn.question : nil,
                                    answer: turn.answer, summary: nil, mode: mode.rawValue, persona: currentPersona))
        say(text)
    }

    func playMoreTone() {
        guard speaker.settings.moreTone else { return }
        try? controller.playback.playTestTone(frequency: 1_320, duration: 0.12)
    }
}

/// D199 step 6a (A121): what the exam session uses (`ExamSessionHost`): the model's own calls, unchanged.
extension ListeningModel: ExamSessionHost {
    func isSomeoneElseSpeakingNow() -> Bool {
        guard let speakers, speakers.profiles.isEnrolled else { return false }
        return speakers.identity(near: Date())?.isOther == true
    }

    func rememberToPractise(_ facts: [String]) {
        for fact in facts { memory.add(fact, kind: .fact, source: .automatic) }
        if !facts.isEmpty { refreshKeyterms() }
    }
}

/// D199 step 6b (A125): what the practice exam by voice uses (`PracticeExamHost`): the model's own calls, unchanged.
extension ListeningModel: PracticeExamHost {
    func recordConcept(_ topic: String, right: Bool) {
        conceptStats.record(topic, right: right)
        conceptStats.save()
        if let exam = currentExamID() { // A19: the study plan's history
            studyHistory.record(topic, ok: right, exam: exam)
            studyHistory.save()
        }
    }

    func rememberPractice(_ fact: String) {
        memory.add(fact, kind: .fact, source: .automatic)
    }
}

/// D199 step 6c (A126): what Provläge's controller and the mini test use (`ProvModeHost`, `MiniTestHost`): the
/// model's own calls, unchanged.
extension ListeningModel: ProvModeHost {
    func markQuizUsed() { tips.markUsed(.quizMe) }

    // D199 step 6e (A128): what the study plan uses (`StudyPlanHost`).
    var quizDayList: [String] { quizDays.days }
    var examOrTestIsRunning: Bool { exam != nil || practice != nil || miniTest != nil }
    var provSessionStart: Date? { provStartedAt }

    func refreshStreak() {
        streak = quizDays.streak()
        updateWidget() // A44
    }

    func planHistory(for examID: UUID) -> [String: [StudyHistory.Entry]] {
        studyHistory.history(for: examID)
    }

    func saveSummary(_ answer: String) {
        let profile = studyProfile.profile
        let title = "Sammanfattning: " + (profile.subject.isEmpty ? "Provläge" : profile.subject) + ", "
            + Date().formatted(.dateTime.day().month(.abbreviated))
        _ = studyCards?.add(question: title, answer: answer, profile: profile)
        saveNote()
    }

    func attach(_ link: LearningLink, to turn: AnswerTurn) {
        conversation.attach(link, to: turn.id)
        history.attachLink(link, at: turn.createdAt)
    }

    func endSessionNow() async {
        await endNow()
    }

    func markStudyCard(_ id: UUID, right: Bool) {
        studyCards?.mark(id, right: right)
    }

    func recordInStudyPlan(_ card: StudyCard, right: Bool) {
        guard let examID = currentExamID(), let plan = examPlans?.plans.first(where: { $0.id == examID }) else { return }
        studyHistory.record(FlipDeck.concept(for: card, topics: plan.topics), ok: right, exam: examID)
        studyHistory.save()
    }
}

/// D221 (A137, G7 step 7a): what the queue of split turns uses (`TurnQueueHost`): the model's own calls, unchanged.
extension ListeningModel: TurnQueueHost {
    func turnPersona() -> PersonaRequest? { mode == .prov ? tutorPersona() : nil }
    func turnAsked(_ text: String) { if mode == .prov { provMode.recordTurn(text) } }
}

/// D221 (A138, G7 step 7d): what the smaller parts use (`DebugAudioHost`, `PhoneToolsHost`, `PagePhotoHost`,
/// `FlipCardsHost`): the model's own calls, unchanged.
#if LUMEN_TESTMODE
extension ListeningModel: DebugAudioHost {} // A142: the test mode's part exists only with the flag
#endif

/// D233 (A151): what the search tone uses (`SearchToneHost`).
extension ListeningModel: SearchToneHost {
    var searchToneAllowed: Bool {
        let answering = if case .answering = answers.status { true } else { false }
        return SearchToneController.allowed(listening: isListening, mode: mode, instructing: liveMode.isInstructing,
                                            answering: answering, speaking: speaker.isSpeaking,
                                            trigger: pendingQuestion?.trigger,
                                            builtInSpeaker: controller.snapshot?.outputsToBuiltInSpeaker ?? false)
    }

    func playSearchTone() {
        try? controller.playback.playSearchTone()
    }
}

extension ListeningModel: PhoneToolsHost, PagePhotoHost, FlipCardsHost {
    var lastSentRequest: (request: ActivationRequest, persona: PersonaRequest?)? { lastSent }

    func recordFlippedConcept(_ concept: String, right: Bool, exam: UUID) {
        conceptStats.record(concept, right: right)
        conceptStats.save()
        studyHistory.record(concept, ok: right, exam: exam)
        studyHistory.save()
    }
}
