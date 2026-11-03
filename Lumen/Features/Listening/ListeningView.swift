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
            transcriptionStatusRow
            Picker("Language", selection: languageBinding) {
                ForEach(TranscriptionLanguage.allCases) { language in
                    Text(language.nativeName).tag(language)
                }
            }
            .pickerStyle(.segmented)
            activationSettingsRows
        }
    }

    @ViewBuilder
    private var activationSettingsRows: some View {
        @Bindable var settings = model.activation.settings
        Picker("Activation", selection: $settings.mode) {
            Text("Hold to ask").tag(ActivationMode.pushToTalk)
            Text("Auto").tag(ActivationMode.auto)
        }
        .pickerStyle(.segmented)
        if settings.mode == .auto {
            Picker("Sensitivity", selection: $settings.sensitivity) {
                Text("Low").tag(GateSensitivity.low)
                Text("Medium").tag(GateSensitivity.medium)
                Text("High").tag(GateSensitivity.high)
            }
            Text("Auto listens for questions in the room. Hold to ask gives the fewest false answers.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var languageBinding: Binding<TranscriptionLanguage> {
        Binding(get: { model.transcription.language.selected },
                set: { newValue in Task { await model.transcription.setLanguage(newValue) } })
    }

    @ViewBuilder
    private var transcriptionStatusRow: some View {
        switch model.transcription.status {
        case .idle:
            EmptyView()
        case .probing:
            Label("Checking speech recognition…", systemImage: "ellipsis.circle")
                .font(.footnote)
                .foregroundStyle(.secondary)
        case .preparing(let engine):
            Label("Preparing the speech model (\(engine.displayName)) — the first time this downloads it.", systemImage: "arrow.down.circle")
                .font(.footnote)
                .foregroundStyle(.secondary)
        case .running(let engine):
            Label("Transcribing on this iPhone · \(engine.displayName)", systemImage: "text.bubble")
                .font(.footnote)
                .foregroundStyle(.secondary)
        case .unavailable(let language):
            Label("\(language.nativeName) is not available for on-device speech recognition on this iPhone. Switch language below.", systemImage: "exclamationmark.triangle")
                .font(.footnote)
                .foregroundStyle(.orange)
        case .failed(let message):
            Label("Speech recognition failed: \(message)", systemImage: "exclamationmark.triangle")
                .font(.footnote)
                .foregroundStyle(.red)
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
            if let question = model.pendingQuestion {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Detected question", systemImage: "questionmark.bubble")
                        .font(.subheadline.weight(.semibold))
                    Text(question.query)
                    HStack(spacing: 4) {
                        Text(triggerLabel(question.trigger))
                        Text(verbatim: "·")
                        Text(question.createdAt, style: .time)
                    }
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    Text("Answer engine not connected yet (next step).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }
            if model.conversation.answers.isEmpty && model.pendingQuestion == nil {
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

    private func triggerLabel(_ trigger: ActivationTrigger) -> LocalizedStringKey {
        switch trigger {
        case .pushToTalk: "Hold to ask"
        case .auto: "Auto"
        case .answerLast: "Last sentence"
        case .text: "Text"
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
            if model.isListening {
                holdToAskButton
                Button {
                    model.askAboutLast()
                } label: {
                    Label("Ask about the last sentence", systemImage: "arrow.uturn.backward.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(model.conversation.finalSegments.isEmpty)
            }
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

    /// Press-and-hold: the words said while holding become the question (push-to-talk, the default trigger).
    private var holdToAskButton: some View {
        Label(model.isHolding ? "Listening to you… release to ask" : "Hold to ask",
              systemImage: model.isHolding ? "waveform.circle.fill" : "hand.tap")
            .font(.title3.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(model.isHolding ? Color.orange.opacity(0.9) : Color.accentColor.opacity(0.15),
                        in: RoundedRectangle(cornerRadius: 12))
            .foregroundStyle(model.isHolding ? Color.white : Color.accentColor)
            .contentShape(RoundedRectangle(cornerRadius: 12))
            .onLongPressGesture(minimumDuration: 3600, maximumDistance: 60, pressing: { pressing in
                if pressing {
                    model.pressPushToTalk()
                } else {
                    model.releasePushToTalk()
                }
            }, perform: {})
            .accessibilityLabel("Hold to ask")
            .accessibilityAddTraits(.isButton)
    }
}
