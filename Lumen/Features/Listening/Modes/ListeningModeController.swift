import Foundation

/// D199 (G7, A111): one listening mode's own decisions, taken out of `ListeningModel` a mode at a time. The model keeps
/// the audio engine (recording, AirPods routing, playback, the recogniser) and asks the mode's controller only what is
/// the mode's own: what a finished turn means, which words the recogniser should hear first, whether an early turn is
/// answered ahead, and what "Lumen, …" does during the session. Moving a mode here changes nothing it does.
///
/// Step 1 is Intervjuläge (`InterviewModeController`). The order of the others is in
/// `reports/2026-11-16-1700-angela-a111-g7-steg1.md`.
@MainActor
protocol ListeningModeController: AnyObject {
    var mode: ConversationMode { get }
    /// A14: the short words the recogniser should hear first in this mode (after the names).
    var spokenKeyterms: [String] { get }
    /// A finished turn that is not a command, filler or exam answer.
    func turn(_ text: String)
    /// D80: an early turn while the other person still talks. The request to answer ahead, or nil for none.
    func aheadRequest(for text: String) -> (request: ActivationRequest, persona: PersonaRequest?)?
    /// "Lumen, …" while this mode's session runs.
    func instruction(_ text: String)
}

/// D199: what a mode's controller may use of `ListeningModel`. Narrow on purpose: the turn's speaker, the session's
/// state, the answer pipeline and the log. Nothing here records, routes or plays audio.
@MainActor
protocol ListeningModeHost: AnyObject {
    var language: TranscriptionLanguage { get }
    var study: StudySessionController { get }
    /// D81: the voice when known, otherwise the input level.
    func turnSpeaker(level: Double?) -> (speaker: RizzSpeaker, why: String)
    /// The answer pipeline (item 4), as for every other question.
    func activated(_ request: ActivationRequest, persona: PersonaRequest?)
    func modeLog(_ line: String)
}
