import Foundation

/// Composition root. Concrete services are wired here; everything else sees protocols.
@MainActor
final class AppContainer {
    let graph: AudioGraph
    let session: AudioSessionManager
    /// The microphone, or (Debug, `LUMEN_AUDIO_FILES`) WAV files for Toby's Simulator tests.
    let capture: any CaptureServicing
    let playback: PlaybackService
    let consent: ConsentStore
    let language: LanguageSettings
    let activationSettings: ActivationSettings
    let voiceSettings: VoiceSettings
    let sessionController: SessionController
    let transcription: TranscriptionCoordinator
    let activation: ActivationController
    let auth: SupabaseAuth
    let answers: AnswerEngine
    let speaker: Speaker
    let voices: VoiceCatalog
    let share: ShareSettings
    let notes: NotesStore
    let prep: PrepStore
    let listening: ListeningModel
    let diagnostics: DiagnosticsModel
    /// D86: light/dark/follow the iPhone, handwriting for questions.
    let appearance = AppearanceSettings()
    /// D142 (A78): the shared AirPods buttons; the repetition takes them over while it plays.
    let remote: RemoteCommandHub
    /// D142 (A78): the repetition mode (no microphone).
    let repetition: RepetitionSession
    #if DEBUG
    /// Toby T27/T28: AirPods presses from a UI test (`LUMEN_TEST_PRESSES=1`), Debug only.
    var testPresses: TestPresses?
    #endif
    /// A145: the account was deleted; the app makes a new container (`AppHolder`). The text is K101's notice, if any.
    var onRestart: (@MainActor (String?) -> Void)?

    /// The mock mode of the repetition flow (`-RepetitionMock YES` and the screenshots): Debug only, never in the builds
    /// for testers or the App Store. A142: a property, not a constant in `init`. With `let mock = false` the first
    /// Release build ever (44264496532) stopped on "will never be executed" for every `mock ? … : …`.
    private static var isMockMode: Bool {
        #if DEBUG
        UserDefaults.standard.bool(forKey: "RepetitionMock") || ScreenshotStage.requested != nil
        #else
        false
        #endif
    }

    /// A145: this container is being replaced after the account was deleted. Its sign-in never runs again.
    func retire() {
        auth.retire()
    }

    init() {
        let graph = AudioGraph()
        let session = AudioSessionManager()
        #if DEBUG
        let capture: any CaptureServicing = FileCaptureService.fromEnvironment() ?? CaptureService(graph: graph)
        #else
        let capture: any CaptureServicing = CaptureService(graph: graph)
        #endif
        let playback = PlaybackService(graph: graph)
        let consent = ConsentStore()
        let language = LanguageSettings()
        let activationSettings = ActivationSettings()
        let voiceSettings = VoiceSettings()
        let controller = SessionController(session: session, capture: capture, playback: playback, graph: graph)
        let activation = ActivationController(settings: activationSettings)
        let http = URLSessionHTTP()
        let auth = SupabaseAuth(config: .lumen, store: KeychainSessionStore(), http: http)
        let transcription = TranscriptionCoordinator(controller: controller, language: language, settings: STTSettings(),
                                                     vad: VoiceActivityLoader(),
                                                     makeProvider: { locale, engine in
            switch engine {
            case .scribe:
                ScribeProvider(locale: locale, language: language.selected, config: .lumen, auth: auth, http: http)
            case .legacyOnDevice:
                LegacySpeechProvider(locale: locale)
            case .speechTranscriber, .dictationTranscriber:
                AppleSpeechProvider(locale: locale, engine: engine)
            }
        })
        let cloud = CloudAnswerProvider(config: .lumen, auth: auth, http: http)
        let answers = AnswerEngine(provider: cloud)
        answers.offline = OnDeviceAnswerProvider() // A40: only answers on iPhones with Apple Intelligence
        let speaker = Speaker(settings: voiceSettings,
                              apple: AppleTTSProvider(playback: playback),
                              premium: ElevenLabsTTSProvider(config: .lumen, auth: auth, http: http, playback: playback),
                              playback: playback)
        let voices = VoiceCatalog(config: .lumen, auth: auth, http: http)
        let share = ShareSettings()
        let notes = NotesStore()
        let prep = PrepStore()
        let remote = RemoteCommandHub()
        let listening = ListeningModel(controller: controller, consent: consent,
                                       transcription: transcription, activation: activation,
                                       answers: answers, speaker: speaker, voices: voices,
                                       notes: notes, prep: prep,
                                       warmer: BackendWarmer(config: .lumen, http: http),
                                       activity: ListeningActivityPresenter(),
                                       history: HistoryStore(), memory: MemoryStore(),
                                       feedback: FeedbackClient(config: .lumen, auth: auth, http: http, settings: share),
                                       remote: remote,
                                       memoryExtractor: MemoryExtractor(config: .lumen, auth: auth, http: http),
                                       speakers: SpeakerIdentifier(), studyCards: StudyCardStore(),
                                       studyCardsClient: StudyCardsClient(config: .lumen, auth: auth, http: http),
                                       studyProfileClient: StudyProfileClient(config: .lumen, auth: auth, http: http),
                                       examMaterials: ExamMaterials(), examClient: ExamClient(config: .lumen, auth: auth, http: http),
                                       examPlans: ExamPlanStore(), phrases: CommandPhraseStore(), music: MusicRemote.live(),
                                       tips: CommandTipStore(), preferences: PreferenceStore(),
                                       studyPlanClient: StudyPlanClient(config: .lumen, auth: auth, http: http))
        ListeningRemote.toggle = { [weak listening] in await listening?.togglePause() }
        ListeningRemote.nextSuggestion = { [weak listening] in listening?.nextSuggestion() }
        ListeningRemote.start = { [weak listening] in await listening?.startFromShortcut() }
        ListeningRemote.ask = { [weak listening] in await listening?.askFromShortcut() }
        ListeningRemote.startStudy = { [weak listening] in await listening?.startStudyFromShortcut() }
        ListeningRemote.quiz = { [weak listening] in await listening?.quizFromShortcut() } // A44
        // A48 (D122): calendar, reminders, timers, alarms and notes for the agent.
        listening.myAnswers = MyAnswerStore() // A53 (D126)
        listening.myAnswersClient = MyAnswersClient(config: .lumen, auth: auth, http: http)
        listening.logoVoteClient = LogoVoteClient(config: .lumen, auth: auth, http: http) // A54 (D127)
        #if LUMEN_TESTMODE
        listening.testMode = TestModeSettings() // A76 (D140): off unless switched on
        listening.debugAudioClient = DebugAudioClient(config: .lumen, auth: auth, http: http) // A76 (K43)
        #else
        TestModeBuild.removeLeftovers() // A142: the App Store build has no test mode and keeps none of its audio
        #endif
        listening.spotifyConnection = SpotifyConnection(client: ConnectClient(config: .lumen, auth: auth, http: http)) // A59
        listening.phoneTools = LivePhoneTools { [weak listening] text in listening?.notes.add(text: text) }
        ListeningRemote.pause = { [weak listening] in await listening?.pauseFromShortcut() }
        ListeningRemote.stop = { [weak listening] in await listening?.endSession() }
        transcription.sink = listening
        self.graph = graph
        self.session = session
        self.capture = capture
        self.playback = playback
        self.consent = consent
        self.language = language
        self.activationSettings = activationSettings
        self.voiceSettings = voiceSettings
        self.sessionController = controller
        self.transcription = transcription
        self.activation = activation
        self.auth = auth
        self.answers = answers
        self.speaker = speaker
        self.voices = voices
        self.share = share
        self.notes = notes
        self.prep = prep
        self.listening = listening
        self.remote = remote
        let repetitionSession = RepetitionSession(inputs: [AirPodsRepetitionInput(hub: remote)])
        self.repetition = repetitionSession
        // A79–A81 (D142): K45 for questions and answers, K46 for the exams per account and their ElevenLabs sound,
        // K47 for sharing. The mock mode (-RepetitionMock YES, Debug only: the Simulator tests and screenshots) uses
        // fixed questions, the phone only and the iPhone's own voice: 0 model calls and 0 ElevenLabs characters.
        let drillStore = DrillStore()
        let mock = Self.isMockMode
        // A143 (D225 point 4): the sign-in starts when the app opens, and the token is renewed when the app comes back,
        // so Spela never waits for it. Not in the mock mode (no network there) and not in the unit tests' host app.
        if !mock, ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil {
            auth.prepare()
            auth.watchForeground()
        }
        let drillCloud: (any DrillCloudSyncing)? = mock ? nil : DrillCloudClient(config: .lumen, auth: auth, http: http) as any DrillCloudSyncing
        let maker: any DrillMaking = mock ? MockDrillMaker() as any DrillMaking
            : DrillClient(config: .lumen, auth: auth, http: http) as any DrillMaking
        let drillAudio: any DrillAudioProviding
        if let drillCloud {
            drillAudio = CloudDrillAudio(cloud: drillCloud, store: drillStore)
        } else {
            #if DEBUG
            let makesSound = ScreenshotStage.requested == nil // the screenshots write their own silent files
            #else
            let makesSound = true
            #endif
            drillAudio = DeviceVoiceDrillAudio(makesSound: makesSound)
        }
        let repetitionModel = RepetitionModel(store: drillStore, session: repetitionSession, maker: maker,
                                              audio: drillAudio, sharing: DrillShareClient(cloud: drillCloud),
                                              remote: remote, cloud: drillCloud)
        repetitionModel.profile = listening.studyProfile // A88
        repetitionModel.publishing = drillCloud as? DrillCloudClient // A83 (K49)
        repetitionModel.help = mock ? MockHelp() as any HelpAnswering
            : HelpClient(config: .lumen, auth: auth, http: http) as any HelpAnswering // A92 (K57)
        if let drillCloud { // A134 (D218, K94), A141 (K98): purchases, welcome credits and invitations
            let shop = CreditShop(front: AppStoreFront(), server: PurchaseClient(config: .lumen, auth: auth, http: http))
            shop.accountID = { await drillCloud.accountID() }
            shop.onWalletChanged = { [weak repetitionModel] in await repetitionModel?.refreshQuota() }
            repetitionModel.shop = shop
        }
        repetitionModel.stopListening = { [weak listening] in
            if listening?.isActiveSession == true { await listening?.endSession() }
        }
        listening.repetition = repetitionModel
        // A145 (Ke78, K101): Radera konto. The server first; then everything stops, the phone forgets the account,
        // and the app starts as new.
        let deletion = AccountDeletionModel(client: AccountClient(config: .lumen, auth: auth, http: http),
                                            wipe: { _ = LocalWipe.live().run() },
                                            stopEverything: { [weak listening, weak repetitionModel] in
            if listening?.isActiveSession == true { await listening?.endSession() }
            repetitionModel?.end()
        })
        listening.accountDeletion = deletion
        repetitionModel.watchForeground() // K87: back in the app, the sound that is missing is asked for again
        // A108 (D194): a tap on the practice reminder opens the latest exam on Start.
        LumenNotifications.openDrill = { [weak repetitionModel] id in repetitionModel?.openDrill = id }
        repetitionModel.reminders = LivePracticeReminders() // also in the mock mode, for Toby's T30
        // T24-M1 (D189): one list of exams. Provläge and Mina svar see every repetition exam, also after a restart.
        if let plans = listening.examPlans {
            plans.sync(with: drillStore.drills)
            drillStore.onChange = { [weak plans] drills in plans?.sync(with: drills) }
        }
        self.diagnostics = DiagnosticsModel(controller: controller)
        diagnostics.micComparison = MicComparisonModel(listening: listening)
        diagnostics.speechRecording = SpeechRecordingModel(listening: listening)
        diagnostics.studyRecording = StudyRecordingModel(listening: listening)
        listening.accountDeletion?.onDeleted = { [weak self] notice in self?.onRestart?(notice) }
        #if DEBUG
        if let shot = ScreenshotStage.requested { ScreenshotStage.seed(self, for: shot) } // A2: demo data, Simulator only
        testPresses = TestPresses(session: repetitionSession)
        #endif
    }
}
