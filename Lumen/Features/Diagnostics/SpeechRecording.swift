import Foundation
import Observation
import UIKit

/// Diagnostics (D78): two minutes of the same audio the recogniser gets, with what it heard, as WAV + text for Aron
/// to send. "Kör iPhone-igenkänning" then runs the phone's own recogniser on that recording, so Scribe and Apple can be
/// compared on the same sound. Debug builds only (no audio is stored otherwise, D8); started by hand, never by itself.
@MainActor
@Observable
final class SpeechRecordingModel {
    static let seconds: TimeInterval = 120

    private(set) var isRecording = false
    private(set) var elapsed: TimeInterval = 0
    private(set) var files: [URL] = []
    private(set) var notice: String?
    private(set) var isTranscribingOnDevice = false

    private let listening: ListeningModel
    private var samples: [Int16] = []
    private var lines: [String] = []
    private var startedAt = Date()
    private var task: Task<Void, Never>?
    private var subscription: UUID?
    private var header = ""

    init(listening: ListeningModel) {
        self.listening = listening
    }

    var canRecord: Bool { listening.isListening }

    func start() {
        guard !isRecording, listening.isListening else {
            notice = "Börja lyssna först."
            return
        }
        samples = []
        lines = []
        files = []
        notice = nil
        elapsed = 0
        startedAt = Date()
        isRecording = true
        header = describeSetup()
        listening.finalObserver = { [weak self] text in self?.heard(text) }
        let audio = listening.subscribeToAudio()
        subscription = audio.id
        let limit = Int(Self.seconds * LumenAudioFormat.sampleRate)
        task = Task { [weak self] in
            for await chunk in audio.stream {
                guard let self, self.isRecording else { break }
                self.samples += chunk.samples
                self.elapsed = Double(self.samples.count) / LumenAudioFormat.sampleRate
                if self.samples.count >= limit {
                    self.finish()
                    break
                }
            }
        }
    }

    func stop() {
        guard isRecording else { return }
        finish()
    }

    private func heard(_ text: String) {
        let offset = Date().timeIntervalSince(startedAt)
        lines.append(String(format: "[%02d:%04.1f] (%@) %@", Int(offset) / 60, offset.truncatingRemainder(dividingBy: 60),
                            listening.recognizerName, text))
    }

    private func finish() {
        isRecording = false
        task?.cancel()
        task = nil
        if let subscription { listening.unsubscribeFromAudio(subscription) }
        subscription = nil
        listening.finalObserver = nil
        write(extra: nil)
    }

    /// Runs the phone's recogniser on the recording and adds its transcript to the text file.
    func transcribeOnDevice() async {
        guard !samples.isEmpty, !isTranscribingOnDevice else { return }
        isTranscribingOnDevice = true
        defer { isTranscribingOnDevice = false }
        let result = await listening.transcription.transcribeOnDevice(samples)
        switch result {
        case .success(let (engine, finals)):
            write(extra: "--- \(engine) on the same recording ---\n" + (finals.isEmpty ? "(nothing recognised)" : finals.joined(separator: "\n")))
        case .failure(let reason):
            notice = "iPhone-igenkänningen gick inte: \(reason.message)"
        }
    }

    private func describeSetup() -> String {
        let device = UIDevice.current
        let tuning = listening.transcription.scribeTuning
        let vad = listening.transcription.settings?.useLocalVAD == true ? "on" : "off"
        return """
        Lumen speech recording · \(Date().formatted(date: .numeric, time: .standard))
        Device: \(device.model) · iOS \(device.systemVersion)
        Mode: \(listening.mode.rawValue) · recogniser: \(listening.recognizerName) · route: \(listening.routeSummary ?? "no route")
        Scribe pause detection: \(tuning.silenceSeconds) s · vad_threshold \(tuning.threshold) · local VAD \(vad)
        """
    }

    private func write(extra: String?) {
        #if DEBUG
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let stamp = Self.stamp(startedAt)
        let wav = documents.appendingPathComponent("lumen-speech-\(stamp).wav")
        let text = documents.appendingPathComponent("lumen-speech-\(stamp).txt")
        do {
            if !FileManager.default.fileExists(atPath: wav.path) {
                try WAVWriter.write(samples: samples, sampleRate: Int(LumenAudioFormat.sampleRate), to: wav)
            }
            let vad = String(format: "Local VAD: %.1f s sent to Scribe, %.1f s held back",
                             listening.transcription.vadSentSeconds, listening.transcription.vadHeldSeconds)
            var body = header + "\n" + vad + String(format: "\nRecorded: %.1f s\n\n--- live transcript ---\n", elapsed)
            body += lines.isEmpty ? "(nothing recognised)" : lines.joined(separator: "\n")
            if let extra { body += "\n\n" + extra }
            try Data(body.utf8).write(to: text)
            files = [wav, text]
            notice = "Sparat: \(wav.lastPathComponent) och \(text.lastPathComponent)"
        } catch {
            notice = "Kunde inte spara: \(error.localizedDescription)"
        }
        #else
        notice = "Inspelning finns bara i testbygget."
        #endif
    }

    private static func stamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: date)
    }
}
