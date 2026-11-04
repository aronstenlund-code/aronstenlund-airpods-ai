import SwiftUI

/// The product screen (MVP item 1): Start/Stop listening, live transcript, answer history.
/// The always-visible indicator lives in `RootView` so it covers every screen, not only this one.
struct ListeningView: View {
    @Bindable var model: ListeningModel
    let diagnostics: DiagnosticsModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        List {
            statusSection
            transcriptSection
            answersSection
        }
        .listStyle(.insetGrouped)
        .overlay(alignment: .topTrailing) { latencyOverlay }
        .safeAreaInset(edge: .bottom) { controls }
        .navigationTitle("Lumen")
        .task { await model.prepareBackend() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await model.prepareBackend() } }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { model.isShowingNotes = true } label: { Label("Notes", systemImage: "note.text") }
                    Button { model.isShowingPrep = true } label: { Label("Prep material", systemImage: "books.vertical") }
                    Button { model.isShowingCommands = true } label: { Label("Commands", systemImage: "command") }
                    Button { model.isShowingDiagnostics = true } label: { Label("Diagnostics", systemImage: "waveform.badge.magnifyingglass") }
                    Button { model.isShowingPrivacy = true } label: { Label("Privacy & consent", systemImage: "hand.raised") }
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    model.isShowingSettings = true
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
            }
        }
        .navigationDestination(isPresented: $model.isShowingDiagnostics) {
            DiagnosticsView(model: diagnostics)
        }
        .sheet(isPresented: $model.isShowingNotes) {
            NavigationStack {
                NotesView(store: model.notes)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Done") { model.isShowingNotes = false }
                        }
                    }
            }
        }
        .sheet(isPresented: $model.isShowingCommands) {
            NavigationStack {
                CommandsView(store: model.commands)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Done") { model.isShowingCommands = false }
                        }
                    }
            }
        }
        .sheet(isPresented: $model.isShowingPrep) {
            NavigationStack {
                PrepView(store: model.prep, goals: model.goals)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Done") { model.isShowingPrep = false }
                        }
                    }
            }
        }
        .sheet(isPresented: $model.isShowingSettings) {
            NavigationStack {
                SettingsView(model: model)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { model.isShowingSettings = false }
                        }
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

    // MARK: Latency overlay (item 7, Debug builds)

    @AppStorage("debug.latencyOverlay") private var showsLatencyOverlay = false

    @ViewBuilder
    private var latencyOverlay: some View {
        #if DEBUG
        if showsLatencyOverlay {
            VStack(alignment: .trailing, spacing: 2) {
                if let latest = model.latency.latest {
                    Text(verbatim: latest.summary)
                }
                if let p50 = model.latency.firstSpeechP50, let p95 = model.latency.firstSpeechP95 {
                    Text(verbatim: "voice p50 \(Int(p50)) · p95 \(Int(p95)) · n=\(model.latency.records.count)")
                } else if let p50 = model.latency.firstTextP50 {
                    Text(verbatim: "text p50 \(Int(p50)) · n=\(model.latency.records.count)")
                } else {
                    Text(verbatim: "latency: no answers yet")
                }
            }
            .font(.caption2.monospacedDigit())
            .padding(6)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
            .padding(8)
            .allowsHitTesting(false)
        }
        #endif
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
            speakerRow
            studyRow
        }
    }

    @ViewBuilder
    private var studyRow: some View {
        if model.study.isActive {
            Label(studyPhaseText, systemImage: "graduationcap.fill")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.purple)
        }
        if let notice = model.studyNotice {
            Label(notice, systemImage: "moon.zzz")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var studyPhaseText: LocalizedStringKey {
        switch model.study.phase {
        case .off: ""
        case .listening: model.study.isUserSpeaking ? "Pluggläge · I hear you…" : "Pluggläge · your turn — just speak"
        case .thinking: "Pluggläge · thinking…"
        case .speaking: "Pluggläge · speaking — talk to interrupt"
        }
    }

    @ViewBuilder
    private var speakerRow: some View {
        if model.speaker.status != .idle {
            Label("Speaking…", systemImage: "speaker.wave.2.fill")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else if !model.speaker.settings.speakAnswers {
            Label("Silent mode: answers are shown, not spoken.", systemImage: "speaker.slash")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        if let notice = model.speaker.notice {
            Label(notice, systemImage: "exclamationmark.triangle")
                .font(.footnote)
                .foregroundStyle(.orange)
        }
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
            case .user: "Your music can play now. Answers are shown, not spoken, until you resume."
            case .interruption: "A call or another app took the audio. Tap Resume to listen again."
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
            if let streaming = model.conversation.streamingAnswer {
                VStack(alignment: .leading, spacing: 4) {
                    Text(streaming.question)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if streaming.answer.isEmpty {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Thinking…").foregroundStyle(.secondary)
                        }
                    } else {
                        Text(streaming.answer)
                    }
                    HStack(spacing: 4) {
                        if let question = model.pendingQuestion {
                            Text(triggerLabel(question.trigger))
                            Text(verbatim: "·")
                        }
                        Text(streaming.source)
                    }
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 2)
            }
            if let notice = model.answerNotice {
                Label(notice, systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
            if let notice = model.commandNotice {
                Label(notice, systemImage: "command")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if let savedAt = model.noteSavedAt {
                Label("Saved as a note \(savedAt.formatted(date: .omitted, time: .shortened))", systemImage: "checkmark.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if model.conversation.answers.isEmpty && model.conversation.streamingAnswer == nil && model.answerNotice == nil {
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
                if model.canSaveNote {
                    Button("Save note") { model.saveNote() }
                        .font(.footnote)
                        .textCase(nil)
                }
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
        case .tutor: "Pluggläge"
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
            textQuestionRow
            Button {
                Task { await model.toggleStudyMode() }
            } label: {
                Label(model.study.isActive ? "End Pluggläge" : "Pluggläge",
                      systemImage: model.study.isActive ? "graduationcap.fill" : "graduationcap")
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.bordered)
            .tint(.purple)
            if model.isListening, !model.study.isActive {
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

            if model.isActiveSession {
                Button {
                    Task { await model.togglePause() }
                } label: {
                    Label(model.isListening ? "Pause for music" : "Resume listening",
                          systemImage: model.isListening ? "pause.fill" : "play.fill")
                        .font(.title3.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.bar)
    }

    /// Text mode (item 6): type a question; the answer is spoken, or only shown in silent mode. No microphone needed.
    private var textQuestionRow: some View {
        HStack(spacing: 8) {
            TextField("Type a question", text: $model.draftQuestion)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.send)
                .onSubmit { model.sendDraft() }
            Button {
                model.sendDraft()
            } label: {
                Image(systemName: "paperplane.fill")
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!model.canSendDraft)
            .accessibilityLabel("Send")
        }
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
