import Foundation

/// Composition root. Concrete services are wired here; everything else sees protocols.
@MainActor
final class AppContainer {
    let graph: AudioGraph
    let session: AudioSessionManager
    let capture: CaptureService
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
    let notes: NotesStore
    let prep: PrepStore
    let listening: ListeningModel
    let diagnostics: DiagnosticsModel

    init() {
        let graph = AudioGraph()
        let session = AudioSessionManager()
        let capture = CaptureService(graph: graph)
        let playback = PlaybackService(graph: graph)
        let consent = ConsentStore()
        let language = LanguageSettings()
        let activationSettings = ActivationSettings()
        let voiceSettings = VoiceSettings()
        let controller = SessionController(session: session, capture: capture, playback: playback, graph: graph)
        let transcription = TranscriptionCoordinator(controller: controller, language: language)
        let activation = ActivationController(settings: activationSettings)
        let http = URLSessionHTTP()
        let auth = SupabaseAuth(config: .lumen, store: KeychainSessionStore(), http: http)
        let cloud = CloudAnswerProvider(config: .lumen, auth: auth, http: http)
        let answers = AnswerEngine(provider: cloud)
        let speaker = Speaker(settings: voiceSettings,
                              apple: AppleTTSProvider(playback: playback),
                              premium: ElevenLabsTTSProvider(config: .lumen, auth: auth, http: http, playback: playback),
                              playback: playback)
        let voices = VoiceCatalog(config: .lumen, auth: auth, http: http)
        let notes = NotesStore()
        let prep = PrepStore()
        let listening = ListeningModel(controller: controller, consent: consent,
                                       transcription: transcription, activation: activation,
                                       answers: answers, speaker: speaker, voices: voices,
                                       notes: notes, prep: prep)
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
        self.notes = notes
        self.prep = prep
        self.listening = listening
        self.diagnostics = DiagnosticsModel(controller: controller)
    }
}
