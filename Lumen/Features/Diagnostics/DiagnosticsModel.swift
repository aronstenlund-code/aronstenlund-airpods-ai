import AVFAudio
import Foundation
import Observation
import UIKit

enum TestPhraseLanguage: String, CaseIterable, Identifiable, Sendable {
    case swedish
    case english
    var id: String { rawValue }

    var code: String { self == .swedish ? "sv-SE" : "en-US" }
    var phrase: String {
        switch self {
        case .swedish: "Hej! Det här är ett test av ljudet i dina AirPods. Hör du mig tydligt?"
        case .english: "Hello! This is a test of the audio in your AirPods. Can you hear me clearly?"
        }
    }
}

/// Drives the Diagnostics screen. Owns the Phase 1 session state machine; no business logic in views.
@MainActor
@Observable
final class DiagnosticsModel {
    struct LogEntry: Identifiable, Sendable {
        let id = UUID()
        var time: Date
        var text: String
    }

    var selectedConfig: CaptureConfig = .bHQ
    private(set) var state: SessionState = .idle
    private(set) var lastError: String?
    private(set) var eventLog: [LogEntry] = []
    private(set) var chunkCount = 0
    private(set) var lastChunkFrames = 0
    private(set) var formatChanges: [String] = []
    var speakRate: Float = 1.0 {
        didSet { playback.rate = speakRate }
    }

    // Speaker-distance test
    var distanceMeters: Int = 1
    var noiseCondition: NoiseCondition = .quiet
    var speakerRole: SpeakerRole = .otherPerson
    private(set) var distanceRecording: DistanceRecordingInProgress?
    private(set) var distanceRuns: [DistanceTestRun] = []

    private(set) var micSourceResult: MicSourceTest.Result?
    private(set) var micSourceRunning = false
    private(set) var localeReport: String?
    private(set) var localeCheckRunning = false
    private(set) var lastExportURL: URL?
    private(set) var copiedAt: Date?

    let session: any AudioSessionManaging
    let capture: any CaptureServicing
    let playback: any PlaybackServicing
    private let graph: AudioGraph
    private var chunkTask: Task<Void, Never>?

    var snapshot: SessionSnapshot? { session.snapshot }
    var banner: String { session.snapshot?.banner ?? "No active session" }
    var level: AudioLevel.Reading { capture.level }
    var isCapturing: Bool { capture.isCapturing }
    var latencySamplesMs: [Double] { playback.latencySamplesMs }
    var medianLatencyMs: Double? {
        let sorted = playback.latencySamplesMs.sorted()
        return sorted.isEmpty ? nil : sorted[sorted.count / 2]
    }
    var canResume: Bool {
        if case .paused(let reason) = state { return reason != .interruption }
        return false
    }

    init(session: any AudioSessionManaging, capture: any CaptureServicing,
         playback: any PlaybackServicing, graph: AudioGraph) {
        self.session = session
        self.capture = capture
        self.playback = playback
        self.graph = graph

        session.eventHandler = { [weak self] event in self?.handleSessionEvent(event) }
        capture.onFormatChange = { [weak self] change in
            self?.formatChanges.append(change)
            self?.log("Input format changed: \(change)")
        }
        capture.onError = { [weak self] error in self?.fail(error) }
    }

    // MARK: - State machine

    func apply(_ event: SessionEvent) async {
        let (newState, effect) = SessionReducer.reduce(state, event)
        if newState != state {
            log("State \(state.label) → \(newState.label)")
            state = newState
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
            resumeCapture()
        case .pauseCapture:
            chunkTask?.cancel()
            capture.stop()
            playback.stop()
        case .stopCapture:
            chunkTask?.cancel()
            capture.stop()
            playback.stop()
            session.deactivate()
        case .rebuildAudioGraph:
            chunkTask?.cancel()
            capture.stop()
            playback.stop()
            graph.rebuild()
            log("Audio engine rebuilt after media services reset")
        }
    }

    private func beginCapture() async {
        lastError = nil
        // Phase 1 §3.5: capture is started only by an explicit user tap in the foreground.
        guard UIApplication.shared.applicationState == .active else {
            await apply(.failed("Capture must be started from the foreground"))
            return
        }
        guard await session.requestMicrophonePermission() else {
            await apply(.failed(AudioError.permissionDenied.localizedDescription))
            return
        }
        do {
            let snapshot = try await session.activate(selectedConfig)
            log("Session active: \(snapshot.banner)")
            try capture.start()
            _ = session.refreshSnapshot(engineInputFormat: capture.inputFormatDescription)
            startChunkCounter()
            log("Capture started · engine input \(capture.inputFormatDescription ?? "?")")
            await apply(.captureStarted)
        } catch {
            await apply(.failed(error.localizedDescription))
        }
    }

    private func resumeCapture() {
        do {
            try session.reactivate()
            try capture.start()
            _ = session.refreshSnapshot(engineInputFormat: capture.inputFormatDescription)
            startChunkCounter()
            log("Capture resumed: \(banner)")
        } catch {
            fail(error)
            Task { await apply(.failed(error.localizedDescription)) }
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
            }
        }
    }

    // MARK: - User actions

    func startCapture() async { await apply(.userStart) }
    func stopCapture() async { await apply(.userStop) }
    func resume() async { await apply(.userResume) }

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

    // MARK: - Playback

    private func ensureSessionForPlayback() async throws(AudioError) {
        if session.activeConfig == nil {
            _ = try await session.activate(selectedConfig)
            log("Session activated for playback: \(banner)")
        }
    }

    func playTestTone() async {
        do {
            try await ensureSessionForPlayback()
            try playback.playTestTone(frequency: 440, duration: 0.6)
            log("Test tone requested")
        } catch {
            fail(error)
        }
    }

    func speakTestPhrase(_ language: TestPhraseLanguage) async {
        do {
            try await ensureSessionForPlayback()
            log("Speak \(language.code)")
            try await playback.speak(language.phrase, language: language.code)
        } catch {
            fail(error)
        }
    }

    func stopPlayback() {
        playback.stop()
        log("Playback stopped")
    }

    func clearLatencySamples() {
        playback.clearLatencySamples()
    }

    // MARK: - Speaker-distance test

    func startDistanceRecording() {
        guard isCapturing else {
            log("Start capture before a distance run")
            return
        }
        distanceRecording = DistanceRecordingInProgress(startedAt: Date(),
                                                        startMark: capture.ringBuffer.totalWritten,
                                                        config: session.activeConfig ?? selectedConfig,
                                                        distanceMeters: distanceMeters,
                                                        noise: noiseCondition,
                                                        speaker: speakerRole)
        log("Distance run started · \(distanceMeters) m · \(noiseCondition.rawValue) · \(speakerRole.rawValue)")
    }

    func stopDistanceRecording() {
        guard let recording = distanceRecording else { return }
        distanceRecording = nil
        let samples = capture.ringBuffer.snapshot(since: recording.startMark)
        let snr = SNREstimator.estimate(samples)
        var url: URL?
        do {
            url = try capture.exportSamples(samples, name: recording.fileStem)
            lastExportURL = url
        } catch {
            log("WAV export failed: \(error.localizedDescription)")
        }
        let run = DistanceTestRun(time: Date(), config: recording.config, distanceMeters: recording.distanceMeters,
                                  noise: recording.noise, speaker: recording.speaker,
                                  durationSeconds: Double(samples.count) / LumenAudioFormat.sampleRate,
                                  snr: snr, wavURL: url, snapshot: session.snapshot)
        distanceRuns.append(run)
        log("Distance run saved · \(run.summaryLine)")
    }

    // MARK: - Mic-source sanity check

    func runMicSourceCheck() async {
        guard isCapturing else {
            log("Start capture before the mic-source check")
            return
        }
        micSourceRunning = true
        defer { micSourceRunning = false }
        let mark = capture.ringBuffer.totalWritten
        log("Mic-source check: tap the iPhone body 3 times within 5 s…")
        try? await Task.sleep(for: .seconds(5))
        let samples = capture.ringBuffer.snapshot(since: mark)
        let result = MicSourceTest.analyze(samples)
        micSourceResult = result
        log("Mic-source check: \(result.summary)")
    }

    // MARK: - Speech locales

    func checkSpeechLocales() async {
        localeCheckRunning = true
        defer { localeCheckRunning = false }
        let report = await SpeechLocaleCheck.run()
        localeReport = report
        log("Speech locale check finished")
    }

    // MARK: - Export / copy

    func exportLast60s() {
        do {
            let url = try capture.exportLast(seconds: 60)
            lastExportURL = url
            log("Exported \(url.lastPathComponent)")
        } catch {
            fail(error)
        }
    }

    var resultsMarkdown: String { ResultsMarkdown.render(self) }

    func copyResultsMarkdown() {
        UIPasteboard.general.string = resultsMarkdown
        copiedAt = Date()
        log("Results copied as Markdown")
    }

    // MARK: - Logging

    func log(_ text: String) {
        eventLog.insert(LogEntry(time: Date(), text: text), at: 0)
        if eventLog.count > 500 { eventLog.removeLast(eventLog.count - 500) }
        Log.diagnostics.info("\(text, privacy: .public)")
    }

    private func fail(_ error: AudioError) {
        lastError = error.localizedDescription
        log("Error: \(error.localizedDescription)")
        Log.diagnostics.error("\(error.localizedDescription, privacy: .public)")
    }
}
