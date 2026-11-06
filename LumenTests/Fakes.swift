import AVFAudio
import Foundation
@testable import Lumen

/// In-memory stand-ins for the audio services so the session state machine and the Listening model can be
/// tested without a microphone. Every call is counted so tests can assert the side effects.
@MainActor
final class FakeSessionManager: AudioSessionManaging {
    var snapshot: SessionSnapshot?
    var activeConfig: CaptureConfig?
    var eventHandler: (@MainActor (AudioSessionEvent) -> Void)?

    var permissionGranted = true
    var activationError: AudioError?
    var permissionRequests = 0
    var activateCalls: [CaptureConfig] = []
    var reactivateCalls = 0
    var deactivateCalls = 0

    func requestMicrophonePermission() async -> Bool {
        permissionRequests += 1
        return permissionGranted
    }

    func activate(_ config: CaptureConfig) async throws(AudioError) -> SessionSnapshot {
        if let activationError { throw activationError }
        activateCalls.append(config)
        activeConfig = config
        let snapshot = Self.makeSnapshot(config: config)
        self.snapshot = snapshot
        return snapshot
    }

    func reactivate() throws(AudioError) {
        reactivateCalls += 1
    }

    func deactivate() {
        deactivateCalls += 1
        activeConfig = nil
        snapshot = nil
    }

    func refreshSnapshot(engineInputFormat: String?) -> SessionSnapshot {
        var updated = snapshot ?? Self.makeSnapshot(config: activeConfig ?? .bHQ)
        updated.engineInputFormat = engineInputFormat
        snapshot = updated
        return updated
    }

    static func makeSnapshot(config: CaptureConfig) -> SessionSnapshot {
        SessionSnapshot(timestamp: Date(timeIntervalSince1970: 0), config: config,
                        category: "AVAudioSessionCategoryPlayAndRecord", mode: "AVAudioSessionModeDefault",
                        options: ["allowBluetoothHFP"],
                        inputs: [PortInfo(portType: "BluetoothHFP", portName: "AirPods Pro", uid: "u", channelCount: 1, dataSource: nil)],
                        outputs: [PortInfo(portType: "BluetoothHFP", portName: "AirPods Pro", uid: "u", channelCount: 1, dataSource: nil)],
                        sampleRate: 16_000, ioBufferDuration: 0.02, inputChannels: 1, outputChannels: 1,
                        inputLatency: 0.01, outputLatency: 0.02, hq: .unavailable, preferredInputSucceeded: true,
                        engineInputFormat: nil, region: "SE", osVersion: "Version 26.5")
    }
}

@MainActor
final class FakeCaptureService: CaptureServicing {
    private(set) var isCapturing = false
    var level: AudioLevel.Reading = .silence
    var chunks: AsyncStream<AudioChunk>?
    let ringBuffer = Int16RingBuffer(capacity: 16_000)
    var inputFormatDescription: String? = "16000 Hz · 1 ch · Int16"
    var conversionErrorCount = 0
    var onFormatChange: (@MainActor (String) -> Void)?
    var onError: (@MainActor (AudioError) -> Void)?

    var startError: AudioError?
    var startCalls = 0
    var stopCalls = 0

    func start() throws(AudioError) {
        if let startError { throw startError }
        startCalls += 1
        isCapturing = true
    }

    func stop() {
        stopCalls += 1
        isCapturing = false
    }

    func exportLast(seconds: Double) throws(AudioError) -> URL {
        throw .export(detail: "not available in tests")
    }

    func exportSamples(_ samples: [Int16], name: String) throws(AudioError) -> URL {
        throw .export(detail: "not available in tests")
    }
}

@MainActor
final class FakePlaybackService: PlaybackServicing {
    var rate: Float = 1.0
    var latencySamplesMs: [Double] = []
    var isSpeaking = false
    var stopCalls = 0
    var spoken: [String] = []
    var spokenVoices: [String?] = []
    var played: [[Int16]] = []
    var playedSampleRates: [Double] = []
    var speakError: AudioError?
    var onAudioScheduled: (@MainActor () -> Void)?
    var speechVolume: Float = 1

    func playTestTone(frequency: Double, duration: Double) throws(AudioError) {}

    func speak(_ text: String, language: String, voiceIdentifier: String?) async throws(AudioError) {
        if let speakError { throw speakError }
        spoken.append(text)
        spokenVoices.append(voiceIdentifier)
    }

    func play(samples: [Int16], sampleRate: Double) throws(AudioError) {
        played.append(samples)
        playedSampleRates.append(sampleRate)
    }

    func stop() {
        stopCalls += 1
        isSpeaking = false
    }

    func clearLatencySamples() {
        latencySamplesMs.removeAll()
    }
}

@MainActor
final class FakeConsentStore: ConsentStoring {
    var record: ConsentRecord?
    var isGranted: Bool { record != nil }
    var revokeCalls = 0

    init(granted: Bool) {
        record = granted ? ConsentRecord(version: ConsentPolicy.currentVersion, grantedAt: Date(timeIntervalSince1970: 0)) : nil
    }

    func grant() {
        record = ConsentRecord(version: ConsentPolicy.currentVersion, grantedAt: Date())
    }

    func revoke() {
        revokeCalls += 1
        record = nil
    }
}

/// Builds a controller around the fakes. `foreground` mirrors `UIApplication.applicationState == .active`.
@MainActor
struct ControllerHarness {
    let session = FakeSessionManager()
    let capture = FakeCaptureService()
    let playback = FakePlaybackService()
    let graph = AudioGraph()
    let controller: SessionController

    init(foreground: Bool = true) {
        controller = SessionController(session: session, capture: capture, playback: playback, graph: graph,
                                       isForeground: { foreground })
    }
}
