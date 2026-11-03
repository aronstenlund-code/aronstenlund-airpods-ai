import Foundation
import Observation

/// Drives the Listening screen (MVP items 1–5). No business logic in views.
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
    /// Per-answer latency budget (item 7), shown in the debug overlay.
    let latency = LatencyLog()
    private(set) var conversation = Conversation()
    /// The most recent question handed to the answer engine.
    private(set) var pendingQuestion: ActivationRequest?
    /// One-line notice under the answers: "not a question", failures, offline.
    private(set) var answerNotice: String?
    var isShowingPrivacy = false
    var isShowingSettings = false
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

    /// "AirPods Pro · HFP" — which microphone is live, from the session snapshot.
    var routeSummary: String? {
        guard let snapshot = controller.snapshot, let input = snapshot.inputs.first else { return nil }
        return "\(input.portName) · \(snapshot.transport)"
    }

    init(controller: SessionController, consent: any ConsentStoring,
         transcription: TranscriptionCoordinator, activation: ActivationController,
         answers: AnswerEngine, speaker: Speaker, voices: VoiceCatalog) {
        self.controller = controller
        self.consent = consent
        self.transcription = transcription
        self.activation = activation
        self.answers = answers
        self.speaker = speaker
        self.voices = voices
        activation.onActivate = { [weak self] request in self?.activated(request) }
        answers.sink = self
        speaker.onSentenceStarted = { [weak self] provider in self?.latency.markFirstSpeech(provider: provider) }
    }

    // MARK: - User actions

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
    }

    func previewVoice() {
        speaker.preview(speaker.settings.voice, language: language)
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
        let context = AnswerContext(transcript: conversation.recentText(seconds: 60),
                                    recentQA: conversation.recentQA(limit: 3),
                                    prepTerms: [])
        answers.answer(request, context: context)
    }

    // MARK: - AnswerSink (item 4)

    func answerStarted(_ request: ActivationRequest, source: String) {
        conversation.beginAnswer(question: request.query, source: source, at: request.createdAt)
    }

    func answerQuestionReconstructed(_ question: String) {
        conversation.setAnswerQuestion(question)
    }

    func answerDelta(_ text: String) {
        latency.markFirstText(provider: answers.activeProvider.name)
        conversation.appendAnswerText(text)
    }

    func answerSentence(_ sentence: String) {
        speaker.enqueue(sentence, language: pendingQuestion?.language ?? language)
    }

    func answerCompleted(latencyMs: Double?, done: AnswerDone?) {
        conversation.completeAnswer(latencyMs: latencyMs)
        if let latencyMs {
            controller.log("Answer · first text after \(Int(latencyMs)) ms" + (done?.usage?.model.map { " · \($0)" } ?? ""))
        }
    }

    func answerSkipped(_ request: ActivationRequest) {
        latency.end()
        conversation.cancelAnswer()
        answerNotice = "Not a question — no answer (auto mode)"
        controller.log("Auto: backend says not a question: \(request.query)")
    }

    func answerFailed(_ message: String, wantsFallback: Bool) {
        latency.end()
        conversation.cancelAnswer()
        answerNotice = message
        controller.log("Answer failed: \(message)" + (wantsFallback ? " · fallback requested (on-device engine not available on this iPhone)" : ""))
    }

    // MARK: - TranscriptSink (fed by TranscriptionCoordinator)

    func receivePartialTranscript(_ text: String, at date: Date = Date()) {
        conversation.updatePartial(text, at: date, overlapsPlayback: controller.playback.isSpeaking)
    }

    func receiveFinalTranscript(_ text: String, at date: Date = Date()) {
        let before = conversation.finalSegments.count
        conversation.finalize(text, at: date, overlapsPlayback: controller.playback.isSpeaking)
        guard conversation.finalSegments.count > before, let segment = conversation.finalSegments.last else { return }
        activation.segmentFinalized(segment, conversation: conversation, language: language,
                                    isPlaybackSpeaking: controller.playback.isSpeaking, now: date)
    }

    func receiveAnswer(question: String, answer: String, latencyMs: Double? = nil, source: String) {
        conversation.append(AnswerTurn(question: question, answer: answer, latencyMs: latencyMs, source: source))
    }
}
