import SwiftUI

/// The product screen (MVP item 1): Start/Stop listening, live transcript, answer history.
/// The always-visible indicator lives in `RootView` so it covers every screen, not only this one.
struct ListeningView: View {
    @Bindable var model: ListeningModel
    let diagnostics: DiagnosticsModel

    var body: some View {
        List {
            statusSection
            transcriptSection
            answersSection
        }
        .listStyle(.insetGrouped)
        .safeAreaInset(edge: .bottom) { controls }
        .navigationTitle("Lumen")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    DiagnosticsView(model: diagnostics)
                } label: {
                    Label("Diagnostics", systemImage: "waveform.badge.magnifyingglass")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    model.isShowingPrivacy = true
                } label: {
                    Label("Privacy & consent", systemImage: "hand.raised")
                }
            }
        }
        .sheet(isPresented: $model.isShowingPrivacy) {
            NavigationStack {
                ConsentView(mode: .review(grantedAt: model.consent.record?.grantedAt) {
                    model.isShowingPrivacy = false
                    Task { await model.withdrawConsent() }
                })
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { model.isShowingPrivacy = false }
                    }
                }
            }
        }
    }

    // MARK: Sections

    private var statusSection: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: model.isListening ? "mic.fill" : "mic.slash")
                    .font(.title2)
                    .foregroundStyle(model.isListening ? .red : .secondary)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(statusTitle).font(.headline)
                    if let route = model.routeSummary, model.isActiveSession {
                        Text(route).font(.footnote).foregroundStyle(.secondary)
                    } else {
                        Text(statusDetail).font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
            if model.isListening {
                ProgressView(value: DiagnosticsView.meterValue(model.level.rmsDBFS))
                    .tint(model.level.peakDBFS > -3 ? .red : .green)
                    .accessibilityLabel("Input level")
            }
            if let error = model.lastError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }

    private var statusTitle: LocalizedStringKey {
        switch model.state {
        case .idle: "Not listening"
        case .listening: "Listening"
        case .paused: "Paused"
        case .error: "Could not start"
        }
    }

    private var statusDetail: LocalizedStringKey {
        switch model.state {
        case .idle: "Tap Start listening. The microphone is only on while you listen."
        case .listening: "Speech is transcribed on this iPhone."
        case .paused(let reason):
            switch reason {
            case .interruption: "A call or another app interrupted the session."
            case .awaitingUserResume: "Tap Resume to continue."
            case .outputDeviceLost: "AirPods disconnected. Put them back in and tap Resume."
            case .mediaServicesReset: "The audio system was reset. Tap Resume to continue."
            }
        case .error: "See the message below and try again."
        }
    }

    private var transcriptSection: some View {
        Section("Live transcript") {
            if model.conversation.segments.isEmpty {
                Text(model.isListening ? "Listening… recognised speech appears here." : "Nothing transcribed yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(model.conversation.segments) { segment in
                    Text(segment.text)
                        .foregroundStyle(segment.isFinal ? .primary : .secondary)
                        .italic(!segment.isFinal)
                }
            }
        }
    }

    private var answersSection: some View {
        Section {
            if model.conversation.answers.isEmpty {
                Text("Answers to questions appear here and are spoken in your AirPods.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(model.conversation.answers.reversed()) { turn in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(turn.question)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(turn.answer)
                        Text(answerCaption(turn))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 2)
                }
            }
        } header: {
            HStack {
                Text("Answers")
                Spacer()
                if !model.conversation.isEmpty {
                    Button("Clear") { model.clearHistory() }
                        .font(.footnote)
                        .textCase(nil)
                }
            }
        }
    }

    private func answerCaption(_ turn: AnswerTurn) -> String {
        var parts = [turn.createdAt.formatted(date: .omitted, time: .shortened), turn.source]
        if let latency = turn.latencyMs {
            parts.append(String(format: "%.0f ms", latency))
        }
        return parts.joined(separator: " · ")
    }

    // MARK: Controls

    private var controls: some View {
        VStack(spacing: 10) {
            Button {
                Task { await model.toggleListening() }
            } label: {
                Label(model.isActiveSession ? "Stop listening" : "Start listening",
                      systemImage: model.isActiveSession ? "stop.fill" : "mic.fill")
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .tint(model.isActiveSession ? .red : .accentColor)

            if model.canResume {
                Button {
                    Task { await model.resume() }
                } label: {
                    Label("Resume listening", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.bar)
    }
}
