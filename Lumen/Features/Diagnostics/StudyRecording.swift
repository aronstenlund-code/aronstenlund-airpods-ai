import Foundation
import Observation
import SwiftUI
import UIKit

/// D87: "Spela in plugg-session". Ten minutes of a real study session for measuring: the same audio the recogniser
/// gets (WAV), what was heard, what was asked, every answer with its timings, what was spoken and the session log,
/// all with the time from the start. Started by hand in Diagnostik (test build only, D8: no audio is stored
/// otherwise), and Aron exports the files.
@MainActor
@Observable
final class StudyRecordingModel {
    static let seconds: TimeInterval = 600

    struct Event: Codable, Equatable, Sendable {
        /// Seconds from the start of the recording.
        var t: Double
        var kind: String
        var text: String
        var trigger: String?
        var question: String?
        var firstTextMs: Double?
        var source: String?
    }

    private(set) var isRecording = false
    private(set) var elapsed: TimeInterval = 0
    private(set) var files: [URL] = []
    private(set) var notice: String?
    private(set) var events: [Event] = []

    private let listening: ListeningModel
    private var samples: [Int16] = []
    private var startedAt = Date()
    private var task: Task<Void, Never>?
    private var subscription: UUID?
    private var header = ""

    init(listening: ListeningModel) {
        self.listening = listening
    }

    /// Starts Provläge if nothing is running, then records.
    func start() async {
        guard !isRecording else { return }
        if !listening.isListening { await listening.startStudy() }
        guard listening.isListening else {
            notice = "Mikrofonen kunde inte starta."
            return
        }
        samples = []
        events = []
        files = []
        notice = nil
        elapsed = 0
        startedAt = Date()
        isRecording = true
        header = describeSetup()
        listening.sessionObserver = { [weak self] event, date in self?.record(event, at: date) }
        listening.controller.logObserver = { [weak self] entry in self?.add(Event(t: self?.offset(entry.time) ?? 0, kind: "log", text: entry.text)) }
        let audio = listening.subscribeToAudio()
        subscription = audio.id
        let limit = Int(Self.seconds * LumenAudioFormat.sampleRate)
        samples.reserveCapacity(limit)
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

    private func offset(_ date: Date) -> Double {
        (date.timeIntervalSince(startedAt) * 10).rounded() / 10
    }

    private func add(_ event: Event) {
        guard isRecording else { return }
        events.append(event)
    }

    private func record(_ event: ListeningModel.SessionEvent, at date: Date) {
        let t = offset(date)
        switch event {
        case .heard(let text):
            add(Event(t: t, kind: "heard", text: text, source: listening.recognizerName))
        case .asked(let query, let trigger):
            add(Event(t: t, kind: "asked", text: query, trigger: trigger))
        case .answered(let question, let answer, let firstTextMs, let source):
            add(Event(t: t, kind: "answered", text: answer, question: question, firstTextMs: firstTextMs, source: source))
        case .spoke(let text):
            add(Event(t: t, kind: "spoke", text: text))
        }
    }

    private func finish() {
        isRecording = false
        task?.cancel()
        task = nil
        if let subscription { listening.unsubscribeFromAudio(subscription) }
        subscription = nil
        listening.sessionObserver = nil
        listening.controller.logObserver = nil
        write()
    }

    private func describeSetup() -> String {
        let device = UIDevice.current
        let profile = listening.studyProfile.profile
        return """
        Lumen plugg-session \(Date().formatted(date: .numeric, time: .standard))
        Enhet: \(device.model), iOS \(device.systemVersion)
        Läge: \(listening.mode.rawValue), igenkänning: \(listening.recognizerName), ljudväg: \(listening.routeSummary ?? "ingen")
        Prov: \(listening.currentExamID()?.uuidString ?? "inget"), profil: \(profile.setupText() ?? "ingen")
        Keyterms (provets först): \(ExamKeyterms.terms(profile: profile).joined(separator: ", "))
        """
    }

    /// The text file: everything in time order. Pure, so it can be tested.
    static func transcript(header: String, events: [Event], recordedSeconds: Double) -> String {
        var lines = [header, String(format: "Inspelat: %.1f s", recordedSeconds), ""]
        for event in events {
            let stamp = String(format: "[%02d:%04.1f]", Int(event.t) / 60, event.t.truncatingRemainder(dividingBy: 60))
            switch event.kind {
            case "heard": lines.append("\(stamp) HÖRDE (\(event.source ?? "")): \(event.text)")
            case "asked": lines.append("\(stamp) FRÅGADE (\(event.trigger ?? "")): \(event.text)")
            case "answered":
                let ms = event.firstTextMs.map { String(format: "%.0f ms till första text", $0) } ?? "ingen tid"
                lines.append("\(stamp) SVAR (\(event.source ?? ""), \(ms)) på \"\(event.question ?? "")\": \(event.text)")
            case "spoke": lines.append("\(stamp) SA: \(event.text)")
            default: lines.append("\(stamp) logg: \(event.text)")
            }
        }
        return lines.joined(separator: "\n")
    }

    private func write() {
        #if DEBUG
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let stamp = Self.stamp(startedAt)
        let wav = documents.appendingPathComponent("lumen-plugg-\(stamp).wav")
        let text = documents.appendingPathComponent("lumen-plugg-\(stamp).txt")
        let json = documents.appendingPathComponent("lumen-plugg-\(stamp).json")
        do {
            try WAVWriter.write(samples: samples, sampleRate: Int(LumenAudioFormat.sampleRate), to: wav)
            try Data(Self.transcript(header: header, events: events, recordedSeconds: elapsed).utf8).write(to: text)
            struct File: Encodable { var header: String; var recordedSeconds: Double; var events: [Event] }
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(File(header: header, recordedSeconds: elapsed, events: events)).write(to: json)
            files = [wav, text, json]
            notice = "Sparat: \(wav.lastPathComponent), .txt och .json"
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

/// Diagnostik: the button and the export.
struct StudyRecordingSection: View {
    let model: StudyRecordingModel

    var body: some View {
        Section("Spela in plugg-session (10 min)") {
            Text("Starta Provläget (eller tryck Spela in, så startar det), plugga som vanligt i upp till 10 minuter och tryck Stoppa. Exportera sedan alla tre filerna: ljud, transkript med svar och tider, och samma data som JSON.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button(model.isRecording ? "Stoppa inspelningen" : "Spela in plugg-session") {
                if model.isRecording { model.stop() } else { Task { await model.start() } }
            }
            if model.isRecording {
                ProgressView(value: min(1, model.elapsed / StudyRecordingModel.seconds)) {
                    Text(verbatim: String(format: "%.0f av %.0f s, %d händelser", model.elapsed, StudyRecordingModel.seconds, model.events.count))
                }
            }
            if !model.files.isEmpty {
                ShareLink(items: model.files) {
                    Label("Exportera WAV, transkript och JSON", systemImage: "square.and.arrow.up")
                }
            }
            if let notice = model.notice {
                Text(verbatim: notice).font(.caption)
            }
        }
    }
}
