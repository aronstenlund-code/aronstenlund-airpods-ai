import Foundation
import Observation

/// Drives the Listening screen (MVP items 1–9). No business logic in views.
@MainActor
@Observable
final class ListeningModel: TranscriptSink, AnswerSink {
    let controller: SessionController
    let consent: any ConsentStoring
    let transcription: TranscriptionCoordinator
    let activation: ActivationController
    let answers: AnswerEngine
    let speaker: Speaker
    let voices: VoiceCatalog
    let notes: NotesStore
    let prep: PrepStore
    /// Historik and Minne (D49/D56), on this phone only.
    let history: HistoryStore
    let memory: MemoryStore
    /// Mikrofon per mode (D55).
    let microphone: MicrophoneSettings
    /// What the session is for: decides the microphone.
    private(set) var mode: ConversationMode = .standard
    /// The mode picker on the Listening screen.
    var selectedMode: ConversationMode = .standard
    /// Intervjuläge and Rizzläge setup.
    let modeSettings: ModeSettings
    /// The running Rizzläge session. Gone when it ends, and the words with it.
    private(set) var rizz: RizzSession?
    /// Intervjuläge alternates: the interviewer asks, then the user answers.
    private var interviewerSpeaksNext = true
    var isShowingInterviewSetup = false
    var isShowingRizzStart = false
    /// A microphone comparison is running: what is said is a test sentence, never a question.
    private var isComparing = false
    /// Course goals and personal keyword commands (D37).
    let goals: GoalsStore
    let commands: CommandStore
    /// "Sparade kommandot …" after a spoken save, shown once.
    private(set) var commandNotice: String?
    private let warmer: BackendWarmer?
    private let activity: (any ListeningActivityPresenting)?
    /// Provläge (D36): hands-free tutor session.
    let study: StudySessionController
    /// Why Provläge ended, shown once.
    private(set) var studyNotice: String?
    /// Per-answer latency budget (item 7), shown in the debug overlay.
    let latency = LatencyLog()
    private(set) var conversation = Conversation()
    /// The most recent question handed to the answer engine.
    private(set) var pendingQuestion: ActivationRequest?
    /// One-line notice under the answers: "not a question", failures, offline.
    private(set) var answerNotice: String?
    /// When the session was last saved as a note (item 8).
    private(set) var noteSavedAt: Date?
    var isShowingPrivacy = false
    var isShowingSettings = false
    var isShowingNotes = false
    var isShowingPrep = false
    var isShowingCommands = false
    var isShowingDiagnostics = false
    /// Text mode (item 6): the question being typed. Works without the microphone.
    var draftQuestion = ""
    private var flushTask: Task<Void, Never>?

    var state: SessionState { controller.state }
    var isListening: Bool { controller.state.isListening }
    var isActiveSession: Bool { controller.isActiveSession }
    var canResume: Bool { controller.canResume }
    var lastError: String? { controller.lastError }
    var level: AudioLevel.Reading { controller.level }
    var isHolding: Bool { activation.isHolding }
    var language: TranscriptionLanguage { transcription.language.selected }
    var isAnswering: Bool {
        if case .answering = answers.status { return true }
        return false
    }
    var useMockAnswers: Bool {
        get { answers.useMock }
        set { answers.useMock = newValue }
    }
    /// Installed Apple voices for the selected language (settings picker).
    var appleVoices: [VoiceChoice] { AppleTTSProvider.installedVoices(for: language) }
    var canSaveNote: Bool { !conversation.answers.isEmpty }

    /// "AirPods Pro · HFP" — which microphone is live, from the session snapshot.
    var routeSummary: String? {
        guard let snapshot = controller.snapshot, let input = snapshot.inputs.first else { return nil }
        return "\(input.portName) · \(snapshot.transport)"
    }

    init(controller: SessionController, consent: any ConsentStoring,
         transcription: TranscriptionCoordinator, activation: ActivationController,
         answers: AnswerEngine, speaker: Speaker, voices: VoiceCatalog,
         notes: NotesStore, prep: PrepStore, warmer: BackendWarmer? = nil,
         activity: (any ListeningActivityPresenting)? = nil, study: StudySessionController? = nil,
         goals: GoalsStore? = nil, commands: CommandStore? = nil,
         history: HistoryStore? = nil, memory: MemoryStore? = nil, microphone: MicrophoneSettings? = nil,
         modeSettings: ModeSettings? = nil) {
        self.controller = controller
        self.consent = consent
        self.transcription = transcription
        self.activation = activation
        self.answers = answers
        self.speaker = speaker
        self.voices = voices
        self.notes = notes
        self.prep = prep
        self.history = history ?? HistoryStore()
        self.memory = memory ?? MemoryStore()
        self.microphone = microphone ?? MicrophoneSettings()
        self.modeSettings = modeSettings ?? ModeSettings()
        self.goals = goals ?? GoalsStore()
        self.commands = commands ?? CommandStore()
        self.warmer = warmer
        self.activity = activity
        self.study = study ?? StudySessionController(settings: StudySettings(), session: controller)
        self.study.onEvent = { [weak self] event in self?.studyEvent(event) }
        controller.onStateChanged = { [weak self] state in self?.sessionStateChanged(state) }
        voices.onLoaded = { [weak speaker] voices, defaultID in
            speaker?.settings.reconcile(with: voices, defaultID: defaultID)
        }
        activation.onActivate = { [weak self] request in self?.activated(request) }
        answers.sink = self
        speaker.onSentenceStarted = { [weak self] provider in
            guard let self else { return }
            self.latency.markFirstSpeech(provider: provider)
            if self.study.isActive {
                // Our own voice is playing: gate the recogniser, watch the level for a barge-in (D36).
                self.study.speechStarted()
                self.transcription.setInputGated(true)
            }
        }
        speaker.onFinished = { [weak self] in self?.speechFinished() }
        refreshKeyterms()
        prep.onChange = { [weak self] in self?.refreshKeyterms() }
    }

    // MARK: - User actions

    /// The Listening screen opened, the app came back, or listening starts: wake the backend (D31) and load the
    /// voices (D23), which also signs in ahead of the first question. Quiet when offline; retried next time.
    func prepareBackend() async {
        history.purgeExpired()
        memory.purgeExpired()
        guard !answers.useMock else { return }
        Task { await warmer?.warm() }
        await voices.refreshIfNeeded()
    }

    /// Primary button: start when idle/error, stop when listening or paused.
    func toggleListening() async {
        if isActiveSession {
            await stopListening()
        } else {
            await startListening()
        }
    }

    func startListening() async {
        // Consent is checked here as well as in the UI: no microphone without a current consent record.
        guard consent.isGranted else {
            controller.log("Start refused: no consent")
            return
        }
        Task { await prepareBackend() }
        refreshKeyterms()
        await useMicrophone(for: mode)
        await controller.start()
        logMicrophone()
    }

    /// Selects the microphone for `mode`. A running session moves to the new route at once (D55).
    private func useMicrophone(for mode: ConversationMode) async {
        await use(config: microphone.source(for: mode).captureConfig(echoCancellation: mode == .prov && study.settings.useVoiceChatMode))
    }

    private func use(config: CaptureConfig) async {
        guard config != controller.config else { return }
        let wasActive = isActiveSession
        if wasActive { await controller.stop() }
        controller.config = config
        if wasActive {
            await controller.start()
            logMicrophone()
        }
    }

    private func logMicrophone() {
        controller.log("Microphone \(microphone.source(for: mode).rawValue) for \(mode.rawValue) · \(controller.config.rawValue) · \(routeSummary ?? "no route")")
    }

    /// The phone listens to other people best from a table, not from a pocket (D55).
    var usesPhoneMicrophone: Bool { controller.config.inputPreference == .builtInMic }
    var recognizerName: String {
        if case .running(let engine) = transcription.status { return engine.displayName }
        return "none"
    }

    // MARK: - Microphone comparison (D55)

    /// Starts listening on `source`; returns where the run begins in the transcript. Nil without consent.
    func startComparison(_ source: MicrophoneSource) async -> Int? {
        guard consent.isGranted else { return nil }
        isComparing = true
        await use(config: source.captureConfig())
        if !isListening {
            if canResume { await resume() } else { await controller.start() }
        }
        guard isListening else {
            isComparing = false
            return nil
        }
        return conversation.finalSegments.count
    }

    /// Everything heard since `mark`, including words the recogniser has not finalised.
    func finishComparison(from mark: Int) -> String {
        isComparing = false
        var parts = conversation.finalSegments.dropFirst(mark).map(\.text)
        if let partial = conversation.partial { parts.append(partial.text) }
        return parts.joined(separator: " ")
    }

    /// Command keywords first: they decide what happens, and Scribe takes a limited number of keyterms (D44).
    private func refreshKeyterms() {
        transcription.setContextualStrings(commands.commands.map(\.keyword) + prep.sttTerms)
    }

    func stopListening() async {
        flushTask?.cancel()
        answers.cancel()
        speaker.interrupt()
        conversation.cancelAnswer()
        await controller.stop()
    }

    func resume() async {
        await controller.resume()
    }

    /// One tap to switch to music and back (D33): screen button, Live Activity and Control. Never starts a
    /// session: the microphone is only switched on from the app.
    func togglePause() async {
        if isListening {
            await controller.pause()
        } else if canResume {
            await controller.resume()
        }
    }

    private func sessionStateChanged(_ state: SessionState) {
        if state != .listening, study.isActive {
            // Paused, stopped or failed: the hands-free session cannot continue without the microphone.
            study.stop()
            transcription.setInputGated(false)
            handsFreeEnded()
        }
        switch state {
        case .listening:
            showActivity()
        case .paused:
            // Whoever has the audio now keeps it: no speech may restart the engine behind their back.
            flushTask?.cancel()
            answers.cancel()
            speaker.interrupt()
            conversation.cancelAnswer()
            showActivity()
        case .idle, .error:
            conversation.clearTranscript()
            activity?.end()
        }
    }

    private func showActivity() {
        activity?.show(ListeningActivityAttributes.ContentState(isPaused: !isListening, suggestions: rizz?.suggestions ?? [],
                                                                currentSuggestion: rizz?.index ?? 0))
    }

    /// Stops the microphone, forgets the session's transcript and clears the consent record; the consent
    /// screen is shown again by `RootView`.
    func withdrawConsent() async {
        await stopListening()
        conversation.clear()
        pendingQuestion = nil
        answerNotice = nil
        consent.revoke()
    }

    func clearHistory() {
        answers.cancel()
        speaker.interrupt()
        latency.clear()
        conversation.clear()
        pendingQuestion = nil
        answerNotice = nil
        noteSavedAt = nil
        commandNotice = nil
    }

    func previewVoice() {
        speaker.preview(speaker.settings.voice, language: language)
    }

    // MARK: - Provläge (D36)

    /// One tap starts the hands-free session (starting the microphone if needed), one tap ends it.
    func toggleStudyMode() async {
        if study.isActive {
            endStudy(bySilence: false)
        } else {
            await startStudy()
        }
    }

    /// The Listening screen's mode button. Intervjuläge and Rizzläge go through their start screens first.
    func toggleSelectedMode() async {
        if study.isActive {
            endStudy(bySilence: false)
            return
        }
        switch selectedMode {
        case .standard: await toggleListening()
        case .prov: await startStudy()
        case .interview: isShowingInterviewSetup = true
        case .rizz: isShowingRizzStart = true
        }
    }

    func startStudy() async {
        await startHandsFree(.prov)
    }

    func startHandsFree(_ newMode: ConversationMode) async {
        guard consent.isGranted else {
            controller.log("Hands-free \(newMode.rawValue) refused: no consent")
            return
        }
        studyNotice = nil
        mode = newMode
        await useMicrophone(for: newMode)
        if !isListening {
            if canResume { await resume() } else { await startListening() }
            guard isListening else { return }
        }
        answers.cancel()
        speaker.interrupt()
        conversation.cancelAnswer()
        interviewerSpeaksNext = true
        if newMode == .rizz {
            rizz = RizzSession(style: modeSettings.rizzStyle)
            study.stallSilence = Self.stallSilence
            controller.playback.speechVolume = Self.rizzVolume
        } else {
            study.stallSilence = nil
        }
        study.start()
        controller.log("Hands-free \(newMode.rawValue) started")
    }

    /// ~4 s of silence asks for a way to carry on (D43).
    static let stallSilence: TimeInterval = 4
    /// Quiet enough to say under one's breath, not loud enough to carry (D43). Tuned on device.
    static let rizzVolume: Float = 0.6

    /// Own lines reach Historik only from the AirPods mic: on the iPhone the level tag cannot tell the people on
    /// either side of the table apart, and other people's words are never saved (D56).
    private var ownLinesAreReliable: Bool { microphone.source(for: mode) == .airPods }

    private func handsFreeEnded() {
        if let session = rizz, !session.offered.isEmpty {
            let lines = ownLinesAreReliable ? session.ownLines.joined(separator: "\n") : ""
            history.record(HistoryEntry(question: lines.isEmpty ? nil : lines, answer: "",
                                        summary: "Rizzläge, stil \(session.style.rawValue): \(session.offered.count) förslag.",
                                        suggestions: session.offered))
        }
        rizz = nil
        controller.playback.speechVolume = 1
        mode = .standard
    }

    /// Ends the session. After the silence timeout the microphone is released too ("sparläge").
    func endStudy(bySilence: Bool) {
        guard study.isActive || bySilence else { return }
        study.stop()
        handsFreeEnded()
        showActivity()
        transcription.setInputGated(false)
        if bySilence {
            studyNotice = "Ended after \(study.settings.autoEndMinutes) min of silence; the microphone was switched off."
            controller.log("Hands-free session auto-ended after silence")
            Task { await stopListening() }
        } else {
            controller.log("Provläge ended by the user")
        }
    }

    private func studyEvent(_ event: StudyEvent) {
        switch event {
        case .turnStarted:
            break
        case .endOfTurn(let text):
            switch mode {
            case .interview: interviewTurn(text)
            case .rizz: rizzTurn(text)
            case .standard, .prov: activated(ActivationRequest(query: text, trigger: .tutor, language: language))
            }
        case .stalled:
            if let session = rizz { requestSuggestions(trigger: session.hasConversation ? "stall" : "opener") }
        case .bargeIn:
            controller.log("Provläge: barge-in — stopping the answer")
            answers.cancel()
            speaker.interrupt()
            conversation.cancelAnswer()
            latency.end()
            transcription.setInputGated(false)
        case .autoEnded:
            endStudy(bySilence: true)
        }
    }

    // MARK: - Intervjuläge (D42)

    private func interviewTurn(_ text: String) {
        // "klar" asks the backend for the summary, which only happens on a question turn.
        let isDone = text.lowercased().trimmingCharacters(in: .punctuationCharacters) == "klar"
        let isQuestion = interviewerSpeaksNext || isDone
        interviewerSpeaksNext.toggle()
        let trigger: ActivationTrigger = !isQuestion && ownLinesAreReliable ? .tutor : .overheard
        activated(ActivationRequest(query: text, trigger: trigger, language: language),
                  persona: PersonaRequest(persona: "interview", setup: modeSettings.interviewSetup,
                                          turn: isQuestion ? "question" : "user_answer"))
    }

    /// Likely questions and model answers from the role or job ad. Long, so it is shown, not spoken.
    func prepareInterview() {
        activated(ActivationRequest(query: language == .swedish ? "Förbered mig inför intervjun" : "Prepare me for the interview",
                                    trigger: .interviewPrep, language: language),
                  persona: PersonaRequest(persona: "interview", setup: modeSettings.interviewSetup))
    }

    // MARK: - Rizzläge (D43)

    private func rizzTurn(_ text: String) {
        let speaker = RizzSpeaker.tag(levelDBFS: study.lastTurnLevelDBFS, thresholdDBFS: modeSettings.speakerThresholdDBFS)
        controller.log("Rizzläge: turn tagged \(speaker.rawValue) · level \(study.lastTurnLevelDBFS ?? -99) dBFS · threshold \(modeSettings.speakerThresholdDBFS)")
        study.resumeListening() // the room goes on while the suggestions are being made
        guard var session = rizz else { return }
        if speaker == .user, session.usesSuggestion(text) {
            modeSettings.countUse(of: session.style)
        }
        session.add(speaker, text: text, at: Date())
        rizz = session
        if speaker == .other {
            requestSuggestions(trigger: "other_spoke")
        }
    }

    private func requestSuggestions(trigger: String) {
        guard let session = rizz else { return }
        let request = ActivationRequest(query: "", trigger: .rizz, language: language)
        let social = SocialRequest(style: session.style.rawValue, trigger: trigger, transcript: session.transcript,
                                   interests: modeSettings.interests, profile: modeSettings.rizzProfile)
        pendingQuestion = request
        latency.begin(request)
        answers.answer(request, context: AnswerContext(memories: memory.backendItems()),
                       persona: PersonaRequest(persona: "social", social: social))
    }

    func answerSuggestions(_ options: [String]) {
        latency.markFirstText(provider: answers.activeProvider.name)
        rizz?.offer(options)
        showActivity()
        speakSuggestion()
    }

    /// "nästa", or the button on the Live Activity.
    func nextSuggestion() {
        rizz?.next()
        showActivity()
        speakSuggestion()
    }

    /// Only in a pause, never over anyone. A missed moment stays on the Live Activity.
    private func speakSuggestion() {
        guard let line = rizz?.current, !study.someoneIsTalking(), !speaker.isSpeaking else { return }
        speaker.enqueue(line, language: language)
    }

    private func speechFinished() {
        guard study.isActive else { return }
        transcription.setInputGated(false)
        study.resumeListening()
    }

    /// The answer produced no speech (silent mode, empty answer): back to listening right away.
    private func studyAnswerEnded() {
        guard study.isActive, mode != .rizz, !speaker.hasPendingSpeech else { return }
        transcription.setInputGated(false)
        study.resumeListening()
    }

    /// Item 8: saves the session's answers as a local note.
    @discardableResult
    func saveNote() -> Note? {
        guard let note = notes.save(conversation, language: language) else {
            controller.log("Save note: nothing to save")
            return nil
        }
        noteSavedAt = note.createdAt
        controller.log("Note saved: \(note.title)")
        return note
    }

    // MARK: - Activation (item 3)

    func pressPushToTalk() {
        guard isListening else { return }
        flushTask?.cancel()
        activation.beginPushToTalk(conversation: conversation)
    }

    func releasePushToTalk() {
        transcription.commit()
        let fired = activation.endPushToTalk(conversation: conversation, language: language)
        guard !fired, activation.isAwaitingFinal else { return }
        let grace = activation.settings.releaseGrace
        flushTask?.cancel()
        flushTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(grace))
            guard let self, !Task.isCancelled else { return }
            self.activation.flushPushToTalk(conversation: self.conversation, language: self.language)
        }
    }

    func askAboutLast() {
        if !activation.answerLast(conversation: conversation, language: language) {
            controller.log("Ask about last: nothing final in the transcript yet")
        }
    }

    /// Text mode (item 6): typed questions take the same path as spoken ones (`mode: text` to the backend).
    func submitText(_ text: String) {
        activation.submitText(text, language: language)
    }

    var canSendDraft: Bool { !draftQuestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    func sendDraft() {
        guard canSendDraft else { return }
        let text = draftQuestion
        draftQuestion = ""
        submitText(text)
    }

    private func activated(_ request: ActivationRequest, persona: PersonaRequest? = nil) {
        pendingQuestion = request
        answerNotice = nil
        // A new question interrupts the current answer and its speech (assignment item 5).
        speaker.interrupt()
        latency.begin(request)
        controller.log("Activation (\(request.trigger.rawValue)): \(request.query)")
        // Provläge sends the whole session's memory (the backend keeps the last 6 pairs).
        let qaLimit = study.isActive ? AnswerContext.qaLimit : 3
        let matched = commands.matches(in: request.query)
        if !matched.isEmpty {
            controller.log("Commands matched: \(matched.map(\.keyword).joined(separator: ", "))")
        }
        let context = AnswerContext(transcript: conversation.recentText(seconds: 60),
                                    recentQA: conversation.recentQA(limit: qaLimit),
                                    prepTerms: prep.backendTerms,
                                    goals: goals.compact,
                                    commands: matched.map { AnswerContext.Command(keyword: $0.keyword, instruction: $0.instruction) },
                                    memories: memory.backendItems())
        answers.answer(request, context: context, persona: persona)
    }

    // MARK: - AnswerSink (item 4)

    func answerStarted(_ request: ActivationRequest, source: String) {
        if request.trigger == .rizz { return } // suggestions have no answer of their own
        conversation.beginAnswer(question: request.query, source: source, at: request.createdAt,
                                 isOwnQuestion: request.trigger.isUsersOwnWords)
        if study.isActive { study.answerStarted() }
    }

    func answerQuestionReconstructed(_ question: String) {
        conversation.setAnswerQuestion(question)
    }

    func answerDelta(_ text: String) {
        latency.markFirstText(provider: answers.activeProvider.name)
        conversation.appendAnswerText(text)
    }

    func answerSentence(_ sentence: String) {
        if case .paused = state { return } // a typed question while paused is shown, not spoken over the music
        if pendingQuestion?.trigger == .interviewPrep { return }
        speaker.enqueue(sentence, language: pendingQuestion?.language ?? language)
    }

    func answerCompleted(latencyMs: Double?, done: AnswerDone?) {
        if let turn = conversation.completeAnswer(latencyMs: latencyMs) {
            history.record(HistoryEntry(createdAt: turn.createdAt, question: turn.isOwnQuestion ? turn.question : nil,
                                        answer: turn.answer, summary: done?.summary))
        }
        if let fact = done?.memoryAdd {
            memory.add(fact)
        }
        if let latencyMs {
            controller.log("Answer · first text after \(Int(latencyMs)) ms" + (done?.usage?.model.map { " · \($0)" } ?? ""))
        }
        studyAnswerEnded()
    }

    func answerSkipped(_ request: ActivationRequest) {
        latency.end()
        conversation.cancelAnswer()
        answerNotice = "Not a question — no answer (auto mode)"
        controller.log("Auto: backend says not a question: \(request.query)")
        studyAnswerEnded()
    }

    func answerFailed(_ message: String, wantsFallback: Bool) {
        latency.end()
        conversation.cancelAnswer()
        answerNotice = message
        controller.log("Answer failed: \(message)" + (wantsFallback ? " · fallback requested (on-device engine not available on this iPhone)" : ""))
        studyAnswerEnded()
    }

    // MARK: - TranscriptSink (fed by TranscriptionCoordinator)

    func receivePartialTranscript(_ text: String, at date: Date = Date()) {
        conversation.updatePartial(text, at: date, overlapsPlayback: controller.playback.isSpeaking)
        if study.isActive { study.transcriptPartial(text) }
    }

    func receiveFinalTranscript(_ text: String, at date: Date = Date()) {
        let before = conversation.finalSegments.count
        conversation.finalize(text, at: date, overlapsPlayback: controller.playback.isSpeaking)
        guard conversation.finalSegments.count > before, let segment = conversation.finalSegments.last else { return }
        if isComparing { return }
        if rizz != nil, RizzCommand.isNext(segment.text) {
            study.resumeListening()
            nextSuggestion()
            return
        }
        if !segment.overlapsPlayback, saveSpokenCommand(segment.text) {
            return // "spara kommando …" is handled on the phone, never sent as a question
        }
        if study.isActive {
            // Provläge decides turns by silence, not by the question gate.
            study.transcriptFinal(segment.text, at: date)
            return
        }
        activation.segmentFinalized(segment, conversation: conversation, language: language,
                                    isPlaybackSpeaking: controller.playback.isSpeaking, now: date)
    }

    /// Voice-created command (D37): "spara kommando <ord>: <instruktion>". Confirms by voice.
    @discardableResult
    func saveSpokenCommand(_ text: String) -> Bool {
        guard let parsed = CommandMatcher.parseSaveCommand(text),
              let command = commands.save(keyword: parsed.keyword, instruction: parsed.instruction) else { return false }
        commandNotice = "Saved command \"\(command.keyword)\""
        controller.log("Command saved by voice: \(command.keyword) → \(command.instruction)")
        let confirmation = language == .swedish ? "Sparade kommandot \(command.keyword)." : "Saved the command \(command.keyword)."
        if case .paused = state { return true }
        speaker.enqueue(confirmation, language: language)
        return true
    }

    func receiveAnswer(question: String, answer: String, latencyMs: Double? = nil, source: String) {
        conversation.append(AnswerTurn(question: question, answer: answer, latencyMs: latencyMs, source: source))
    }
}
