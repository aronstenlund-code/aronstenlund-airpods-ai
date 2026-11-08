import SwiftUI

/// The product screen (MVP item 1): Start/Stop listening, live transcript, answer history.
/// The always-visible indicator lives in `RootView` so it covers every screen, not only this one.
struct ListeningView: View {
    @Bindable var model: ListeningModel
    let diagnostics: DiagnosticsModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var reportingTurn: AnswerTurn?
    @State private var reportComment = ""

    var body: some View {
        List {
            provCard
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
        .alert("Report this answer", isPresented: isReporting, presenting: reportingTurn) { turn in
            TextField("What was wrong? (optional)", text: $reportComment)
            Button("Send") { Task { await model.report(turn, comment: reportComment) } }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("Your question and this answer go to the developers word for word.")
        }
        .sheet(isPresented: $model.isShowingInterviewSetup) {
            NavigationStack {
                InterviewSetupView(model: model, settings: model.modeSettings)
            }
        }
        .sheet(isPresented: $model.isShowingLiveStart) {
            NavigationStack {
                LiveStartView(model: model, settings: model.modeSettings, mode: model.selectedMode)
            }
        }
        .sheet(isPresented: $model.isShowingExamSetup) {
            if let materials = model.examMaterials, let client = model.examClient {
                NavigationStack { ExamSetupView(model: model, materials: materials, client: client) }
            }
        }
        .sheet(isPresented: $model.isShowingStudyOnboarding) {
            StudyOnboardingView(initial: model.studyProfile.profile) { answers in
                Task { await model.finishStudyOnboarding(answers) }
            }
        }
        .sheet(isPresented: $model.isShowingAgeGate) {
            AgeGateView { model.answerAgeGate(confirmed: $0) }
        }
        .onChange(of: model.selectedMode) { model.modeSelected() }
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
            if model.usesPhoneMicrophone, model.isActiveSession {
                Label("Put the phone on the table, close to the person talking.", systemImage: "iphone.gen3")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
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
        case .listening: model.study.isUserSpeaking ? "Provläge · I hear you…" : "Provläge · your turn — just speak"
        case .thinking: "Provläge · thinking…"
        case .speaking: "Provläge · speaking — talk to interrupt"
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
            Label(engine.isOnDevice ? "Transcribing on this iPhone · \(engine.displayName)" : "Transcribing with Scribe in the cloud", systemImage: "text.bubble")
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
        case .listening: "No audio is saved."
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
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        if let label = segment.speakerLabel {
                            // D81: "Du" / "Talare 1" from the voice.
                            Text(verbatim: label)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(label == "Du" || label == "You" ? Color.accentColor : .secondary)
                        }
                        Text(segment.text)
                            .foregroundStyle(segment.isFinal ? .primary : .secondary)
                            .italic(!segment.isFinal)
                    }
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
            if let notice = model.reportNotice {
                Label(notice, systemImage: "paperplane")
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
                        HStack {
                            Text(answerCaption(turn))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            Spacer()
                            Button("Report") {
                                reportComment = ""
                                reportingTurn = turn
                            }
                            .font(.caption2)
                            .buttonStyle(.borderless)
                        }
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
        case .auto: "Auto"
        case .answerLast: "Last sentence"
        case .overheard: "Intervjuläge"
        case .rizz: "Rizzläge"
        case .interviewPrep: "Intervjuläge"
        case .text: "Text"
        case .tutor: "Provläge"
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

    private var isReporting: Binding<Bool> {
        Binding(get: { reportingTurn != nil }, set: { if !$0 { reportingTurn = nil } })
    }

    private var modeButtonTitle: LocalizedStringKey {
        if model.study.isActive { return "End session" }
        switch model.selectedMode {
        case .standard: return ""
        case .prov: return "Start Provläge"
        case .interview: return "Set up Intervjuläge"
        case .rizz: return "Set up Rizzläge"
        case .social: return "Set up Socialt läge"
        }
    }

    private var controls: some View {
        VStack(spacing: 10) {
            textQuestionRow
            Picker("Mode", selection: $model.selectedMode) {
                Text("Frågor (Auto)").tag(ConversationMode.standard)
                Text("Provläge").tag(ConversationMode.prov)
                Text("Intervjuläge").tag(ConversationMode.interview)
                Text("Socialt läge").tag(ConversationMode.social)
                Text("Rizzläge (18+)").tag(ConversationMode.rizz)
            }
            .pickerStyle(.menu)
            .disabled(model.study.isActive)
            Text("Säg \"\(WakeWord.name), byt till provläge\" för att byta utan att ta upp telefonen.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            // D74: one stop button. While a session runs, "Stop listening" below ends it and the microphone.
            if model.selectedMode != .standard, !model.study.isActive {
                Button {
                    Task { await model.toggleSelectedMode() }
                } label: {
                    Label(modeButtonTitle, systemImage: model.study.isActive ? "stop.circle" : "play.circle")
                        .font(.title3.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
                .tint(.purple)
            }
            if let session = model.rizz, let line = session.current {
                Button {
                    model.nextSuggestion()
                } label: {
                    Label(line, systemImage: "forward.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            if model.isListening, !model.study.isActive {
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

    /// D72: Provläge one tap away. Starts at once, no start screen or settings in between; never ends by itself (D71).
    @ViewBuilder
    private var provCard: some View {
        if !model.study.isActive {
            Section {
                Button {
                    Task { await model.startProvFromCard() }
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "graduationcap.fill")
                            .font(.title)
                            .foregroundStyle(.white)
                            .frame(width: 52, height: 52)
                            .background(Color.purple, in: RoundedRectangle(cornerRadius: 12))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Få A-svar till provet")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text("Provläge · tryck för att starta")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "play.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.purple)
                    }
                    .padding(.vertical, 6)
                }
                .accessibilityLabel("Få A-svar till provet. Startar Provläge.")
                if model.examMaterials != nil {
                    // D84: upload an exam and its marking instructions, then practise it by voice.
                    Button {
                        model.isShowingExamSetup = true
                    } label: {
                        Label("Provsession · ladda upp ett prov", systemImage: "doc.text.viewfinder")
                    }
                }
                if let cards = model.studyCards, !cards.current().isEmpty {
                    // D81: five questions by voice from the study cards, linked to the exam.
                    Button {
                        Task { await model.startMiniTest() }
                    } label: {
                        Label("Minitest · 5 frågor (\(cards.current().count) studiekort)", systemImage: "checklist")
                    }
                }
            }
        }
    }
}
