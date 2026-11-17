import Foundation
import Observation

/// D221 (A138, G7 step 7d): what the phone tools use of `ListeningModel`: the model's own calls, unchanged.
@MainActor
protocol PhoneToolsHost: ListeningModeHost {
    /// The tools themselves (set by AppContainer; nil in most tests: no tools offered).
    var phoneTools: (any PhoneToolRunning)? { get }
    /// The request last sent to the answer engine: a tool call belongs to it.
    var lastSentRequest: (request: ActivationRequest, persona: PersonaRequest?)? { get }
    func say(_ line: String)
}

/// A48 (D122, K35; A138, G7 step 7d): the phone tools. The model in the backend may ask for a tool on the phone (a
/// note, a reminder, a calendar entry). Moved unchanged out of `ListeningModel`: a tool that changes nothing runs at
/// once; one that changes something is asked about first ("Ska jag lägga in …?", by voice or Ja / Nej on Lyssnar);
/// then the same question is sent again with the tool's result, and the model says one short sentence about it.
@MainActor
@Observable
final class PhoneToolsController {
    @ObservationIgnored weak var host: (any PhoneToolsHost)?
    /// The question Lumen asked before a tool changes something; shown with Ja / Nej.
    private(set) var pendingConfirm: String?
    @ObservationIgnored private var pending: (call: PhoneToolCall, request: ActivationRequest, persona: PersonaRequest?)?
    @ObservationIgnored private var roundFor: (id: UUID, round: ToolRound)?

    /// The tool round that goes with `request` (the second call), if it is that call.
    func round(for request: ActivationRequest) -> ToolRound? {
        guard let roundFor, roundFor.id == request.id else { return nil }
        return roundFor.round
    }

    /// The model asked for a tool: run it at once when nothing changes, else ask first (voice or Ja / Nej).
    func answer(_ call: PhoneToolCall) {
        guard let host, let lastSent = host.lastSentRequest, host.phoneTools != nil else { return }
        host.modeLog("Tool call: \(call.name) (A48)")
        pending = (call, lastSent.request, lastSent.persona)
        if let confirm = call.confirm, !confirm.isEmpty {
            pendingConfirm = confirm
            host.say(confirm)
        } else {
            runPending()
        }
    }

    /// "Ja" / "Nej" on Lyssnar, or the voice.
    func confirm(_ yes: Bool) {
        guard pending != nil else { return }
        pendingConfirm = nil
        if yes { runPending() } else { sendRound(.declined, result: nil) }
    }

    /// A spoken yes or no to the confirm question; anything else drops the tool and is a turn of its own.
    func confirmTurn(_ text: String) -> Bool {
        switch ToolConfirmReply.parse(text) {
        case .yes: confirm(true)
        case .no: confirm(false)
        case .other:
            host?.modeLog("Tool not confirmed: something else was said (A48)")
            pending = nil
            pendingConfirm = nil
            return false
        }
        host?.study.resumeListening()
        return true
    }

    private func runPending() {
        guard let pending, let phoneTools = host?.phoneTools else { return }
        pendingConfirm = nil
        Task { [weak self] in
            let outcome = await phoneTools.run(pending.call)
            guard let self, self.pending?.call.id == pending.call.id else { return }
            self.host?.modeLog("Tool \(pending.call.name): \(outcome.status.rawValue) (A48)")
            self.sendRound(outcome.status, result: outcome.result)
        }
    }

    /// The second call: same question, the tool's result; the model says one short sentence about it.
    private func sendRound(_ status: ToolRound.Status, result: JSONValue?) {
        guard let host, let pending else { return }
        self.pending = nil
        let request = ActivationRequest(query: pending.request.query, trigger: pending.request.trigger, language: pending.request.language)
        roundFor = (request.id, ToolRound(call: pending.call, status: status, result: result))
        host.activated(request, persona: pending.persona)
    }
}
