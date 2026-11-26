import AVFoundation
import Foundation
import Observation

enum OwnRecordingError: Error, Equatable, Sendable {
    /// The user has said no to the microphone.
    case microphoneDenied
    case failed(String)
}

/// A164 (D263): records the user's own voice to a file on the phone. Behind a protocol so the tests can put a
/// pretend recorder in its place; the microphone itself is verified on a phone.
@MainActor
protocol OwnRecording: AnyObject {
    /// While it records: how long it has gone on, and how loud it is (for the level mark).
    var elapsed: TimeInterval { get }
    var levelDBFS: Double? { get }
    /// The recording reached its limit and stopped by itself.
    var onLimit: (@MainActor () -> Void)? { get set }
    /// The kind of file it writes (`m4a`), so the file is named for what is in it.
    var fileExtension: String { get }
    /// Asks for the microphone the first time, then records to `url`.
    func start(to url: URL) async throws(OwnRecordingError)
    /// Stops and keeps the file. The seconds recorded; nil when nothing was being recorded.
    func stop() -> TimeInterval?
    /// Stops and deletes the file.
    func cancel()
}

extension OwnRecording {
    /// The phone's recorder writes AAC in an m4a file; another recorder says its own.
    var fileExtension: String { "m4a" }
}

/// The phone's recorder. The AirPods microphone when AirPods are connected, otherwise the phone's own: the session
/// allows Bluetooth hands-free input, and iOS then takes the connected headset's microphone. (The recorder for "Mitt
/// svar", `AnswerRecorder`, uses the plain record session, which never offers the AirPods microphone.) AAC in an m4a
/// file. Nothing is sent anywhere.
@MainActor
@Observable
final class OwnRecorder: OwnRecording {
    private(set) var elapsed: TimeInterval = 0
    private(set) var levelDBFS: Double?
    @ObservationIgnored var onLimit: (@MainActor () -> Void)?
    let fileExtension = "m4a"
    @ObservationIgnored private let limit: TimeInterval
    @ObservationIgnored private var recorder: AVAudioRecorder?
    @ObservationIgnored private var ticker: Task<Void, Never>?

    init(limit: TimeInterval = OwnDeckModel.recordingLimit) {
        self.limit = limit
    }

    func start(to url: URL) async throws(OwnRecordingError) {
        guard await AudioSessionPermission.microphone() else { throw .microphoneDenied }
        end(deleting: true)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.allowBluetoothHFP, .defaultToSpeaker])
            try session.setActive(true)
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            ]
            let recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder.isMeteringEnabled = true
            guard recorder.record(forDuration: limit) else {
                throw OwnRecordingError.failed("the recorder did not start")
            }
            self.recorder = recorder
        } catch {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            throw .failed(String(describing: error))
        }
        elapsed = 0
        levelDBFS = nil
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(200))
                guard let self, let recorder = self.recorder else { return }
                guard recorder.isRecording else {
                    self.onLimit?() // the limit was reached: the one who asked for the recording keeps it
                    return
                }
                recorder.updateMeters()
                self.elapsed = recorder.currentTime
                self.levelDBFS = Double(recorder.averagePower(forChannel: 0))
            }
        }
    }

    func stop() -> TimeInterval? {
        guard let recorder else { return nil }
        let seconds = recorder.isRecording ? recorder.currentTime : max(elapsed, limit)
        end(deleting: false)
        return seconds
    }

    func cancel() {
        end(deleting: true)
    }

    private func end(deleting: Bool) {
        ticker?.cancel()
        ticker = nil
        guard let recorder else { return }
        recorder.stop()
        if deleting { recorder.deleteRecording() }
        self.recorder = nil
        levelDBFS = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

#if LUMEN_TESTMODE
/// T58 (Toby): a pretend recorder for the Simulator, which has no microphone in CI. `-FakeOwnRecorder 1` at launch:
/// "recording" writes two seconds of silence at once, without asking for the microphone, and stopping keeps it as
/// usual, so create → record → practise can be tried. Only in the test builds (Debug and Beta), never in Release.
@MainActor
@Observable
final class PretendOwnRecorder: OwnRecording {
    static let argument = "FakeOwnRecorder"
    nonisolated static let seconds: TimeInterval = 2

    static func isRequested(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: argument)
    }

    private(set) var elapsed: TimeInterval = 0
    private(set) var levelDBFS: Double?
    @ObservationIgnored var onLimit: (@MainActor () -> Void)?
    let fileExtension = "wav"
    @ObservationIgnored private var target: URL?

    func start(to url: URL) async throws(OwnRecordingError) {
        do {
            try WAVWriter.write(samples: [Int16](repeating: 0, count: Int(Self.seconds) * 16_000), sampleRate: 16_000, to: url)
        } catch {
            throw .failed(String(describing: error))
        }
        target = url
        elapsed = Self.seconds
        levelDBFS = -30
    }

    func stop() -> TimeInterval? {
        guard target != nil else { return nil }
        target = nil
        levelDBFS = nil
        return Self.seconds
    }

    func cancel() {
        if let target { try? FileManager.default.removeItem(at: target) }
        target = nil
        levelDBFS = nil
    }
}
#endif
