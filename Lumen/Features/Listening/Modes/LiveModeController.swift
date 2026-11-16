import Foundation
import Observation

/// D199 step 2 (A113): what the live session needs of `ListeningModel` beyond `ListeningModeHost`. The model keeps the
/// audio engine; these are its existing calls, unchanged: the answer pipeline for a suggestion request, the voice's
/// queue, the Live Activity and the log's counters. Nothing here records or routes audio.
@MainActor
protocol LiveModeHost: ListeningModeHost {
    /// The running mode (`.social` or `.rizz` while a live session runs).
    var mode: ConversationMode { get }
    /// D82.2: Silero is deciding who speaks (for the log line).
    var vadIsRunning: Bool { get }
    /// The sound goes out of the iPhone's own speaker (D82: then the microphone can hear Lumen).
    var outputsToBuiltInSpeaker: Bool { get }
    var voiceIsSpeaking: Bool { get }
    /// "Talare 1" when the labels are on and the voice is known (D81).
    func liveLabel() -> String?
    /// Sends a suggestion or instruction request: the pending question, the latency clock and the answer engine, as
    /// the model always did.
    func sendLive(_ request: ActivationRequest, persona: PersonaRequest)
    /// The first text of an answer came (latency).
    func markLiveFirstText()
    func showLiveActivity()
    /// Queues a line for the voice (the model's speaker, unchanged).
    func speakLive(_ line: String)
    /// A short confirmation ("Okej."), not while paused.
    func sayLive(_ line: String)
    func aheadStarted()
    func aheadDiscarded()
}

/// D43, D69, D72, D80, D82.3 (A113, D199 step 2): the live session of Socialt läge and Rizzläge, moved unchanged out of
/// `ListeningModel`: the conversation so far (`RizzSession`), the suggestion asked for while the other person still
/// talks (`liveAhead`), the turn's timing (`liveTurn`), instructions ("Lumen, lite mindre kaxig", "ge mig tre") and
/// the suggestions themselves (asked for, shown, spoken in a pause, "nästa").
///
/// The two modes share this session; what differs between them (the age question, the style, the start screen) is
/// not here. Socialt läge sits behind `SocialModeController`; Rizzläge still calls this directly from the model
/// until step 3.
@MainActor
@Observable
final class LiveModeController {
    /// The conversation and its suggestions; nil outside a live session. The views read it through `ListeningModel.rizz`.
    private(set) var session: RizzSession?
    /// The text the last early suggestion request was for, and when (D80: at most every 3 s).
    @ObservationIgnored private var liveAhead: (key: String, at: Date)?
    /// D82.3: one live turn, logged when its suggestion is spoken: who, why, requested, ready, spoken.
    @ObservationIgnored private var liveTurn: (endedAt: Date, who: String, requestedAt: Date?, readyAt: Date?)?
    /// An instruction is on its way to the backend for this mode (D69): what comes back is a calibration, or the
    /// suggestions the wearer asked for ("ge mig tre", D72).
    @ObservationIgnored private(set) var instructing: ConversationMode?
    /// The suggestion trigger that waits until the instruction is back.
    @ObservationIgnored private var deferredTrigger: String?
    /// The trigger of the suggestions being made, so an instruction that cancels them can ask again.
    @ObservationIgnored private var inFlightTrigger: String?
    /// The instruction was a request for more and its suggestions are on screen: nothing replaces them at once.
    @ObservationIgnored private var instructionSuggested = false

    /// Set by the model right after its own init; weak, the model owns this controller.
    @ObservationIgnored weak var host: (any LiveModeHost)?
    private let settings: ModeSettings

    /// A14: the short words the recogniser should hear first in both live modes.
    static let spokenKeyterms = ["rizz", "cringe", "flirtig", "flirtigare"]

    init(settings: ModeSettings) {
        self.settings = settings
    }

    var isActive: Bool { session != nil }
    var isInstructing: Bool { instructing != nil }

    // MARK: The session

    /// A live mode started (`ListeningModel.startHandsFree`).
    func begin(style: LiveStyle) {
        session = RizzSession(style: style)
    }

    /// The hands-free session ended. The model records the history from `session` first.
    func end() {
        liveAhead = nil
        session = nil
        instructing = nil
        deferredTrigger = nil
        inFlightTrigger = nil
    }

    // MARK: Turns

    /// A finished turn in a live mode: who spoke, the line into the conversation, and a suggestion for the wearer.
    func turn(_ text: String) {
        guard let host else { return }
        let (speaker, why) = host.turnSpeaker(level: host.study.lastTurnLevelDBFS)
        let detector = host.vadIsRunning ? "Silero" : "level"
        host.modeLog("\(host.mode.rawValue) turn · \(speaker == .user ? "wearer" : "other") · \(why) · speech by \(detector)")
        if speaker == .other {
            // A suggestion asked for while they were talking (D80) counts from that request.
            let early = liveAhead?.at
            let ready: Date? = early != nil && session?.current != nil ? Date() : nil
            liveTurn = (endedAt: Date(), who: "other", requestedAt: early, readyAt: ready)
        }
        host.study.resumeListening() // the room goes on while the suggestions are being made
        guard var session else { return }
        if speaker == .user, session.usesSuggestion(text) {
            settings.countUse(of: session.style)
        }
        session.add(speaker, text: text, at: Date(), label: host.liveLabel())
        self.session = session
        if speaker == .other, !FillerFilter.isOnlyFiller(text) {
            if let early = liveAhead, early.key == AheadAnswer.key(text) {
                // D80: asked for while they were talking; it is on screen or on its way, and speaks in this pause.
                liveAhead = nil
                speakSuggestion()
            } else {
                if inFlightTrigger != nil { host.aheadDiscarded() }
                liveAhead = nil
                requestSuggestions(trigger: "other_spoke")
            }
        }
    }

    /// The conversation stalled (D43): an opener, or something to go on with.
    func stalled() {
        if let session { requestSuggestions(trigger: session.hasConversation ? "stall" : "opener") }
    }

    /// Rizzläge / Socialt läge: the wearer saying the suggestion out loud is its use, not Lumen's echo. Through
    /// AirPods Lumen is never heard by the microphone (D82, owner); out of the iPhone's own speaker it can be.
    func isWearerUsingSuggestion(_ text: String, level: Double?) -> Bool {
        guard let host, let session, session.usesSuggestion(text), !host.outputsToBuiltInSpeaker else { return false }
        return RizzSpeaker.tag(levelDBFS: level, thresholdDBFS: settings.speakerThresholdDBFS) == .user
    }

    // MARK: Instructions (D69, D72)

    /// "Lumen, lite mindre kaxig" or "Lumen, ge mig tre pickup lines" in Socialt läge or Rizzläge. Sent as
    /// `social.calibrate` with the stored calibration, never as a line of the conversation. The backend answers a
    /// calibration with `done.calibration` and a request for more with that many suggestions.
    func instruction(_ text: String) {
        guard let host, let session,
              let persona = LiveRequest.instruction(text, for: session, interests: settings.interests,
                                                    profile: settings.rizzProfile,
                                                    calibration: settings.calibration(for: host.mode),
                                                    adultConfirmed: settings.isAdultConfirmed) else { return }
        if let trigger = inFlightTrigger { deferredTrigger = trigger } // the suggestions being made are cancelled
        inFlightTrigger = nil
        instructing = host.mode
        instructionSuggested = false
        host.modeLog("\(host.mode.rawValue): instruction sent") // the words stay out of the log
        host.sendLive(ActivationRequest(query: "", trigger: .rizz, language: host.language), persona: persona)
    }

    /// The instruction came back: store a calibration, then ask for the suggestions that waited.
    func instructionEnded(_ calibration: String?, answered: Bool) {
        guard let host, let instructed = instructing else { return }
        instructing = nil
        if let calibration {
            settings.setCalibration(calibration, for: instructed)
            host.modeLog("\(instructed.rawValue): calibration stored (\(calibration.count) characters)")
            host.sayLive(host.language == .swedish ? "Okej." : "Okay.")
        }
        let suggested = instructionSuggested
        instructionSuggested = false
        if let trigger = deferredTrigger, answered, !suggested {
            deferredTrigger = nil
            requestSuggestions(trigger: trigger)
        }
        deferredTrigger = nil
    }

    // MARK: Suggestions

    /// The answer engine's request completed or failed (`AnswerSink`): no suggestions are being made any more.
    func requestEnded() {
        inFlightTrigger = nil
    }

    private func requestSuggestions(trigger: String) {
        guard let host, let session else { return }
        if liveTurn != nil, liveTurn?.requestedAt == nil { liveTurn?.requestedAt = Date() }
        if instructing != nil {
            deferredTrigger = trigger // the instruction goes first, the suggestions follow it
            return
        }
        guard let persona = LiveRequest.suggestions(for: session, trigger: trigger, interests: settings.interests,
                                                    profile: settings.rizzProfile,
                                                    calibration: settings.calibration(for: host.mode),
                                                    adultConfirmed: settings.isAdultConfirmed) else { return }
        inFlightTrigger = trigger
        host.sendLive(ActivationRequest(query: "", trigger: .rizz, language: host.language), persona: persona)
    }

    /// The backend's suggestions came (`AnswerSink.answerSuggestions`).
    func suggestionsArrived(_ options: [String]) {
        guard let host else { return }
        host.markLiveFirstText()
        if instructing != nil {
            // The wearer asked for more ("ge mig tre", D72): all of them, shown and spoken, this time only.
            instructionSuggested = true
            session?.offer(options)
            host.showLiveActivity()
            speakAllSuggestions()
            return
        }
        inFlightTrigger = nil
        if liveTurn != nil { liveTurn?.readyAt = Date() }
        session?.offer(Array(options.prefix(ListeningModel.suggestionsShown))) // D72: one suggestion, shown and spoken
        host.showLiveActivity()
        speakSuggestion()
    }

    private func speakAllSuggestions() {
        guard let host, let options = session?.suggestions, !host.study.someoneIsTalking() else { return }
        for line in options { host.speakLive(line) }
    }

    /// "nästa", or the button on the Live Activity. With one suggestion on screen (D72) it asks for a fresh one.
    func nextSuggestion() {
        guard let host, let session else { return }
        if session.suggestions.count <= 1 {
            requestSuggestions(trigger: session.hasConversation ? "stall" : "opener")
            return
        }
        self.session?.next()
        host.showLiveActivity()
        speakSuggestion()
    }

    /// Only in a pause, never over anyone. A missed moment stays on the Live Activity.
    private func speakSuggestion() {
        guard let host, let line = session?.current, !host.study.someoneIsTalking(), !host.voiceIsSpeaking else { return }
        host.speakLive(line)
        logLiveTurn()
    }

    /// A suggestion is made while the other person is still talking, so it is ready when the pause comes; during a
    /// long monologue at most every 3 s (D80).
    func suggestionAhead(for text: String, now: Date = Date()) {
        guard let host, let session, instructing == nil else { return }
        let speaker = host.turnSpeaker(level: host.study.currentTurnLevelDBFS).speaker
        guard speaker == .other else { return }
        if let last = liveAhead, now.timeIntervalSince(last.at) < ListeningModel.liveRefresh { return }
        var preview = session
        preview.add(.other, text: text, at: now)
        guard let persona = LiveRequest.suggestions(for: preview, trigger: "other_spoke", interests: settings.interests,
                                                    profile: settings.rizzProfile,
                                                    calibration: settings.calibration(for: host.mode),
                                                    adultConfirmed: settings.isAdultConfirmed) else { return }
        if inFlightTrigger != nil { host.aheadDiscarded() }
        liveAhead = (AheadAnswer.key(text), now)
        host.aheadStarted()
        inFlightTrigger = "other_spoke"
        host.sendLive(ActivationRequest(query: "", trigger: .rizz, language: host.language), persona: persona)
    }

    /// D82.3: turn end → suggestion requested → ready → spoken, in ms from the end of the other person's turn.
    private func logLiveTurn(now: Date = Date()) {
        guard let host, let turn = liveTurn else { return }
        liveTurn = nil
        func ms(_ date: Date?) -> String {
            guard let date else { return "–" }
            return "\(Int((date.timeIntervalSince(turn.endedAt) * 1000).rounded())) ms"
        }
        host.modeLog("Live turn timing · \(turn.who) · requested \(ms(turn.requestedAt)) · ready \(ms(turn.readyAt)) · spoken \(ms(now)) (from the end of the turn)")
    }
}

/// D199 step 2 (A113): Socialt läge as a `ListeningModeController`. Its turns, instructions and suggestions are the
/// shared live session (`LiveModeController`); what is its own is the mode and that it needs no age question. Rizzläge
/// gets its own controller on the same session in step 3.
@MainActor
final class SocialModeController: ListeningModeController {
    let mode: ConversationMode = .social
    private let live: LiveModeController

    init(live: LiveModeController) {
        self.live = live
    }

    var spokenKeyterms: [String] { LiveModeController.spokenKeyterms }

    func turn(_ text: String) { live.turn(text) }

    /// A live mode answers ahead with a suggestion (`LiveModeController.suggestionAhead`), never with an answer.
    func aheadRequest(for text: String) -> (request: ActivationRequest, persona: PersonaRequest?)? { nil }

    func instruction(_ text: String) { live.instruction(text) }
}
