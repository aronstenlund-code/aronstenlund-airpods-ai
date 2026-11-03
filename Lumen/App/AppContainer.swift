import Foundation

/// Composition root. Concrete services are wired here; everything else sees protocols.
@MainActor
final class AppContainer {
    let graph: AudioGraph
    let session: AudioSessionManager
    let capture: CaptureService
    let playback: PlaybackService
    let diagnostics: DiagnosticsModel

    init() {
        let graph = AudioGraph()
        let session = AudioSessionManager()
        let capture = CaptureService(graph: graph)
        let playback = PlaybackService(graph: graph)
        self.graph = graph
        self.session = session
        self.capture = capture
        self.playback = playback
        self.diagnostics = DiagnosticsModel(session: session, capture: capture, playback: playback, graph: graph)
    }
}
