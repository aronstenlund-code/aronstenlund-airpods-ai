import SwiftUI

/// Language, activation, voice and speed (items 2, 3, 5). Presented as a sheet from the Listening screen.
struct SettingsView: View {
    @Bindable var model: ListeningModel
    var diagnostics: DiagnosticsModel?
    @Environment(AppearanceSettings.self) private var appearance
    @AppStorage("debug.latencyOverlay") private var showsLatencyOverlay = false
    /// A13.1: the technical settings are folded away; the choice is remembered.
    @AppStorage("settings.showsAdvanced") private var showsAdvanced = false

    /// A13.1: what a student changes first, at the top; the technical parts folded under "Avancerat"; licences and
    /// technical explanations in "Om appen". Nothing is removed.
    var body: some View {
        Form {
            // Vanliga
            voiceSection
            answerSection
            Section {
                NavigationLink("Röstkommandon") { VoiceCommandsView(store: model.phrases, music: model.music, voice: model.speaker.settings, tips: model.tips) }
                NavigationLink("Minne") { MemoryView(store: model.memory, commands: model.commands, preferences: model.preferences, paces: model.paces) }
            }
            studyProfileSection
            appearanceSection
            languageSection
            Section {
                NavigationLink("Integritet och samtycke") {
                    ConsentView(mode: .review(grantedAt: model.consent.record?.grantedAt) {
                        model.isShowingSettings = false
                        Task { await model.withdrawConsent() }
                    })
                }
            }
            Section("Mer") {
                if model.canSaveNote {
                    Button("Spara samtalet som anteckning") { model.saveNote() }
                }
                NavigationLink("Anteckningar") { NotesView(store: model.notes) }
                NavigationLink("Historik") { HistoryView(store: model.history) }
                if let cards = model.studyCards {
                    NavigationLink("Studiekort") { StudyCardsView(store: cards) }
                }
                NavigationLink("Förberedelser") { PrepView(store: model.prep, goals: model.goals) }
                NavigationLink("Egna kommandon") { CommandsView(store: model.commands) }
                Button("Provsession, ladda upp ett prov") {
                    model.isShowingSettings = false
                    model.isShowingExamSetup = true
                }
                NavigationLink("Feedback och förslag") { FeedbackView(model: model) }
                NavigationLink("Om appen") { AboutView() }
            }
            // Avancerat
            Section {
                Button {
                    withAnimation { showsAdvanced.toggle() }
                } label: {
                    HStack {
                        Text("Avancerat").foregroundStyle(LumenColor.ink)
                        Spacer()
                        Image(systemName: showsAdvanced ? "chevron.up" : "chevron.down").foregroundStyle(.secondary)
                    }
                }
            } footer: {
                Text("Mikrofon, pauser, känslighet, taligenkänning, röstprofil, kalibrering och diagnostik.")
            }
            if showsAdvanced {
                microphoneSection
                activationSection
                recognitionSection
                studySection
                if let speakers = model.speakers {
                    VoiceProfileSection(model: model, speakers: speakers)
                }
                Section("Diagnostik") {
                    NavigationLink("Rå transkription och svar") { RawTranscriptView(model: model) }
                    if let diagnostics {
                        NavigationLink("Diagnostik") { DiagnosticsView(model: diagnostics) }
                    }
                }
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
        .lumenForm() // D86: the new look, no capitals over headings
        .navigationTitle("Inställningar")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.voices.refreshIfNeeded() }
    }

    /// D86: light, dark or as the iPhone; handwriting for the user's questions.
    private var appearanceSection: some View {
        @Bindable var appearance = appearance
        return Section {
            Picker("Utseende", selection: $appearance.appearance) {
                ForEach(AppearanceSettings.Appearance.allCases, id: \.self) { Text($0.title).tag($0) }
            }
        } header: {
            Text("Utseende")
        } footer: {
            Text("Som standard följer Lumen iPhonens ljusa eller mörka läge.")
        }
    }

    private var languageSection: some View {
        Section("Språk") {
            Picker("Språk", selection: languageBinding) {
                ForEach(TranscriptionLanguage.allCases) { language in
                    Text(language.nativeName).tag(language)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    /// A13.1: Scribe, the local voice detector and the wearer focus (Avancerat).
    private var recognitionSection: some View {
        Section("Taligenkänning") {
            Toggle("Cloud speech recognition (Scribe)", isOn: cloudBinding)
            if let failure = model.transcription.cloudFailure {
                Text("Using the iPhone's speech recognition: \(failure)")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
            Text("On: audio goes to ElevenLabs for the best recognition. Off: everything stays on this iPhone, with weaker recognition.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            if model.transcription.settings?.useCloud == true {
                Toggle("Lokal röstdetektor före Scribe", isOn: vadBinding)
                Text(vadStatusText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Toggle("Bara min röst i Provläge och Frågor", isOn: focusBinding)
                Text("Andra som pratar i rummet hörs svagare i AirPods. Deras tal skickas inte, så din fråga blir klar när du tystnar.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func pauseBinding(_ target: ConversationMode) -> Binding<Double> {
        Binding(get: { model.modeSettings.pause(for: target) },
                set: { model.setPause($0, for: target) })
    }

    static func modeName(_ mode: ConversationMode) -> String {
        switch mode {
        case .standard: "Frågor"
        case .prov: "Provläge"
        case .interview: "Intervju"
        case .social: "Socialt"
        case .rizz: "Rizz"
        }
    }

    /// D83: the Provläge profile, the same answers as the first-start questions.
    @ViewBuilder
    private var studyProfileSection: some View {
        @Bindable var store = model.studyProfile
        Section {
            // A22 (Deangelo): no "Inget prov just nu" switch; exams are added and removed on Start.
            DatePicker("Provdatum", selection: examBinding, displayedComponents: .date)
                .environment(\.locale, Locale(identifier: "sv_SE"))
            Picker("Årskurs", selection: $store.profile.grade) {
                Text("Inte angivet").tag(nil as StudyProfile.Grade?)
                ForEach(StudyProfile.Grade.allCases, id: \.self) { Text(StudyProfile.gradeName($0)).tag(StudyProfile.Grade?.some($0)) }
            }
            TextField("Kurs, t.ex. Matematik 1c", text: $store.profile.course)
            TextField("Ämne", text: $store.profile.subject)
            Picker("Kontrollfrågor", selection: $store.profile.checkQuestions) {
                Text("Inte angivet").tag(nil as StudyProfile.CheckQuestions?)
                ForEach(StudyProfile.CheckQuestions.allCases, id: \.self) { Text(StudyProfile.checkName($0)).tag(StudyProfile.CheckQuestions?.some($0)) }
            }
            Picker("Förklaringar", selection: $store.profile.explanations) {
                Text("Inte angivet").tag(nil as StudyProfile.Explanations?)
                ForEach(StudyProfile.Explanations.allCases, id: \.self) { Text(StudyProfile.explanationName($0)).tag(StudyProfile.Explanations?.some($0)) }
            }
            Button("Spara i minnet") { model.studyProfileChanged() }
            Button("Visa frågorna igen vid nästa start") { store.profile.onboarded = false }
        } header: {
            Text("Prov")
        } footer: {
            Text(model.headMotion.isAvailable
                 ? "Ja–nej-frågor kan besvaras med en nick eller en skakning med huvudet. Du kan också säga \"Lumen, korta förklaringar\" eller \"Lumen, provet är på fredag\"."
                 : "Dina AirPods stöder inte huvudrörelser just nu: svara på ja–nej-frågor med rösten. Du kan också säga \"Lumen, korta förklaringar\" eller \"Lumen, provet är på fredag\".")
        }
    }

    private var examBinding: Binding<Date> {
        Binding(get: { model.studyProfile.profile.examDate ?? Date() },
                set: {
                    model.studyProfile.profile.examDate = Calendar.current.startOfDay(for: $0)
                    model.studyProfile.profile.noExam = false // A22: a date means there is an exam
                })
    }

    /// A10: the wearer focus in front of Scribe.
    private var focusBinding: Binding<Bool> {
        Binding(get: { model.transcription.settings?.focusOnWearer ?? false },
                set: { newValue in Task { await model.transcription.setFocusOnWearer(newValue) } })
    }

    private var vadBinding: Binding<Bool> {
        Binding(get: { model.transcription.settings?.useLocalVAD ?? false },
                set: { newValue in Task { await model.transcription.setUseLocalVAD(newValue) } })
    }

    /// D78: what the local detector is doing, including the one-time model download.
    private var vadStatusText: String {
        switch model.transcription.vad?.status {
        case .loading: "Hämtar röstdetektorn (Silero, några MB, en gång)…"
        case .ready: "Bara tal skickas till Scribe; tystnad och brus stannar på telefonen."
        case .unavailable(let reason): "Röstdetektorn kunde inte laddas (\(reason)). Allt ljud går till Scribe."
        case .idle, nil: "Laddas när du börjar lyssna."
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
            Toggle("Ekoreducering i iPhonens högtalare", isOn: echoBinding)
            Toggle("Pausa när AirPods kopplas bort", isOn: Binding(get: { model.microphone.pauseWhenAirPodsLost },
                                                                  set: { model.microphone.pauseWhenAirPodsLost = $0 }))
            Text("Av: Lumen lyssnar vidare och svaren hörs i telefonens högtalare.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text("När ljudet går ut i iPhonens egen högtalare hör mikrofonen annars Lumen. Med AirPods eller hörlurar används den aldrig, så mikrofonen behåller sin kvalitet.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var echoBinding: Binding<Bool> {
        Binding(get: { model.microphone.echoCancellation },
                set: { newValue in
                    model.microphone.echoCancellation = newValue
                    Task { await model.echoCancellationChanged() }
                })
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
        Section("Questions") {
            Picker("Sensitivity", selection: $settings.sensitivity) {
                Text("Low").tag(GateSensitivity.low)
                Text("Medium").tag(GateSensitivity.medium)
                Text("High").tag(GateSensitivity.high)
            }
            Text("Every mode is hands-free: Lumen listens for questions in the room. Higher sensitivity answers more, and more often by mistake. The text field is the fallback.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var answerSection: some View {
        @Bindable var answer = model.answers.settings
        Section("Svarslängd") {
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
        Section {
            ForEach(ConversationMode.allCases) { target in
                HStack {
                    Text(Self.modeName(target))
                    Slider(value: pauseBinding(target), in: ModeSettings.pauseRange, step: 0.1)
                    Text(String(format: "%.1f s", model.modeSettings.pause(for: target)))
                        .font(.footnote.monospacedDigit())
                        .frame(width: 44, alignment: .trailing)
                }
            }
        } header: {
            Text("Paus innan Lumen svarar")
        } footer: {
            Text("Hur länge du ska vara tyst innan svaret läses upp. Lumen börjar arbeta på svaret redan när meningen är hörd, så kortare paus ger snabbare svar men fler avbrutna försök.")
        }
        Section("Provläge") {
            Stepper(value: $study.autoEndMinutes, in: 0...60) {
                if study.autoEndMinutes == 0 {
                    Text("Auto-end after silence: never")
                } else {
                    Text("Auto-end after \(study.autoEndMinutes) min of silence")
                }
            }
            Text("Hands-free: speak, pause, get a tutor-style answer, continue. Talking while it speaks interrupts it. Tuned on device.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        studyProfileSection
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
        Section {
            ForEach([ConversationMode.social, .rizz]) { mode in
                VStack(alignment: .leading, spacing: 6) {
                    Text(mode == .rizz ? "Rizzläge" : "Socialt läge")
                        .font(.subheadline.weight(.semibold))
                    if let calibration = modes.calibration(for: mode) {
                        Text(calibration)
                            .font(.footnote)
                            .textSelection(.enabled)
                        Button("Återställ", role: .destructive) {
                            modes.resetCalibration(for: mode)
                        }
                        .font(.footnote)
                    } else {
                        Text("Inget ännu")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 2)
            }
        } header: {
            Text("Kalibrering")
        } footer: {
            Text("Under en session: säg \"\(WakeWord.name), lite mindre kaxig\" eller \"\(WakeWord.name), mer skämt\". Lumen kommer ihåg det här på telefonen och skickar det med varje förslag. \"\(WakeWord.name), ge mig tre\" ger fler förslag en gång.")
        }
    }

    @ViewBuilder
    private var voiceSection: some View {
        @Bindable var voice = model.speaker.settings
        Section("Röst och hastighet") {
            Toggle("Läs upp svaren", isOn: $voice.speakAnswers)
            if !voice.speakAnswers {
                Text("Tyst läge: svaren visas men läses inte upp.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Picker("Röst", selection: $voice.voice) {
                Text("iPhonens röst").tag(VoiceChoice.appleDefault)
                ForEach(model.appleVoices) { choice in
                    Text(choice.name).tag(choice)
                }
                ForEach(model.voices.voices) { choice in
                    Text(choice.name).tag(choice)
                }
            }
            // A22 (Deangelo): a plain row, not a floating chip.
            Button {
                model.previewVoice()
            } label: {
                HStack {
                    Text("Provlyssna")
                    Spacer()
                    if model.speaker.status != .idle {
                        Text("Pratar …").font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
            // A22: words, not "1.00×".
            Picker("Hastighet", selection: Binding(get: { SpeedChoice.nearest(to: voice.rate) },
                                                   set: { voice.rate = $0.rate; model.speaker.applyRate() })) {
                ForEach(SpeedChoice.allCases, id: \.self) { Text($0.title).tag($0) }
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

/// A22 (Deangelo): the voice speed in words. The stored rate stays a number (0.5…2.0); A20's learned pace multiplies it.
enum SpeedChoice: CaseIterable, Hashable {
    case slow, normal, fast

    var title: String {
        switch self {
        case .slow: "Lugn"
        case .normal: "Normal"
        case .fast: "Snabb"
        }
    }

    var rate: Float {
        switch self {
        case .slow: 0.85
        case .normal: 1.0
        case .fast: 1.2
        }
    }

    static func nearest(to rate: Float) -> SpeedChoice {
        allCases.min { abs($0.rate - rate) < abs($1.rate - rate) } ?? .normal
    }
}
