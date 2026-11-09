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
    /// A8: a question the app did not send, and why, for the Diagnostics turn table.
    var onDrop: (@MainActor (_ text: String, _ reason: String) -> Void)?
    /// The last question sent, so words that follow it within `continuationWindow` can complete it (A8.2).
    private(set) var lastFired: FiredQuestion?
    /// Questions split from one utterance (A8.4) wait here until the answer before them is over.
    private(set) var queued: [PendingQuestion] = []
    /// Words that follow a sent question this soon and are no question themselves complete it (A8.2).
    static let continuationWindow: TimeInterval = 5

    init(settings: ActivationSettings) {
        self.settings = settings
    }

    struct FiredQuestion: Equatable, Sendable {
        var text: String
        var at: Date
    }

    struct PendingQuestion: Equatable, Sendable {
        var text: String
        var gate: GateDecision
        var dueAt: Date
        var language: TranscriptionLanguage
    }

    // MARK: - Final segments (Frågor, auto)

    /// Trigger design after Parrot v0.11.3 (MIT; the design, not its code): more speech within `questionDebounce`
    /// joins a waiting question; answers are at least `cooldown` apart (Parrot's minimum interval).
    /// A8: nothing that passed the gate is dropped any more. A question inside the cooldown waits for it to pass; a
    /// question that turns out to go on is sent whole; several questions in one utterance are sent one after another;
    /// words that complete the question just sent are sent together with it.
    func segmentFinalized(_ segment: TranscriptSegment, conversation: Conversation, language: TranscriptionLanguage,
                          isPlaybackSpeaking: Bool, now: Date = Date()) {
        guard !isPlaybackSpeaking else {
            // Our own answer is playing (§4.3): the recogniser input is gated then, so this is rare.
            onDrop?(segment.text, "heard while Lumen spoke")
            return
        }
        let gate = QuestionGate(sensitivity: settings.sensitivity)

        if var held = pending {
            // The speaker went on: the question was not finished. The whole thing is sent; the backend judges it.
            held.text += " " + segment.text
            let decision = gate.evaluate(held.text, overlapsPlayback: segment.overlapsPlayback)
            lastDecision = decision
            held.gate = decision
            held.dueAt = now.addingTimeInterval(settings.questionDebounce)
            pending = held
            return
        }

        let parts = QuestionSplitter.split(segment.text)
        if parts.count == 1, let last = lastFired, now.timeIntervalSince(last.at) <= Self.continuationWindow, !last.text.hasSuffix("?"),
           !gate.evaluate(segment.text, overlapsPlayback: segment.overlapsPlayback).fires, !segment.overlapsPlayback {
            // A8.2: the words went on after the question was sent ("vilka är de största" … "bergen i världen").
            // The answer to the first half is replaced by one to the whole.
            let merged = last.text + " " + segment.text
            let decision = gate.evaluate(merged)
            lastDecision = decision
            lastAutoFiredAt = now
            fire(query: merged, trigger: .auto, language: language, gate: decision, now: now)
            return
        }

        var accepted: [PendingQuestion] = []
        for part in parts {
            let decision = gate.evaluate(part, overlapsPlayback: segment.overlapsPlayback)
            lastDecision = decision
            if decision.fires {
                accepted.append(PendingQuestion(text: part, gate: decision, dueAt: now.addingTimeInterval(settings.questionDebounce),
                                                language: language))
            } else if part.split(separator: " ").count >= 2 {
                onDrop?(part, "question gate " + String(format: "%.2f", decision.score) + " < " + String(format: "%.2f", decision.threshold))
            }
        }
        guard let first = accepted.first else { return }
        queued += accepted.dropFirst()
        pending = first
        if let last = lastAutoFiredAt, now.timeIntervalSince(last) < settings.cooldown {
            pending?.dueAt = max(first.dueAt, last.addingTimeInterval(settings.cooldown)) // waits, never dropped
            return
        }
        if settings.questionDebounce <= 0 { fireDue(now: now) }
    }

    /// The waiting question is due: fire it. Inside the cooldown it waits for the cooldown instead (A8).
    @discardableResult
    func fireDue(now: Date = Date()) -> Bool {
        guard let held = pending, now >= held.dueAt else { return false }
        if let last = lastAutoFiredAt, now.timeIntervalSince(last) < settings.cooldown {
            pending?.dueAt = last.addingTimeInterval(settings.cooldown)
            return false
        }
        pending = nil
        lastAutoFiredAt = now
        fire(query: held.text, trigger: .auto, language: held.language, gate: held.gate, now: now)
        return true
    }

    /// A8.4: the answer before is over; the next question split from the same utterance goes now.
    @discardableResult
    func fireNextQueued(now: Date = Date()) -> Bool {
        guard pending == nil, !queued.isEmpty else { return false }
        let next = queued.removeFirst()
        lastAutoFiredAt = now
        fire(query: next.text, trigger: .auto, language: next.language, gate: next.gate, now: now)
        return true
    }

    var hasQueued: Bool { !queued.isEmpty }

    /// The last question got its answer (spoken or shown): later words are a new turn, not its continuation.
    func answerDelivered() {
        lastFired = nil
    }

    /// The session stopped: waiting questions are dropped.
    func cancelPending() {
        pending = nil
        queued.removeAll()
        lastFired = nil
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
        if trigger == .auto { lastFired = FiredQuestion(text: query, at: now) }
        let request = ActivationRequest(query: query, trigger: trigger, language: language, gate: gate, createdAt: now)
        history.insert(request, at: 0)
        if history.count > Self.maxHistory { history.removeLast(history.count - Self.maxHistory) }
        onActivate?(request)
    }
}
