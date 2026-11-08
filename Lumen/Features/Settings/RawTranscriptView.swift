import SwiftUI

/// D86: Settings › Diagnostik › Rå transkription. The only place with the raw transcript, the answer's source and
/// milliseconds, and the typed question (MVP item 6), for testing.
struct RawTranscriptView: View {
    @Bindable var model: ListeningModel

    var body: some View {
        List {
            Section("Skriv en fråga") {
                HStack(spacing: 8) {
                    TextField("Fråga", text: $model.draftQuestion)
                        .submitLabel(.send)
                        .onSubmit { model.sendDraft() }
                    Button("Skicka") { model.sendDraft() }
                        .disabled(!model.canSendDraft)
                }
            }
            Section("Transkription") {
                if model.conversation.segments.isEmpty {
                    Text("Inget än.").foregroundStyle(.secondary)
                }
                ForEach(model.conversation.segments) { segment in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        if let label = segment.speakerLabel {
                            Text(verbatim: label).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        }
                        Text(segment.text)
                            .foregroundStyle(segment.isFinal ? .primary : .secondary)
                            .italic(!segment.isFinal)
                    }
                }
            }
            Section("Svar") {
                ForEach(model.conversation.answers.reversed()) { turn in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(turn.question).font(.subheadline).foregroundStyle(.secondary)
                        Text(turn.answer)
                        Text(Self.caption(turn)).font(.caption2.monospacedDigit()).foregroundStyle(.tertiary)
                    }
                }
                if let notice = model.answerNotice { Text(notice).font(.footnote).foregroundStyle(.orange) }
                if let error = model.answers.lastError { Text(verbatim: error.localizedDescription).font(.footnote).foregroundStyle(.red) }
            }
            Section("Fördröjning") {
                if let latest = model.latency.latest { Text(verbatim: latest.summary).font(.footnote.monospacedDigit()) }
                if let p50 = model.latency.firstSpeechP50, let p95 = model.latency.firstSpeechP95 {
                    Text(verbatim: "röst p50 \(Int(p50)) ms, p95 \(Int(p95)) ms, n=\(model.latency.records.count)")
                        .font(.footnote.monospacedDigit())
                }
                if let route = model.routeSummary { Text(verbatim: route).font(.footnote) }
                // A4: hack in the voice, as numbers from Aron's phone.
                if let last = model.speaker.lastAnswerStats {
                    Text(verbatim: "Röst, senaste svaret: \(last.summary)").font(.footnote.monospacedDigit())
                }
                Text(verbatim: "Röst, totalt: \(model.speaker.totalStats.summary)").font(.footnote.monospacedDigit())
                Text(verbatim: "Taligenkänning: \(model.recognizerName)").font(.footnote)
            }
        }
        .lumenForm()
        .navigationTitle("Rå transkription")
        .navigationBarTitleDisplayMode(.inline)
    }

    static func caption(_ turn: AnswerTurn) -> String {
        var parts = [turn.createdAt.formatted(date: .omitted, time: .shortened), turn.source]
        if let latency = turn.latencyMs { parts.append(String(format: "%.0f ms", latency)) }
        if turn.interrupted == true { parts.append("avbrutet") }
        return parts.joined(separator: ", ")
    }
}
