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
        let speaker = Speaker(settings: voiceSettings,
                              apple: AppleTTSProvider(playback: playback),
                              premium: ElevenLabsTTSProvider(config: .lumen, auth: auth, http: http, playback: playback),
                              playback: playback)
        let voices = VoiceCatalog(config: .lumen, auth: auth, http: http)
        let share = ShareSettings()
        let notes = NotesStore()
        let prep = PrepStore()
        let listening = ListeningModel(controller: controller, consent: consent,
                                       transcription: transcription, activation: activation,
                                       answers: answers, speaker: speaker, voices: voices,
                                       notes: notes, prep: prep,
                                       warmer: BackendWarmer(config: .lumen, http: http),
                                       activity: ListeningActivityPresenter(),
                                       history: HistoryStore(), memory: MemoryStore(),
                                       feedback: FeedbackClient(config: .lumen, auth: auth, http: http, settings: share),
                                       remote: RemoteCommandHub(),
                                       memoryExtractor: MemoryExtractor(config: .lumen, auth: auth, http: http),
                                       speakers: SpeakerIdentifier(), studyCards: StudyCardStore(),
                                       studyCardsClient: StudyCardsClient(config: .lumen, auth: auth, http: http),
                                       studyProfileClient: StudyProfileClient(config: .lumen, auth: auth, http: http),
                                       examMaterials: ExamMaterials(), examClient: ExamClient(config: .lumen, auth: auth, http: http),
                                       examPlans: ExamPlanStore())
        ListeningRemote.toggle = { [weak listening] in await listening?.togglePause() }
        ListeningRemote.nextSuggestion = { [weak listening] in listening?.nextSuggestion() }
        ListeningRemote.start = { [weak listening] in await listening?.startFromShortcut() }
        ListeningRemote.ask = { [weak listening] in await listening?.askFromShortcut() }
        ListeningRemote.startStudy = { [weak listening] in await listening?.startStudyFromShortcut() }
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
        self.diagnostics = DiagnosticsModel(controller: controller)
        diagnostics.micComparison = MicComparisonModel(listening: listening)
        diagnostics.speechRecording = SpeechRecordingModel(listening: listening)
        diagnostics.studyRecording = StudyRecordingModel(listening: listening)
        #if DEBUG
        if let shot = ScreenshotStage.requested { ScreenshotStage.seed(self, for: shot) } // A2: demo data, Simulator only
        #endif
    }
}
