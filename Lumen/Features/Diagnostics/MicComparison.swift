import Foundation
import LumenScoring
import Observation

/// Mikrofonjämförelsen (D55): the same five sentences through each microphone, read by the wearer and by another
/// person at 1.5 m, scored as word error rate against what the recogniser heard. Kept in memory; "Copy results"
/// exports it.
@MainActor
@Observable
final class MicComparisonModel {
    enum Speaker: String, CaseIterable, Identifiable, Sendable {
        case wearer = "own voice"
        case otherPerson = "other person at 1.5 m"

        var id: String { rawValue }
    }

    struct Trial: Identifiable, Equatable, Sendable {
        let id = UUID()
        var source: MicrophoneSource
        var speaker: Speaker
        var sentence: String
        var heard: String
        var wer: Double
        var recognizer: String
        var route: String
    }

    static let sentences = [
        "Vad är huvudstaden i Australien?",
        "Mitokondrien ger cellen energi genom att bryta ner socker.",
        "Hur många kilometer är det mellan Stockholm och Göteborg?",
        "Andra världskriget slutade år nittonhundrafyrtiofem.",
        "Jag tänkte fråga om du vill ta en kaffe efter jobbet.",
    ]

    var source: MicrophoneSource = .airPods
    var speaker: Speaker = .wearer
    private(set) var sentenceIndex = 0
    private(set) var isRecording = false
    private(set) var trials: [Trial] = []
    private let listening: ListeningModel
    private let settleDelay: Duration
    private let scorer = Scorer()
    private var mark = 0

    init(listening: ListeningModel, settleDelay: Duration = .seconds(1.5)) {
        self.listening = listening
        self.settleDelay = settleDelay
    }

    var sentence: String { Self.sentences[sentenceIndex] }
    var canRecord: Bool { listening.consent.isGranted }

    func start() async {
        guard !isRecording, let mark = await listening.startComparison(source) else { return }
        self.mark = mark
        isRecording = true
    }

    /// Lets the recogniser finish, scores the sentence and moves on to the next one.
    func finish() async {
        guard isRecording else { return }
        isRecording = false
        listening.transcription.commit()
        try? await Task.sleep(for: settleDelay)
        let heard = listening.finishComparison(from: mark)
        trials.append(Trial(source: source, speaker: speaker, sentence: sentence, heard: heard,
                            wer: scorer.score(reference: sentence, hypothesis: heard).wer,
                            recognizer: listening.recognizerName, route: listening.routeSummary ?? "no route"))
        sentenceIndex = (sentenceIndex + 1) % Self.sentences.count
    }

    /// One line per source and speaker: the average word error rate of its sentences.
    var summaryLines: [String] {
        MicrophoneSource.allCases.flatMap { source in
            Speaker.allCases.compactMap { speaker in
                let matching = trials.filter { $0.source == source && $0.speaker == speaker }
                guard !matching.isEmpty else { return nil }
                let average = matching.map(\.wer).reduce(0, +) / Double(matching.count)
                return "\(source.rawValue) · \(speaker.rawValue): WER \(String(format: "%.0f", average * 100)) % (n=\(matching.count))"
            }
        }
    }

    var markdown: String {
        guard !trials.isEmpty else { return "_not run_" }
        var out = summaryLines.map { "- \($0)" }
        out.append("")
        out.append("| Microphone | Speaker | WER | Recogniser | Route | Sentence | Heard |")
        out.append("|---|---|---|---|---|---|---|")
        for trial in trials {
            out.append("| \(trial.source.rawValue) | \(trial.speaker.rawValue) | \(String(format: "%.2f", trial.wer)) | \(trial.recognizer) | \(trial.route) | \(trial.sentence) | \(trial.heard) |")
        }
        return out.joined(separator: "\n")
    }
}
