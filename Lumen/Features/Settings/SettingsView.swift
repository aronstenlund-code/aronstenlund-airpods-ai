import SwiftUI

/// Language, activation, voice and speed (items 2, 3, 5). Presented as a sheet from the Listening screen.
struct SettingsView: View {
    @Bindable var model: ListeningModel
    @AppStorage("debug.latencyOverlay") private var showsLatencyOverlay = false

    var body: some View {
        Form {
            languageSection
            activationSection
            voiceSection
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
        }
    }

    private var languageBinding: Binding<TranscriptionLanguage> {
        Binding(get: { model.transcription.language.selected },
                set: { newValue in Task { await model.transcription.setLanguage(newValue) } })
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
