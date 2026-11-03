import Foundation
import Observation

/// Drives the Listening screen (MVP item 1). No business logic in views.
@MainActor
@Observable
final class ListeningModel: TranscriptSink {
    let controller: SessionController
    let consent: any ConsentStoring
    let transcription: TranscriptionCoordinator
    private(set) var conversation = Conversation()
    var isShowingPrivacy = false

    var state: SessionState { controller.state }
    var isListening: Bool { controller.state.isListening }
    var isActiveSession: Bool { controller.isActiveSession }
    var canResume: Bool { controller.canResume }
    var lastError: String? { controller.lastError }
    var level: AudioLevel.Reading { controller.level }

    /// "AirPods Pro · HFP" — which microphone is live, from the session snapshot.
    var routeSummary: String? {
        guard let snapshot = controller.snapshot, let input = snapshot.inputs.first else { return nil }
        return "\(input.portName) · \(snapshot.transport)"
    }

    init(controller: SessionController, consent: any ConsentStoring, transcription: TranscriptionCoordinator) {
        self.controller = controller
        self.consent = consent
        self.transcription = transcription
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
        consent.revoke()
    }

    func clearHistory() {
        conversation.clear()
    }

    // MARK: - TranscriptSink (fed by TranscriptionCoordinator) and answers (item 4)

    func receivePartialTranscript(_ text: String, at date: Date = Date()) {
        conversation.updatePartial(text, at: date, overlapsPlayback: controller.playback.isSpeaking)
    }

    func receiveFinalTranscript(_ text: String, at date: Date = Date()) {
        conversation.finalize(text, at: date, overlapsPlayback: controller.playback.isSpeaking)
    }

    func receiveAnswer(question: String, answer: String, latencyMs: Double? = nil, source: String) {
        conversation.append(AnswerTurn(question: question, answer: answer, latencyMs: latencyMs, source: source))
    }
}
