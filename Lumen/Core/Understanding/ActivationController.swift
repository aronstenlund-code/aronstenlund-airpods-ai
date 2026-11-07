import Foundation
import Observation

/// Decides *when* a question goes to the answer engine (MVP item 3, D72): every mode is hands-free, so the room is
/// listened to through `QuestionGate` with cooldown and self-playback suppression. The typed question and "ask about
/// the last sentence" are the manual fallbacks. There is no hold-to-ask any more (D72).
/// Pure state machine over the `Conversation` value; time is injected so it is unit-tested without timers.
@MainActor
@Observable
final class ActivationController {
    static let maxHistory = 20

    let settings: ActivationSettings
    private(set) var lastAutoFiredAt: Date?
    private(set) var lastDecision: GateDecision?
    private(set) var history: [ActivationRequest] = []
    /// The answer engine (item 4) subscribes here.
    var onActivate: (@MainActor (ActivationRequest) -> Void)?

    init(settings: ActivationSettings) {
        self.settings = settings
    }

    // MARK: - Final segments (Frågor, auto)

    func segmentFinalized(_ segment: TranscriptSegment, conversation: Conversation, language: TranscriptionLanguage,
                          isPlaybackSpeaking: Bool, now: Date = Date()) {
        guard !isPlaybackSpeaking else { return } // our own answer is playing (§4.3)

        let decision = QuestionGate(sensitivity: settings.sensitivity).evaluate(segment.text, overlapsPlayback: segment.overlapsPlayback)
        lastDecision = decision
        guard decision.fires else { return }
        if let last = lastAutoFiredAt, now.timeIntervalSince(last) < settings.cooldown { return }
        lastAutoFiredAt = now
        fire(query: segment.text, trigger: .auto, language: language, gate: decision, now: now)
    }

    // MARK: - Manual paths

    /// "Answer the last thing that was said" (ARCHITECTURE §6 manual path).
    @discardableResult
    func answerLast(conversation: Conversation, language: TranscriptionLanguage, now: Date = Date()) -> Bool {
        guard let last = conversation.finalSegments.last(where: { !$0.overlapsPlayback }) else { return false }
        fire(query: last.text, trigger: .answerLast, language: language, now: now)
        return true
    }

    /// Text mode (item 6), the fallback (D72), enters here.
    func submitText(_ text: String, language: TranscriptionLanguage, now: Date = Date()) {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        fire(query: query, trigger: .text, language: language, now: now)
    }

    // MARK: - Private

    private func fire(query: String, trigger: ActivationTrigger, language: TranscriptionLanguage,
                      gate: GateDecision? = nil, now: Date) {
        let request = ActivationRequest(query: query, trigger: trigger, language: language, gate: gate, createdAt: now)
        history.insert(request, at: 0)
        if history.count > Self.maxHistory { history.removeLast(history.count - Self.maxHistory) }
        onActivate?(request)
    }
}
