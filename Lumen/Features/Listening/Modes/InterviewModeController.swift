import Foundation

/// D42, D72 (A111, D199 step 1): Intervjuläge. Moved unchanged out of `ListeningModel`: the interviewer's question gets
/// the finished answer, read aloud, and nothing else (no feedback, no follow-up questions). The wearer's own words
/// (louder, by input level, or by the voice profile, D81) are never answered, unless they ask for something out loud
/// ("klar", "sammanfatta", "ge mig feedback").
@MainActor
final class InterviewModeController: ListeningModeController {
    let mode: ConversationMode = .interview
    /// Set by the model right after its own init; weak, the model owns this controller.
    weak var host: (any ListeningModeHost)?
    private let settings: ModeSettings

    init(settings: ModeSettings) {
        self.settings = settings
    }

    /// A14: no short command words in Intervjuläge.
    var spokenKeyterms: [String] { [] }

    /// The interview persona with the role or job ad the user gave; `turn` is "question" for an answer to one.
    func persona(turn: String? = nil) -> PersonaRequest {
        PersonaRequest(persona: "interview", setup: settings.interviewPersonaSetup, turn: turn)
    }

    func turn(_ text: String) {
        guard let host else { return }
        let (speaker, why) = host.turnSpeaker(level: host.study.lastTurnLevelDBFS)
        if speaker == .user, !VoiceCommand.isInterviewRequest(text) {
            host.modeLog("Intervjuläge: own turn (\(why)), not answered")
            host.study.resumeListening()
            return
        }
        host.activated(ActivationRequest(query: text, trigger: .overheard, language: host.language),
                       persona: persona(turn: "question"))
    }

    func aheadRequest(for text: String) -> (request: ActivationRequest, persona: PersonaRequest?)? {
        guard let host, host.study.isActive, host.study.phase == .listening else { return nil }
        let speaker = host.turnSpeaker(level: host.study.currentTurnLevelDBFS).speaker
        guard speaker == .other || VoiceCommand.isInterviewRequest(text) else { return nil }
        return (ActivationRequest(query: text, trigger: .overheard, language: host.language), persona(turn: "question"))
    }

    func instruction(_ text: String) {
        guard let host else { return }
        host.activated(ActivationRequest(query: text, trigger: .overheard, language: host.language),
                       persona: persona(turn: "question"))
    }

    /// Likely questions and model answers from the role or job ad. Long, so it is shown, not spoken.
    func prepare() {
        guard let host else { return }
        host.activated(ActivationRequest(query: host.language == .swedish ? "Förbered mig inför intervjun" : "Prepare me for the interview",
                                         trigger: .interviewPrep, language: host.language),
                       persona: persona())
    }
}
