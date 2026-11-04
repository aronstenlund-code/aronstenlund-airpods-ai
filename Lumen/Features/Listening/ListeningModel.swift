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
    var canSaveNote: Bool { !conversation.finalSegments.isEmpty || !conversation.answers.isEmpty }

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
         goals: GoalsStore? = nil, commands: CommandStore? = nil) {
        self.controller = controller
        self.consent = consent
        self.transcription = transcription
        self.activation = activation
        self.answers = answers
        self.speaker = speaker
        self.voices = voices
        self.notes = notes
        self.prep = prep
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
        transcription.setContextualStrings(prep.sttTerms)
        prep.onChange = { [weak self] in
            guard let self else { return }
            self.transcription.setContextualStrings(self.prep.sttTerms)
        }
    }

    // MARK: - User actions

    /// The Listening screen opened, the app came back, or listening starts: wake the backend (D31) and load the
    /// voices (D23), which also signs in ahead of the first question. Quiet when offline; retried next time.
    func prepareBackend() async {
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
        await controller.start()
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
        }
        switch state {
        case .listening:
            activity?.show(isPaused: false)
        case .paused:
            // Whoever has the audio now keeps it: no speech may restart the engine behind their back.
            flushTask?.cancel()
            answers.cancel()
            speaker.interrupt()
            conversation.cancelAnswer()
            activity?.show(isPaused: true)
        case .idle, .error:
            activity?.end()
        }
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

    func startStudy() async {
        guard consent.isGranted else {
            controller.log("Provläge refused: no consent")
            return
        }
        studyNotice = nil
        if !isActiveSession, study.settings.useVoiceChatMode {
            controller.config = .cHFPVoiceChat // echo cancellation while we talk — to measure (D36)
        }
        if !isListening {
            if canResume { await resume() } else { await startListening() }
            guard isListening else { return }
        }
        answers.cancel()
        speaker.interrupt()
        conversation.cancelAnswer()
        study.start()
        controller.log("Provläge started")
    }

    /// Ends the session. After the silence timeout the microphone is released too ("sparläge").
    func endStudy(bySilence: Bool) {
        guard study.isActive || bySilence else { return }
        study.stop()
        transcription.setInputGated(false)
        if bySilence {
            studyNotice = "Provläge ended after \(study.settings.autoEndMinutes) min of silence; the microphone was switched off."
            controller.log("Provläge auto-ended after silence")
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
            let request = ActivationRequest(query: text, trigger: .tutor, language: language)
            activated(request)
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

    private func speechFinished() {
        guard study.isActive else { return }
        transcription.setInputGated(false)
        study.resumeListening()
    }

    /// The answer produced no speech (silent mode, empty answer): back to listening right away.
    private func studyAnswerEnded() {
        guard study.isActive, !speaker.hasPendingSpeech else { return }
        transcription.setInputGated(false)
        study.resumeListening()
    }

    /// Item 8: saves transcript + answers as a local note.
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

    private func activated(_ request: ActivationRequest) {
        pendingQuestion = request
        answerNotice = nil
        // A new question interrupts the current answer and its speech (assignment item 5).
        speaker.interrupt()
        latency.begin(request)
        controller.log("Activation (\(request.trigger.rawValue)): \(request.query)")
        // Provläge sends the whole session's memory (the backend keeps the last 6 pairs).
        let qaLimit = request.trigger == .tutor ? AnswerContext.qaLimit : 3
        let matched = commands.matches(in: request.query)
        if !matched.isEmpty {
            controller.log("Commands matched: \(matched.map(\.keyword).joined(separator: ", "))")
        }
        let context = AnswerContext(transcript: conversation.recentText(seconds: 60),
                                    recentQA: conversation.recentQA(limit: qaLimit),
                                    prepTerms: prep.backendTerms,
                                    goals: goals.compact,
                                    commands: matched.map { AnswerContext.Command(keyword: $0.keyword, instruction: $0.instruction) })
        answers.answer(request, context: context)
    }

    // MARK: - AnswerSink (item 4)

    func answerStarted(_ request: ActivationRequest, source: String) {
        conversation.beginAnswer(question: request.query, source: source, at: request.createdAt)
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
        speaker.enqueue(sentence, language: pendingQuestion?.language ?? language)
    }

    func answerCompleted(latencyMs: Double?, done: AnswerDone?) {
        conversation.completeAnswer(latencyMs: latencyMs)
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
