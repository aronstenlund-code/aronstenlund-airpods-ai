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

/// Drives the Diagnostics screen. The session state machine lives in `SessionController` (shared with the
/// Listening screen); this model adds the Phase 1 measurement tools. No business logic in views.
@MainActor
@Observable
final class DiagnosticsModel {
    typealias LogEntry = SessionController.LogEntry

    let controller: SessionController

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

    // Forwarded from the shared controller so the view and ResultsMarkdown read one object.
    var selectedConfig: CaptureConfig {
        get { controller.config }
        set { controller.config = newValue }
    }
    var state: SessionState { controller.state }
    var lastError: String? { controller.lastError }
    var eventLog: [LogEntry] { controller.eventLog }
    var chunkCount: Int { controller.chunkCount }
    var lastChunkFrames: Int { controller.lastChunkFrames }
    var formatChanges: [String] { controller.formatChanges }
    var session: any AudioSessionManaging { controller.session }
    var capture: any CaptureServicing { controller.capture }
    var playback: any PlaybackServicing { controller.playback }
    var snapshot: SessionSnapshot? { controller.snapshot }
    var banner: String { controller.banner }
    var level: AudioLevel.Reading { controller.level }
    var isCapturing: Bool { controller.isCapturing }
    var canResume: Bool { controller.canResume }
    var latencySamplesMs: [Double] { playback.latencySamplesMs }
    var medianLatencyMs: Double? {
        let sorted = playback.latencySamplesMs.sorted()
        return sorted.isEmpty ? nil : sorted[sorted.count / 2]
    }

    init(controller: SessionController) {
        self.controller = controller
    }

    // MARK: - User actions

    func startCapture() async { await controller.start() }
    func stopCapture() async { await controller.stop() }
    func resume() async { await controller.resume() }

    // MARK: - Playback

    func playTestTone() async {
        do {
            try await controller.ensureSessionForPlayback()
            try playback.playTestTone(frequency: 440, duration: 0.6)
            log("Test tone requested")
        } catch {
            controller.fail(error)
        }
    }

    func speakTestPhrase(_ language: TestPhraseLanguage) async {
        do {
            try await controller.ensureSessionForPlayback()
            log("Speak \(language.code)")
            try await playback.speak(language.phrase, language: language.code)
        } catch {
            controller.fail(error)
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
            controller.fail(error)
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
        controller.log(text)
    }
}
