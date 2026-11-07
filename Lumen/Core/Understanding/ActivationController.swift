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
    /// A question waiting for the speaker to finish (D78).
    private(set) var pending: PendingQuestion?
    /// When the waiting question is due; the listening model sets a timer for it.
    var pendingDueAt: Date? { pending?.dueAt }
    private(set) var history: [ActivationRequest] = []
    /// The answer engine (item 4) subscribes here.
    var onActivate: (@MainActor (ActivationRequest) -> Void)?

    init(settings: ActivationSettings) {
        self.settings = settings
    }

    struct PendingQuestion: Equatable, Sendable {
        var text: String
        var gate: GateDecision
        var dueAt: Date
        var language: TranscriptionLanguage
    }

    // MARK: - Final segments (Frågor, auto)

    /// Trigger design after Parrot v0.11.3 (MIT; the design, not its code): a question waits `questionDebounce`
    /// so the speaker can finish; more speech in that window joins it and the whole is judged again, so half a
    /// sentence never fires on its own; and answers are at least `cooldown` apart (Parrot's minimum interval).
    func segmentFinalized(_ segment: TranscriptSegment, conversation: Conversation, language: TranscriptionLanguage,
                          isPlaybackSpeaking: Bool, now: Date = Date()) {
        guard !isPlaybackSpeaking else { return } // our own answer is playing (§4.3)
        let gate = QuestionGate(sensitivity: settings.sensitivity)

        if var held = pending {
            // The speaker went on: the question was not finished. Judge the whole thing.
            held.text += " " + segment.text
            let decision = gate.evaluate(held.text, overlapsPlayback: segment.overlapsPlayback)
            lastDecision = decision
            if decision.fires {
                held.gate = decision
                held.dueAt = now.addingTimeInterval(settings.questionDebounce)
                pending = held
            } else {
                pending = nil
            }
            return
        }

        let decision = gate.evaluate(segment.text, overlapsPlayback: segment.overlapsPlayback)
        lastDecision = decision
        guard decision.fires else { return }
        if let last = lastAutoFiredAt, now.timeIntervalSince(last) < settings.cooldown { return }
        let held = PendingQuestion(text: segment.text, gate: decision, dueAt: now.addingTimeInterval(settings.questionDebounce),
                                   language: language)
        if settings.questionDebounce <= 0 {
            pending = held
            fireDue(now: now)
        } else {
            pending = held
        }
    }

    /// The waiting question is due: fire it, unless the last answer is too recent.
    @discardableResult
    func fireDue(now: Date = Date()) -> Bool {
        guard let held = pending, now >= held.dueAt else { return false }
        pending = nil
        if let last = lastAutoFiredAt, now.timeIntervalSince(last) < settings.cooldown { return false }
        lastAutoFiredAt = now
        fire(query: held.text, trigger: .auto, language: held.language, gate: held.gate, now: now)
        return true
    }

    /// Our own answer started, or the session stopped: a waiting question is dropped.
    func cancelPending() {
        pending = nil
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
