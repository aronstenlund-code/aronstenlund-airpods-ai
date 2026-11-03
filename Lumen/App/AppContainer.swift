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
    let sessionController: SessionController
    let transcription: TranscriptionCoordinator
    let listening: ListeningModel
    let diagnostics: DiagnosticsModel

    init() {
        let graph = AudioGraph()
        let session = AudioSessionManager()
        let capture = CaptureService(graph: graph)
        let playback = PlaybackService(graph: graph)
        let consent = ConsentStore()
        let language = LanguageSettings()
        let controller = SessionController(session: session, capture: capture, playback: playback, graph: graph)
        let transcription = TranscriptionCoordinator(controller: controller, language: language)
        let listening = ListeningModel(controller: controller, consent: consent, transcription: transcription)
        transcription.sink = listening
        self.graph = graph
        self.session = session
        self.capture = capture
        self.playback = playback
        self.consent = consent
        self.language = language
        self.sessionController = controller
        self.transcription = transcription
        self.listening = listening
        self.diagnostics = DiagnosticsModel(controller: controller)
    }
}
