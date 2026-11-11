@preconcurrency import AVFoundation
import Foundation
import Observation
@preconcurrency import Speech

/// A53 (D126): "Spela in ett svar". The microphone records to a file on the phone while the screen shows a red dot,
/// the time and a level meter (iOS also shows its own microphone indicator). Nothing is done with the audio until the
/// student taps Klar (D126); then the phone's own speech recognition writes it out (`requiresOnDeviceRecognition`,
/// as the sleep mode does, A49), the file is deleted, and only the text goes to `/my-answers compress`. No audio
/// leaves the phone and no Scribe credits are used (D120). At most `limit` (10 min, Kelly Ke30).
@MainActor
@Observable
final class AnswerRecorder {
    enum State: Equatable {
        case idle
        case recording
        /// Writing out the words on the phone.
        case transcribing
        case failed(String)
    }

    static let limit: TimeInterval = 10 * 60

    private(set) var state: State = .idle
    private(set) var elapsed: TimeInterval = 0
    /// −60…0 dBFS, for the meter.
    private(set) var levelDBFS: Double?
    @ObservationIgnored private var tap: RecorderTap?
    @ObservationIgnored private var startedAt: Date?
    @ObservationIgnored private var ticker: Task<Void, Never>?

    func start() async {
        guard state != .recording else { return }
        guard await AudioSessionPermission.microphone() else {
            state = .failed("Earmind får inte använda mikrofonen. Tillåt den i Inställningar.")
            return
        }
        // The words are written out by the phone's speech recognition, which iOS asks about once.
        guard await LegacySpeechProvider.requestAuthorization() == .authorized else {
            state = .failed("Earmind får inte använda taligenkänningen. Tillåt den i Inställningar.")
            return
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("mitt-svar-\(UUID().uuidString).caf")
        let tap = RecorderTap(url: url) { [weak self] level in
            Task { @MainActor in self?.levelDBFS = level }
        }
        do {
            try tap.start()
        } catch {
            tap.stop()
            try? FileManager.default.removeItem(at: url)
            state = .failed("Inspelningen kunde inte starta.")
            return
        }
        self.tap = tap
        startedAt = Date()
        elapsed = 0
        state = .recording
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(250))
                guard let self, let started = self.startedAt, self.state == .recording else { return }
                self.elapsed = Date().timeIntervalSince(started)
                if self.elapsed >= Self.limit { self.stopAtLimit() }
            }
        }
    }

    /// The limit stops the microphone; the text is made when the student taps Klar, as always.
    private func stopAtLimit() {
        ticker?.cancel()
        tap?.stop()
        levelDBFS = nil
    }

    var reachedLimit: Bool { elapsed >= Self.limit }

    /// Klar: stop, write out the words on the phone, delete the audio. Nil when nothing could be made out.
    func finish() async -> String? {
        ticker?.cancel()
        guard let tap else { return nil }
        tap.stop()
        self.tap = nil
        levelDBFS = nil
        state = .transcribing
        let text = await SleepRecorder.transcribe(tap.url)
        try? FileManager.default.removeItem(at: tap.url)
        if let text, !text.isEmpty {
            state = .idle
            return text
        }
        state = .failed("Earmind kunde inte höra något svar i inspelningen.")
        return nil
    }

    /// Avbryt: the audio is deleted, nothing is sent.
    func cancel() {
        ticker?.cancel()
        tap?.stop()
        if let url = tap?.url { try? FileManager.default.removeItem(at: url) }
        tap = nil
        levelDBFS = nil
        elapsed = 0
        state = .idle
    }
}

/// The microphone question, the same as the listening session asks.
enum AudioSessionPermission {
    static func microphone() async -> Bool {
        switch AVAudioApplication.shared.recordPermission {
        case .granted: return true
        case .denied: return false
        default: return await AVAudioApplication.requestRecordPermission()
        }
    }
}

/// The audio engine and the file. The audio thread writes buffers to the file and reports the level; `stop()` ends
/// both. `@unchecked Sendable`: the file is written only on the tap's thread, and `stop()` removes the tap first.
private final class RecorderTap: @unchecked Sendable {
    let url: URL
    private let engine = AVAudioEngine()
    private let onLevel: @Sendable (Double) -> Void
    private var file: AVAudioFile?
    private var lastLevel = Date.distantPast

    init(url: URL, onLevel: @escaping @Sendable (Double) -> Void) {
        self.url = url
        self.onLevel = onLevel
    }

    func start() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .default, options: [])
        try session.setActive(true)
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        file = try AVAudioFile(forWriting: url, settings: format.settings)
        input.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
            guard let self else { return }
            try? self.file?.write(from: buffer)
            let now = Date()
            guard now.timeIntervalSince(self.lastLevel) > 0.1 else { return }
            self.lastLevel = now
            self.onLevel(Self.level(buffer))
        }
        engine.prepare()
        try engine.start()
    }

    func stop() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        file = nil // closes the file
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private static func level(_ buffer: AVAudioPCMBuffer) -> Double {
        guard let data = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return -60 }
        var sum: Float = 0
        for i in 0..<Int(buffer.frameLength) { sum += data[i] * data[i] }
        let rms = (sum / Float(buffer.frameLength)).squareRoot()
        return max(-60, min(0, 20 * log10(Double(max(rms, 0.000_001)))))
    }
}
