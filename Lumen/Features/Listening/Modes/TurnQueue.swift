import Foundation

/// D221 (A137, G7 step 7a): what the queue of split turns uses of `ListeningModel`: the model's own calls, unchanged.
@MainActor
protocol TurnQueueHost: ListeningModeHost {
    var mode: ConversationMode { get }
    var isAnswering: Bool { get }
    var voiceIsSpeaking: Bool { get }
    var hasPendingSpeech: Bool { get }
    /// The persona a queued turn is asked with: the tutor's in Provläge, none in Frågor.
    func turnPersona() -> PersonaRequest?
    /// A queued turn was asked. D87: in Provläge it is one of the last turns.
    func turnAsked(_ text: String)
}

/// A8.4 and A21.1 (A137, G7 step 7a): the turns that wait to be asked one after another, hands-free in Frågor and in
/// Provläge. Moved unchanged out of `ListeningModel`, where it was `studyQueue`. Two things fill it: several questions
/// said in one breath (the first is asked at once, the rest wait here), and words heard while a turn is being answered
/// (never dropped). The model asks for the next one when Lumen's voice is over, instead of listening again.
@MainActor
final class TurnQueue {
    /// Set by the model right after its own init; weak, the model owns the queue.
    weak var host: (any TurnQueueHost)?
    private var waiting: [String] = []

    var isEmpty: Bool { waiting.isEmpty }

    /// A8.4: the rest of a turn that was split, before whatever already waits.
    func putFirst(_ parts: [String]) {
        waiting = parts + waiting
    }

    /// A21.1 (Toby T5 finding 1): Scribe delivered several segments at once and the first one ended the turn; the
    /// others arrive while it is answered. Each becomes its own turn, asked when the answer before is over.
    func heardWhileAnswering(_ text: String) {
        guard let host else { return }
        let parts = QuestionSplitter.split(text).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !FillerFilter.isOnlyFiller($0) }
        guard !parts.isEmpty else { return }
        waiting += parts
        host.modeLog("\(host.mode.rawValue): heard while a turn was answered, queued as \(parts.count) turn(s) (A21): \(text)")
        if host.study.phase == .listening || (!host.voiceIsSpeaking && !host.hasPendingSpeech && !host.isAnswering) {
            // Nothing is being answered after all (silent answer, failure): ask it now.
            if askNext() { return }
        }
    }

    /// A8.4: the next turn split from the same utterance, instead of listening again. True: it was asked.
    @discardableResult
    func askNext() -> Bool {
        guard let host, host.study.isActive, host.mode == .prov || host.mode == .standard, !waiting.isEmpty else { return false }
        let next = waiting.removeFirst()
        host.modeLog("\(host.mode.rawValue): next part of the same turn: \(next)")
        host.activated(ActivationRequest(query: next, trigger: .tutor, language: host.language), persona: host.turnPersona())
        host.turnAsked(next)
        return true
    }

    /// Listening stopped: nothing waits any more.
    func clear() {
        waiting.removeAll()
    }
}
