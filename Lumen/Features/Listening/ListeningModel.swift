import Foundation
import Observation

/// Drives the Listening screen (MVP items 1–3). No business logic in views.
@MainActor
@Observable
final class ListeningModel: TranscriptSink {
    let controller: SessionController
    let consent: any ConsentStoring
    let transcription: TranscriptionCoordinator
    let activation: ActivationController
    private(set) var conversation = Conversation()
    /// The most recent question handed to the answer engine (item 4 replaces this with the answer flow).
    private(set) var pendingQuestion: ActivationRequest?
    var isShowingPrivacy = false
    private var flushTask: Task<Void, Never>?

    var state: SessionState { controller.state }
    var isListening: Bool { controller.state.isListening }
    var isActiveSession: Bool { controller.isActiveSession }
    var canResume: Bool { controller.canResume }
    var lastError: String? { controller.lastError }
    var level: AudioLevel.Reading { controller.level }
    var isHolding: Bool { activation.isHolding }
    var language: TranscriptionLanguage { transcription.language.selected }

    /// "AirPods Pro · HFP" — which microphone is live, from the session snapshot.
    var routeSummary: String? {
        guard let snapshot = controller.snapshot, let input = snapshot.inputs.first else { return nil }
        return "\(input.portName) · \(snapshot.transport)"
    }

    init(controller: SessionController, consent: any ConsentStoring,
         transcription: TranscriptionCoordinator, activation: ActivationController) {
        self.controller = controller
        self.consent = consent
        self.transcription = transcription
        self.activation = activation
        activation.onActivate = { [weak self] request in self?.activated(request) }
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
        await controller.stop()
    }

    func resume() async {
        await controller.resume()
    }

    /// Stops the microphone, forgets the session's transcript and clears the consent record; the consent
    /// screen is shown again by `RootView`.
    func withdrawConsent() async {
        await controller.stop()
        conversation.clear()
        pendingQuestion = nil
        consent.revoke()
    }

    func clearHistory() {
        conversation.clear()
        pendingQuestion = nil
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

    private func activated(_ request: ActivationRequest) {
        pendingQuestion = request
        controller.log("Activation (\(request.trigger.rawValue)): \(request.query)")
    }

    // MARK: - TranscriptSink (fed by TranscriptionCoordinator) and answers (item 4)

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
