import Foundation
import Observation

/// Decides *when* a question goes to the answer engine (MVP item 3): push-to-talk (default), auto mode through
/// `QuestionGate` with cooldown and self-playback suppression, and the manual "ask about the last sentence".
/// Pure state machine over the `Conversation` value; time is injected so it is unit-tested without timers.
@MainActor
@Observable
final class ActivationController {
    struct PushToTalkSession: Equatable, Sendable {
        var startedAt: Date
        /// Number of final segments when the button went down — everything after it is "what the user said".
        var finalCountAtStart: Int
    }

    static let maxHistory = 20

    let settings: ActivationSettings
    private(set) var pushToTalk: PushToTalkSession?
    /// Button released while the recogniser still had an open partial: wait for the final until this time.
    private(set) var awaitingFinalUntil: Date?
    private var pendingFinalCountAtStart: Int?
    private(set) var lastAutoFiredAt: Date?
    private(set) var lastDecision: GateDecision?
    private(set) var history: [ActivationRequest] = []
    /// The answer engine (item 4) subscribes here.
    var onActivate: (@MainActor (ActivationRequest) -> Void)?

    var isHolding: Bool { pushToTalk != nil }
    var isAwaitingFinal: Bool { awaitingFinalUntil != nil }

    init(settings: ActivationSettings) {
        self.settings = settings
    }

    // MARK: - Push-to-talk

    func beginPushToTalk(conversation: Conversation, now: Date = Date()) {
        awaitingFinalUntil = nil
        pendingFinalCountAtStart = nil
        pushToTalk = PushToTalkSession(startedAt: now, finalCountAtStart: conversation.finalSegments.count)
    }

    /// Returns true when a request fired immediately. False means the recogniser has not finalised the last
    /// words yet: the next final within `settings.releaseGrace` fires, otherwise `flushPushToTalk` does.
    @discardableResult
    func endPushToTalk(conversation: Conversation, language: TranscriptionLanguage, now: Date = Date()) -> Bool {
        guard let session = pushToTalk else { return false }
        pushToTalk = nil
        let finals = Self.text(conversation.finalSegments.dropFirst(session.finalCountAtStart))
        if !finals.isEmpty && conversation.partial == nil {
            fire(query: finals, trigger: .pushToTalk, language: language, now: now)
            return true
        }
        awaitingFinalUntil = now.addingTimeInterval(settings.releaseGrace)
        pendingFinalCountAtStart = session.finalCountAtStart
        return false
    }

    /// Call once `settings.releaseGrace` after release: fires with whatever is final plus the open partial.
    func flushPushToTalk(conversation: Conversation, language: TranscriptionLanguage, now: Date = Date()) {
        guard awaitingFinalUntil != nil, let start = pendingFinalCountAtStart else { return }
        awaitingFinalUntil = nil
        pendingFinalCountAtStart = nil
        var parts = conversation.finalSegments.dropFirst(start).map(\.text)
        if let partial = conversation.partial { parts.append(partial.text) }
        let query = parts.joined(separator: " ").trimmingCharacters(in: .whitespaces)
        if !query.isEmpty {
            fire(query: query, trigger: .pushToTalk, language: language, now: now)
        }
    }

    // MARK: - Final segments (auto mode + push-to-talk completion)

    func segmentFinalized(_ segment: TranscriptSegment, conversation: Conversation, language: TranscriptionLanguage,
                          isPlaybackSpeaking: Bool, now: Date = Date()) {
        if let until = awaitingFinalUntil, let start = pendingFinalCountAtStart {
            awaitingFinalUntil = nil
            pendingFinalCountAtStart = nil
            if now <= until {
                let query = Self.text(conversation.finalSegments.dropFirst(start))
                if !query.isEmpty {
                    fire(query: query, trigger: .pushToTalk, language: language, now: now)
                }
                return
            }
        }
        guard pushToTalk == nil else { return } // the user is still holding: collect, decide on release
        guard settings.mode == .auto else { return }
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

    /// Text mode (item 6) enters here.
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

    private static func text(_ segments: ArraySlice<TranscriptSegment>) -> String {
        segments.map(\.text).joined(separator: " ").trimmingCharacters(in: .whitespaces)
    }
}
