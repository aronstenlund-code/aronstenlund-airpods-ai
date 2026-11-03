import Foundation

/// Composition root. Concrete services are wired here; everything else sees protocols.
@MainActor
final class AppContainer {
    let graph: AudioGraph
    let session: AudioSessionManager
    let capture: CaptureService
    let playback: PlaybackService
    let consent: ConsentStore
    let sessionController: SessionController
    let listening: ListeningModel
    let diagnostics: DiagnosticsModel

    init() {
        let graph = AudioGraph()
        let session = AudioSessionManager()
        let capture = CaptureService(graph: graph)
        let playback = PlaybackService(graph: graph)
        let consent = ConsentStore()
        let controller = SessionController(session: session, capture: capture, playback: playback, graph: graph)
        self.graph = graph
        self.session = session
        self.capture = capture
        self.playback = playback
        self.consent = consent
        self.sessionController = controller
        self.listening = ListeningModel(controller: controller, consent: consent)
        self.diagnostics = DiagnosticsModel(controller: controller)
    }
}
