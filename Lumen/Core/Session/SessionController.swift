import AVFAudio
import Foundation
import Observation
import UIKit

/// Owns the one capture/playback session of the app: the Phase 1 state machine (`SessionReducer`) plus the
/// side effects on the audio services. Both the Listening screen and Diagnostics observe this single object,
/// so there is exactly one owner of the microphone and one place that decides when it is live.
@MainActor
@Observable
final class SessionController {
    struct LogEntry: Identifiable, Sendable {
        let id = UUID()
        var time: Date
        var text: String
    }

    /// Capture configuration used by the next start (owner decision: B-HQ where available, HFP fallback).
    var config: CaptureConfig = .bHQ
    private(set) var state: SessionState = .idle
    private(set) var lastError: String?
    private(set) var eventLog: [LogEntry] = []
    private(set) var chunkCount = 0
    private(set) var lastChunkFrames = 0
    private(set) var formatChanges: [String] = []

    let session: any AudioSessionManaging
    let capture: any CaptureServicing
    let playback: any PlaybackServicing
    let graph: AudioGraph
    /// Injected so unit tests can run without a foreground UIApplication.
    private let isForeground: @MainActor () -> Bool
    private var chunkTask: Task<Void, Never>?
    /// Fan-out of the capture stream (`AsyncStream` has one consumer): STT and later the question gate subscribe here.
    private var chunkSinks: [UUID: AsyncStream<AudioChunk>.Continuation] = [:]

    /// Called after capture (re)starts — the microphone is live and chunks flow.
    var onCaptureStarted: (@MainActor () -> Void)?
    /// Called whenever capture stops, pauses or the engine is rebuilt.
    var onCaptureStopped: (@MainActor () -> Void)?
    /// Called on every state transition.
    var onStateChanged: (@MainActor (SessionState) -> Void)?

    var snapshot: SessionSnapshot? { session.snapshot }
    var banner: String { session.snapshot?.banner ?? "No active session" }
    var level: AudioLevel.Reading { capture.level }
    var isCapturing: Bool { capture.isCapturing }
    /// The microphone is live or will be live again without a new consent step.
    var isActiveSession: Bool {
        switch state {
        case .listening, .paused: true
        case .idle, .error: false
        }
    }
    /// Always while paused: a music app's interruption may never end, and the user decides (D33).
    var canResume: Bool {
        if case .paused = state { return true }
        return false
    }

    init(session: any AudioSessionManaging,
         capture: any CaptureServicing,
         playback: any PlaybackServicing,
         graph: AudioGraph,
         isForeground: @escaping @MainActor () -> Bool = { UIApplication.shared.applicationState == .active }) {
        self.session = session
        self.capture = capture
        self.playback = playback
        self.graph = graph
        self.isForeground = isForeground

        session.eventHandler = { [weak self] event in self?.handleSessionEvent(event) }
        capture.onFormatChange = { [weak self] change in
            self?.formatChanges.append(change)
            self?.log("Input format changed: \(change)")
        }
        capture.onError = { [weak self] error in self?.fail(error) }
    }

    // MARK: - User actions

    func start() async { await apply(.userStart) }
    func stop() async { await apply(.userStop) }
    func resume() async { await apply(.userResume) }
    func pause() async { await apply(.userPause) }

    // MARK: - State machine

    func apply(_ event: SessionEvent) async {
        let (newState, effect) = SessionReducer.reduce(state, event)
        if newState != state {
            log("State \(state.label) → \(newState.label)")
            state = newState
            onStateChanged?(newState)
        }
        if let effect {
            await perform(effect)
        }
    }

    private func perform(_ effect: SessionEffect) async {
        switch effect {
        case .startCapture:
            await beginCapture()
        case .resumeCapture:
            await resumeCapture()
        case .pauseCapture:
            chunkTask?.cancel()
            capture.stop()
            playback.stop()
            onCaptureStopped?()
        case .stopCapture:
            chunkTask?.cancel()
            capture.stop()
            playback.stop()
            session.deactivate()
            onCaptureStopped?()
        case .rebuildAudioGraph:
            chunkTask?.cancel()
            capture.stop()
            playback.stop()
            graph.rebuild()
            log("Audio engine rebuilt after media services reset")
            onCaptureStopped?()
        }
    }

    private func beginCapture() async {
        lastError = nil
        // Phase 1 §3.5: capture is started only by an explicit user tap in the foreground.
        guard isForeground() else {
            await apply(.failed("Capture must be started from the foreground"))
            return
        }
        guard await session.requestMicrophonePermission() else {
            await apply(.failed(AudioError.permissionDenied.localizedDescription))
            return
        }
        do {
            let snapshot = try await session.activate(config)
            log("Session active: \(snapshot.banner)")
            try capture.start()
            _ = session.refreshSnapshot(engineInputFormat: capture.inputFormatDescription)
            startChunkCounter()
            log("Capture started · engine input \(capture.inputFormatDescription ?? "?")")
            onCaptureStarted?()
            await apply(.captureStarted)
        } catch {
            await apply(.failed(error.localizedDescription))
        }
    }

    private func resumeCapture() async {
        lastError = nil
        do {
            // A user pause released the session; after an interruption it only needs reactivating.
            if session.activeConfig == nil {
                _ = try await session.activate(config)
            } else {
                try session.reactivate()
            }
            try capture.start()
            _ = session.refreshSnapshot(engineInputFormat: capture.inputFormatDescription)
            startChunkCounter()
            log("Capture resumed: \(banner)")
            onCaptureStarted?()
        } catch {
            fail(error)
            await apply(.resumeFailed)
        }
    }

    private func startChunkCounter() {
        chunkTask?.cancel()
        chunkCount = 0
        lastChunkFrames = 0
        guard let stream = capture.chunks else { return }
        chunkTask = Task { [weak self] in
            for await chunk in stream {
                guard let self else { return }
                self.chunkCount += 1
                self.lastChunkFrames = chunk.frameCount
                for sink in self.chunkSinks.values {
                    sink.yield(chunk)
                }
            }
        }
    }

    // MARK: - Chunk subscribers

    /// A copy of every chunk from now on, across pauses and restarts, until `unsubscribeFromChunks`.
    func subscribeToChunks() -> (id: UUID, stream: AsyncStream<AudioChunk>) {
        let (stream, continuation) = AsyncStream<AudioChunk>.makeStream(bufferingPolicy: .bufferingNewest(256))
        let id = UUID()
        chunkSinks[id] = continuation
        return (id, stream)
    }

    func unsubscribeFromChunks(_ id: UUID) {
        chunkSinks.removeValue(forKey: id)?.finish()
    }

    // MARK: - Session events

    private func handleSessionEvent(_ event: AudioSessionEvent) {
        switch event {
        case .activated(let snapshot):
            log("Activated → \(snapshot.banner)")
        case .routeSettled(let snapshot):
            log("Route 1 s after activation → \(snapshot.banner) · \(snapshot.hq.summary)")
        case .interruptionBegan(let reason):
            log("Interruption began (\(reason))")
            Task { await apply(.interruptionBegan) }
        case .interruptionEnded(let shouldResume):
            log("Interruption ended · shouldResume=\(shouldResume)")
            Task { await apply(.interruptionEnded(shouldResume: shouldResume)) }
        case .routeChanged(let reason, let outputLost, let snapshot):
            log("Route change \(reason) → \(snapshot.banner)")
            if outputLost {
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                Task { await apply(.outputDeviceLost) }
            } else if case .paused(.outputDeviceLost) = state, reason == "newDeviceAvailable" {
                Task { await apply(.outputDeviceRestored) }
            }
        case .mediaServicesReset:
            log("Media services were reset")
            Task { await apply(.mediaServicesReset) }
        case .warning(let text):
            log("Warning: \(text)")
        }
    }

    // MARK: - Playback helpers

    /// Activates the session with the selected config if nothing is active yet (test tone / TTS without capture).
    func ensureSessionForPlayback() async throws(AudioError) {
        if session.activeConfig == nil {
            _ = try await session.activate(config)
            log("Session activated for playback: \(banner)")
        }
    }

    // MARK: - Logging

    func log(_ text: String) {
        eventLog.insert(LogEntry(time: Date(), text: text), at: 0)
        if eventLog.count > 500 { eventLog.removeLast(eventLog.count - 500) }
        Log.diagnostics.info("\(text, privacy: .public)")
    }

    func fail(_ error: AudioError) {
        lastError = error.localizedDescription
        log("Error: \(error.localizedDescription)")
        Log.diagnostics.error("\(error.localizedDescription, privacy: .public)")
    }
}
