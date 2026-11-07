import SwiftUI

/// Language, activation, voice and speed (items 2, 3, 5). Presented as a sheet from the Listening screen.
struct SettingsView: View {
    @Bindable var model: ListeningModel
    @AppStorage("debug.latencyOverlay") private var showsLatencyOverlay = false

    var body: some View {
        Form {
            languageSection
            microphoneSection
            activationSection
            studySection
            voiceSection
            answerSection
            Section("History and memory") {
                NavigationLink("History") { HistoryView(store: model.history) }
                NavigationLink("Memory") { MemoryView(store: model.memory) }
                NavigationLink("Feedback & suggestions") { FeedbackView(model: model) }
            }
            #if DEBUG
            Section("Debug") {
                Toggle("Mock answers (debug, no network)", isOn: $model.useMockAnswers)
                Toggle("Latency overlay", isOn: $showsLatencyOverlay)
                if let latest = model.latency.latest {
                    Text(verbatim: "Last answer: \(latest.summary)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            #endif
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.voices.refreshIfNeeded() }
    }

    private var languageSection: some View {
        Section("Language") {
            Picker("Language", selection: languageBinding) {
                ForEach(TranscriptionLanguage.allCases) { language in
                    Text(language.nativeName).tag(language)
                }
            }
            .pickerStyle(.segmented)
            Toggle("Cloud speech recognition (Scribe)", isOn: cloudBinding)
            if let failure = model.transcription.cloudFailure {
                Text("Using the iPhone's speech recognition: \(failure)")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
            Text("On: audio goes to ElevenLabs for the best recognition. Off: everything stays on this iPhone, with weaker recognition.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var cloudBinding: Binding<Bool> {
        Binding(get: { model.transcription.settings?.useCloud ?? false },
                set: { newValue in Task { await model.transcription.setUseCloud(newValue) } })
    }

    private var languageBinding: Binding<TranscriptionLanguage> {
        Binding(get: { model.transcription.language.selected },
                set: { newValue in Task { await model.transcription.setLanguage(newValue) } })
    }

    private var microphoneSection: some View {
        Section("Microphone") {
            ForEach(ConversationMode.allCases) { mode in
                Picker(modeTitle(mode), selection: microphoneBinding(for: mode)) {
                    Text("AirPods").tag(MicrophoneSource.airPods)
                    Text("iPhone").tag(MicrophoneSource.iPhone)
                }
            }
            Text("AirPods hear your own voice best, but answers play in call quality. iPhone hears other people better and keeps music quality in the AirPods; put it on the table.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func modeTitle(_ mode: ConversationMode) -> LocalizedStringKey {
        switch mode {
        case .standard: "Questions"
        case .prov: "Provläge"
        case .interview: "Intervjuläge"
        case .rizz: "Rizzläge"
        case .social: "Socialt läge"
        }
    }

    private func microphoneBinding(for mode: ConversationMode) -> Binding<MicrophoneSource> {
        Binding(get: { model.microphone.source(for: mode) },
                set: { model.microphone.setSource($0, for: mode) })
    }

    @ViewBuilder
    private var activationSection: some View {
        @Bindable var settings = model.activation.settings
        Section("Activation") {
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
            }
            Text("Auto listens for questions in the room. Hold to ask gives the fewest false answers.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var answerSection: some View {
        @Bindable var answer = model.answers.settings
        Section("Answers") {
            Picker("Answer length", selection: $answer.length) {
                Text("Short").tag(AnswerLength.short)
                Text("Adaptive").tag(AnswerLength.adaptive)
                Text("Detailed").tag(AnswerLength.long)
            }
            .pickerStyle(.segmented)
            Text("Adaptive: one or two sentences for a fact, a developed spoken answer for a topic to understand.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var studySection: some View {
        @Bindable var study = model.study.settings
        Section("Provläge") {
            HStack {
                Text("Silence that ends your turn")
                Slider(value: $study.endpointSilence, in: 0.5...1.5, step: 0.1)
                Text(String(format: "%.1f s", study.endpointSilence))
                    .font(.footnote.monospacedDigit())
                    .frame(width: 44, alignment: .trailing)
            }
            Stepper(value: $study.autoEndMinutes, in: 0...60) {
                if study.autoEndMinutes == 0 {
                    Text("Auto-end after silence: never")
                } else {
                    Text("Auto-end after \(study.autoEndMinutes) min of silence")
                }
            }
            Toggle("Echo cancellation (voiceChat) in Provläge", isOn: $study.useVoiceChatMode)
            Text("Hands-free: speak, pause, get a tutor-style answer, continue. Talking while it speaks interrupts it. Tuned on device.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        @Bindable var modes = model.modeSettings
        Section("Rizzläge and Socialt läge") {
            HStack {
                Text("Your voice is louder than")
                Slider(value: $modes.speakerThresholdDBFS, in: -60 ... -10, step: 1)
                Text(verbatim: "\(Int(modes.speakerThresholdDBFS)) dB")
                    .font(.footnote.monospacedDigit())
                    .frame(width: 52, alignment: .trailing)
            }
            Text("Lumen tells you from the other person by input level. Tuned on device.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var voiceSection: some View {
        @Bindable var voice = model.speaker.settings
        Section("Voice") {
            Toggle("Speak answers", isOn: $voice.speakAnswers)
            if !voice.speakAnswers {
                Text("Silent mode: answers are shown, not spoken.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Picker("Voice", selection: $voice.voice) {
                Text("Apple voice (on device)").tag(VoiceChoice.appleDefault)
                ForEach(model.appleVoices) { choice in
                    Text(choice.name).tag(choice)
                }
                ForEach(model.voices.voices) { choice in
                    Text(choice.name).tag(choice)
                }
            }
            HStack {
                Button("Preview") { model.previewVoice() }
                    .buttonStyle(.bordered)
                Spacer()
                if model.speaker.status != .idle {
                    Text("Speaking…").font(.footnote).foregroundStyle(.secondary)
                }
            }
            HStack {
                Text("Speed")
                Slider(value: $voice.rate, in: 0.5...2.0, step: 0.05) { editing in
                    if !editing { model.speaker.applyRate() }
                }
                Text(String(format: "%.2f×", voice.rate))
                    .font(.footnote.monospacedDigit())
                    .frame(width: 52, alignment: .trailing)
            }
            voiceCatalogStatus
            if let notice = model.speaker.notice {
                Text(notice).font(.footnote).foregroundStyle(.orange)
            }
        }
    }

    @ViewBuilder
    private var voiceCatalogStatus: some View {
        switch model.voices.status {
        case .idle, .loaded:
            if model.voices.voices.isEmpty {
                Text("Premium voices appear here when the voice service is live.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        case .loading:
            HStack(spacing: 8) {
                ProgressView()
                Text("Loading voices…").font(.footnote).foregroundStyle(.secondary)
            }
        case .failed(let message):
            Label("Could not load premium voices: \(message)", systemImage: "exclamationmark.triangle")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}
