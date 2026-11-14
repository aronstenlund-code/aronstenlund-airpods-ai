import SwiftUI

/// A98 (D173, Aron's phone test 2026-11-14 12:29): "Spela in" in Mina svar, in two steps and in the system's style
/// (D160). 1. **Fråga**: typed, chosen from the exam or spoken. 2. **Svar**: the microphone starts only when
/// **Spela in svaret** is tapped, with the red dot, the time and the level while it records, and **Stoppa**. The one
/// filled button at the bottom is the next thing to do: Spela in svaret → Stoppa → Klar. Klar is not offered before
/// there is a recorded answer. Nothing is done with the audio before Klar (D126): it stays on the phone and is
/// deleted, only the text is sent. The flow is `MyAnswerRecording` (Angela Schrute).
struct MyAnswerRecordView: View {
    @Bindable var model: ListeningModel
    let examID: UUID?
    let onDone: (MyAnswerDraft) -> Void
    let onCancel: () -> Void
    @State private var recording: MyAnswerRecording
    @State private var choosing = false
    @FocusState private var questionFocused: Bool

    init(model: ListeningModel, examID: UUID?, onDone: @escaping (MyAnswerDraft) -> Void,
         onCancel: @escaping () -> Void) {
        self.model = model
        self.examID = examID
        self.onDone = onDone
        self.onCancel = onCancel
        _recording = State(initialValue: model.myAnswerRecording(examID: examID))
    }

    #if DEBUG
    /// The screenshots: a recording already in the state to show.
    init(model: ListeningModel, staged: MyAnswerRecording) {
        self.model = model
        self.examID = nil
        self.onDone = { _ in }
        self.onCancel = {}
        _recording = State(initialValue: staged)
    }
    #endif

    private var answer: AnswerRecorder { recording.answerRecorder }
    private var isMakingAnswer: Bool { recording.isCompressing || answer.state == .transcribing }

    var body: some View {
        @Bindable var flow = recording
        return Form {
            if let blocked { Section { Text(verbatim: blocked) } }

            Section {
                TextField("Skriv frågan", text: $flow.question, axis: .vertical)
                    .lineLimit(1...4)
                    .focused($questionFocused)
                    .disabled(!recording.canEditQuestion)
                if recording.canEditQuestion {
                    if !recording.choices.isEmpty {
                        Button("Välj ur provet") { choosing = true }
                    }
                    questionRecordingRow
                }
            } header: {
                Text("1. Fråga")
            } footer: {
                if case .failed(let message) = recording.questionRecorder.state { Text(verbatim: message) }
            }

            Section {
                answerStatus
            } header: {
                Text("2. Svar")
            } footer: {
                Text("Earmind gör inget med ljudet förrän du trycker Klar. Ljudet stannar på telefonen och raderas sedan; bara texten skickas.")
            }
        }
        .safeAreaInset(edge: .bottom) { mainAction }
        .navigationTitle("Spela in")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Avbryt") {
                    recording.cancel()
                    onCancel()
                }
            }
        }
        .sheet(isPresented: $choosing) { choices }
        .onDisappear { recording.cancel() }
        // What the microphone does is said as well as shown.
        .onChange(of: answer.state) { _, state in
            switch state {
            case .recording: AccessibilityNotification.Announcement("Spelar in").post()
            case .recorded: AccessibilityNotification.Announcement("Svaret är inspelat").post()
            default: break
            }
        }
        .onChange(of: recording.problem) { _, problem in
            if let problem { AccessibilityNotification.Announcement(problem).post() }
        }
    }

    /// No recording while Earmind listens: one microphone at a time.
    private var blocked: String? {
        model.isActiveSession ? "Avsluta Earmind för att spela in." : nil
    }

    // MARK: 1. The question

    /// "Spela in frågan" with the phone's microphone; while it records, the red dot, the time and Stoppa.
    @ViewBuilder
    private var questionRecordingRow: some View {
        let recorder = recording.questionRecorder
        if recorder.state == .recording {
            HStack(spacing: 10) {
                RecordingDot()
                Text(verbatim: "Spelar in frågan · \(MyAnswerText.clock(recorder.elapsed))").monospacedDigit()
                Spacer(minLength: 8)
                Button("Stoppa") { Task { await recording.finishQuestion() } }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
            }
        } else if recording.isWorkingOnQuestion {
            HStack(spacing: 10) {
                ProgressView()
                Text("Skriver ut frågan …").foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
        } else {
            Button {
                questionFocused = false
                Task { await recording.recordQuestion() }
            } label: {
                Label("Spela in frågan", systemImage: "mic")
            }
            .disabled(blocked != nil)
        }
    }

    private var choices: some View {
        NavigationStack {
            List(recording.choices, id: \.self) { choice in
                Button {
                    recording.choose(choice)
                    choosing = false
                } label: {
                    Text(verbatim: choice).foregroundStyle(Color.primary)
                }
            }
            .navigationTitle("Välj ur provet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Avbryt") { choosing = false } }
            }
        }
    }

    // MARK: 2. The answer

    @ViewBuilder
    private var answerStatus: some View {
        if isMakingAnswer {
            HStack(spacing: 10) {
                ProgressView()
                Text("Earmind gör ett svar …")
            }
            .accessibilityElement(children: .combine)
        } else if answer.state == .recording {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    RecordingDot() // iOS's sign for recording
                    Text(answer.reachedLimit ? "Tiden är slut" : "Spelar in").fontWeight(.semibold)
                    Spacer(minLength: 8)
                    LevelMeter(levelDBFS: answer.levelDBFS)
                }
                Text(verbatim: "\(MyAnswerText.clock(answer.elapsed)) av \(MyAnswerText.clock(AnswerRecorder.limit))")
                    .font(.largeTitle.bold())
                    .monospacedDigit()
                    .accessibilityAddTraits(.updatesFrequently)
            }
            .padding(.vertical, 4)
        } else if answer.state == .recorded {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).accessibilityHidden(true)
                Text(verbatim: "Svaret är inspelat · \(MyAnswerText.clock(answer.elapsed))").monospacedDigit()
            }
            Button("Spela in igen") { recording.recordAgain() }
        } else {
            if let problem = recording.problem ?? failure {
                Text(verbatim: problem)
            }
            Text(recording.hasQuestion ? "Mikrofonen startar när du trycker Spela in svaret."
                                       : "Välj eller skriv frågan först. Mikrofonen startar inte förrän du trycker Spela in svaret.")
                .foregroundStyle(.secondary)
        }
    }

    private var failure: String? {
        if case .failed(let message) = answer.state { return message }
        return nil
    }

    // MARK: The one main button

    @ViewBuilder
    private var mainAction: some View {
        if answer.state == .recording {
            MainActionBar(title: "Stoppa", systemImage: "stop.fill") { recording.stopAnswer() }
        } else if answer.state == .recorded || isMakingAnswer {
            MainActionBar(title: isMakingAnswer ? "Gör ett svar …" : "Klar",
                          isBusy: isMakingAnswer,
                          isDisabled: !recording.canFinish) {
                Task { await finish() }
            }
        } else {
            MainActionBar(title: "Spela in svaret", systemImage: "mic.fill",
                          note: recording.hasQuestion ? nil : "Välj eller skriv frågan först.",
                          isDisabled: !recording.canRecordAnswer || blocked != nil) {
                questionFocused = false
                Task { await recording.recordAnswer() }
            }
        }
    }

    private func finish() async {
        let examID = examID
        let draft = await recording.finish { transcript, question in
            await model.compressMyAnswer(transcript: transcript, question: question, examID: examID)
        }
        if let draft { onDone(draft) }
    }
}

/// The red dot that means "recording", as in iOS.
private struct RecordingDot: View {
    var body: some View {
        Circle().fill(Color.red).frame(width: 12, height: 12).accessibilityHidden(true)
    }
}
