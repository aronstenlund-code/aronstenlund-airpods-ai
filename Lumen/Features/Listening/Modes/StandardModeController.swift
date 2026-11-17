import Foundation
import Observation

/// D199 step 5 (A120): what Frågor (standardläget) and the "Mer?" window use of `ListeningModel`: the model's own
/// calls, unchanged. The activation (`ActivationController`), the echo filter, the recogniser and the playback stay in
/// the model; the tone and the committed words are asked for here, never played or read here.
@MainActor
protocol StandardModeHost: ListeningModeHost {
    var mode: ConversationMode { get }
    var isListening: Bool { get }
    var isAnswering: Bool { get }
    var conversation: Conversation { get }
    var activation: ActivationController { get }
    var headMotion: HeadMotionListener { get }
    var lastAnswerAt: Date? { get }
    /// An exam session, a practice exam, a mini test or a silent quiz runs.
    var hasRunningExercise: Bool { get }
    var playbackIsSpeaking: Bool { get }
    var voiceIsSpeaking: Bool { get }
    var hasPendingSpeech: Bool { get }
    /// A68: Lumen is saying something, or an answer streams that still gives it things to say.
    var lumenIsBusyAnswering: Bool { get }
    var busyReason: String { get }
    /// A63: the recogniser holds words it has not committed yet.
    var hasWaitingWords: Bool { get }
    func commitWaitingWords()
    /// A17: the voice profile says someone else spoke (nil without a profile or when unknown).
    func isOtherVoice(near date: Date) -> Bool?
    func discardAhead(reason: String)
    func say(_ line: String)
    /// What follows the name when it is not a command (D74).
    func instruct(_ text: String)
    /// "Lumen, …" in every mode. True when the words were for Lumen.
    func voice(in text: String, at date: Date) -> Bool
    /// A8.4: the rest of a turn split into several questions, asked one after another.
    func queueTurns(_ parts: [String])
    func listeningEvent(_ event: ListeningModel.ListeningEvent)
    /// A15: the soft tone when the window opens, when the setting is on.
    func playMoreTone()
    /// A56 (K13.2): the answer to "Mer?" teaches the backend the default length.
    func sendLengthSignal(yes: Bool)
    func markMoreUsed()
    /// The developed answer as a turn of its own after `last`: shown, kept in Historik and said.
    func sayDeveloped(_ text: String, after last: AnswerTurn)
}

/// A15 "Mer?" after a short answer, and the two levels behind it (A56, K13): the short answer is spoken and the
/// developed one comes in the same call, ready for "ja". Moved unchanged out of `ListeningModel` (D199 step 5).
/// Frågor and Provläge share it, as before; Provläge's own controller (step 6) uses this same window.
@MainActor
@Observable
final class MoreWindow {
    @ObservationIgnored weak var host: (any StandardModeHost)?
    /// The 5 s window is open: the screen shows "Säg ja för mer".
    private(set) var isOpen = false
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var offeredFor: Date?
    /// A65 (Toby T7b/T12): "ja" in the Mer? window is taken from the partial once it has stood still for
    /// `partialHold`, instead of waiting for Scribe's final after the pause (3 s and more). A partial that goes on
    /// ("Ja men vad är fotosyntes?") is an ordinary turn, as before.
    @ObservationIgnored private var partialTask: Task<Void, Never>?
    @ObservationIgnored private var takenFromPartial: (text: String, at: Date)?
    static let partialHold: TimeInterval = 0.7
    /// A56 (K13): the developed answer that came with the last short one (`done.more`), for about 2 minutes.
    @ObservationIgnored private var developed: (text: String, at: Date, answerID: UUID)?
    /// A67: "ja" came while the short answer's call was still streaming its developed part.
    @ObservationIgnored private var wantedWhileStreaming: Date?

    /// The modes with a "Mer?" window and two levels in one call (`context.two_level`).
    static func applies(to mode: ConversationMode) -> Bool {
        mode == .standard || mode == .prov
    }

    /// After a short answer has been spoken (Frågor and Provläge): the window opens with a soft tone.
    func offerIfShort() {
        guard let host, Self.applies(to: host.mode), !host.hasRunningExercise, host.isListening,
              let last = host.conversation.answers.last, MoreOffer.isShort(last.answer),
              let answered = host.lastAnswerAt, Date().timeIntervalSince(answered) < 30,
              offeredFor != answered else { return } // once per answer (a tip or a confirmation also ends speech)
        offeredFor = answered
        isOpen = true
        host.modeLog("More? window open (A15)")
        host.listeningEvent(.moreWindowOpen) // A29
        host.playMoreTone()
        if host.headMotion.isAvailable {
            host.headMotion.listen(for: MoreOffer.window) { [weak self] gesture in
                guard let self, self.isOpen else { return }
                if gesture == .nod { self.take(by: "nod") } else { self.close(why: "shake") }
            }
        }
        task?.cancel()
        task = Task { [weak self] in
            try? await Task.sleep(for: .seconds(MoreOffer.window))
            guard let self, !Task.isCancelled, self.isOpen else { return }
            self.close(why: "silence")
        }
    }

    func close(why: String) {
        guard isOpen else { return }
        isOpen = false
        task?.cancel()
        task = nil
        host?.modeLog("More? window closed (\(why))")
        host?.listeningEvent(.moreWindowClosed) // A29
        if why == "no" || why == "silence" || why == "shake" { host?.sendLengthSignal(yes: false) } // A56 (K13.2)
    }

    /// A65: a partial heard while the window is open.
    func takeFromPartialIfStable(_ text: String) {
        partialTask?.cancel()
        guard let host, isOpen, MoreOffer.verdict(text) == true, host.isOtherVoice(near: Date()) != true else { return }
        partialTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.partialHold))
            guard let self, let host = self.host, !Task.isCancelled, self.isOpen,
                  host.conversation.partial?.text == text else { return }
            self.takenFromPartial = (text, Date())
            host.discardAhead(reason: "more")
            self.take(by: "voice, before the final (A65)")
        }
    }

    /// A final while the window is open, or right after "ja" was taken from the partial. True: the words were the
    /// answer to "Mer?" and are no turn. "nej" or anything else closes the window.
    func takes(_ text: String, at date: Date) -> Bool {
        guard let host else { return false }
        // A65: the "ja" was already taken from the partial; Scribe's final of the same word is not a turn of its own.
        if let taken = takenFromPartial, date.timeIntervalSince(taken.at) < 6, MoreOffer.verdict(text) == true {
            takenFromPartial = nil
            host.discardAhead(reason: "more, already taken")
            host.study.discardTurnText()
            return true
        }
        // A15: in the "Mer?" window "ja" / "mer" from the wearer gets the long answer; "nej" or anything else closes it.
        guard isOpen else { return false }
        switch MoreOffer.verdict(text) {
        case true? where host.isOtherVoice(near: date) != true:
            host.discardAhead(reason: "more")
            host.study.discardTurnText()
            take(by: "voice")
            return true
        case false?:
            close(why: "no")
            host.study.discardTurnText()
            return true
        default:
            close(why: "new words")
            return false
        }
    }

    /// "ja" / nod / AirPods press in the window: the developed answer. A56: K13's `done.more` at once, without a new
    /// call (Toby T7b: 7–15 s before); `continue_more` only when it did not come.
    func take(by how: String) {
        close(why: "yes, \(how)")
        guard let host else { return }
        host.markMoreUsed()
        host.sendLengthSignal(yes: true)
        if let cached = developed, Date().timeIntervalSince(cached.at) < MoreOffer.cacheLife,
           let last = host.conversation.answers.last, last.id == cached.answerID {
            developed = nil
            host.modeLog("More: the developed answer from the same call, no new call (A56, K13)")
            host.sayDeveloped(cached.text, after: last)
            return
        }
        if host.isAnswering, host.conversation.answers.last != nil {
            // A67 (Toby T13 finding 1): the developed answer is still streaming in the same call (two_level). A new
            // "utveckla" would queue behind it (7–13 s); it is said the moment `done.more` arrives instead.
            wantedWhileStreaming = Date()
            host.modeLog("More: waiting for the developed answer still streaming (A67)")
            return
        }
        host.instruct(MoreOffer.instruction)
    }

    /// An answer's call ended: its developed part (`done.more`) is kept for "ja" (A56, K13), and said now when "ja"
    /// came while it streamed (A67).
    func answerEnded(developed more: String?, of turn: AnswerTurn) {
        if let more = more?.trimmingCharacters(in: .whitespacesAndNewlines), !more.isEmpty {
            developed = (more, Date(), turn.id) // A56 (K13): said at once on "ja"
        } else {
            developed = nil
        }
        sayIfWanted() // A67
    }

    /// A67: the call ended; say its developed answer, or ask for one when it had none.
    private func sayIfWanted() {
        guard let host, let wanted = wantedWhileStreaming else { return }
        wantedWhileStreaming = nil
        guard Date().timeIntervalSince(wanted) < 60 else { return }
        if let cached = developed, let last = host.conversation.answers.last, last.id == cached.answerID {
            developed = nil
            host.modeLog("More: the developed answer said as soon as it came (A67)")
            host.sayDeveloped(cached.text, after: last)
        } else {
            host.instruct(MoreOffer.instruction)
        }
    }

    /// Ke35: a new pass from Start begins without the last pass's developed answer.
    func forget() {
        developed = nil
    }
}

/// D199 step 5 (A120): Frågor (standardläget). Moved unchanged out of `ListeningModel`: the question gate at the
/// pause (D78) with its timer and the held half question (A21, A63), the name alone ("Ja?", A75), the hands-free turn,
/// what is answered ahead (D80), "Lumen, …" as a question, and the "Mer?" window with its two levels (`more`).
///
/// The wake word itself is heard by `ActivationController` and `VoiceChannel`, and the echo filter decides what is
/// Lumen's own voice; both stay in the model's engine. The name alone and "Mer?" are asked for in every mode, as
/// before.
@MainActor
final class StandardModeController: ListeningModeController {
    let mode: ConversationMode = .standard
    /// Set by the model right after its own init; weak, the model owns this controller.
    weak var host: (any StandardModeHost)? {
        didSet { more.host = host }
    }
    /// A15: "Mer?" and the developed answer. Shared with Provläge.
    let more = MoreWindow()

    /// A14 (Toby T6): alone, these short words are what Scribe mishears most ("kortare" heard as "högre").
    static let spokenKeyterms = ["kortare", "upprepa", "viska", "högre"]
    var spokenKeyterms: [String] { Self.spokenKeyterms }

    func startBlock() -> ModeStartBlock? { nil }
    func startScreen() -> ModeStartBlock? { nil }

    // MARK: - The turn, ahead, and "Lumen, …"

    /// Hands-free Frågor. A8.4: several questions in one breath are separate turns, each with its own answer.
    func turn(_ text: String) {
        guard let host else { return }
        var parts = QuestionSplitter.split(text)
        let first = parts.isEmpty ? text : parts.removeFirst()
        if !parts.isEmpty { host.modeLog("\(mode.rawValue): one turn split into \(parts.count + 1) parts") }
        host.queueTurns(parts) // A21.1: turns heard while the last one was answered stay queued
        host.activated(ActivationRequest(query: first, trigger: .tutor, language: host.language), persona: nil)
    }

    func aheadRequest(for text: String) -> (request: ActivationRequest, persona: PersonaRequest?)? {
        guard let host else { return nil }
        if let lone = loneNameAt, Date().timeIntervalSince(lone) <= Self.loneNameWindow {
            // Toby 1 T25 finding 9b: after "Ja?" (the name alone) the next sentence is said to Lumen, also when it
            // ends in "?": answered ahead as an address ("Lumen, …"), not as an auto question the gate can refuse.
            return (ActivationRequest(query: text, trigger: .text, language: host.language), nil)
        }
        guard !host.study.isActive, QuestionGate(sensitivity: host.activation.settings.sensitivity).evaluate(text).fires else { return nil }
        return (ActivationRequest(query: text, trigger: .auto, language: host.language), nil)
    }

    /// What follows the name when it is not a command: a question to Lumen.
    func instruction(_ text: String) {
        guard let host else { return }
        if host.study.isActive {
            host.activated(ActivationRequest(query: text, trigger: .tutor, language: host.language), persona: nil)
        } else {
            host.activated(ActivationRequest(query: text, trigger: .text, language: host.language), persona: nil)
        }
    }

    // MARK: - The name alone (A14, A75)

    /// When a lone "Lumen." was heard; the next segment within `loneNameWindow` is its command.
    private var loneNameAt: Date?
    static let loneNameWindow: TimeInterval = 8 // A75: "Ja?" and 8 s for the question

    /// A75 (Aron 20:41): the name alone (as heard: "Lumin.") always gets an answer: "Ja?", then 8 s for the question.
    func nameAlone(at date: Date) {
        guard let host else { return }
        loneNameAt = date
        host.modeLog("Name alone: \"Ja?\", waiting for the question (A75)")
        host.study.discardTurnText()
        host.discardAhead(reason: "the name alone")
        host.say(host.language == .swedish ? "Ja?" : "Yes?")
    }

    /// The segment after "Ja?". True: within the window it was said to Lumen, and it is no conversation.
    func takesAfterName(_ text: String, at date: Date) -> Bool {
        guard let host, let lone = loneNameAt else { return false }
        loneNameAt = nil
        // A75: the question after "Ja?" may overlap its end; only an echo of "Ja?" itself is not the question.
        let isEchoOfYes = ["ja", "yes"].contains(VoiceChannel.normalized(text))
        if date.timeIntervalSince(lone) <= Self.loneNameWindow, !isEchoOfYes,
           host.voice(in: WakeWord.name + ", " + text, at: date) {
            host.discardAhead(reason: "a voice command")
            return true
        }
        return false
    }

    // MARK: - The question gate at the pause (D78)

    private var questionTimer: Task<Void, Never>?
    private var halfQuestionTask: Task<Void, Never>?
    /// A72: a waiting question goes at most this long after Lumen's voice went quiet.
    static let quietMaxWait: TimeInterval = 3

    /// A final that was nothing else (no command, no echo, no hands-free turn): the gate decides if it is a question.
    func heard(_ segment: TranscriptSegment, at date: Date) {
        guard let host else { return }
        host.activation.segmentFinalized(segment, conversation: host.conversation, language: host.language,
                                         isPlaybackSpeaking: host.playbackIsSpeaking, now: date)
        if host.activation.pendingIsUnfinished {
            host.modeLog("Frågor: half a question, waiting up to \(UnfinishedQuestion.hold) s for the rest (A21)")
            askForTheRestBeforeTheHoldEnds()
        }
        scheduleQuestionTimer()
        if host.activation.pendingDueAt == nil { host.discardAhead(reason: "no question when the pause came") }
    }

    /// The question gate holds a question until the speaker is done (D78): fire it when it is due.
    private func scheduleQuestionTimer() {
        guard let due = host?.activation.pendingDueAt else { return }
        questionTimer?.cancel()
        questionTimer = Task { [weak self] in
            let wait = due.timeIntervalSinceNow
            if wait > 0 { try? await Task.sleep(for: .seconds(wait)) }
            // A8: Lumen is speaking: the question waits for the end of the answer, never dropped. A68 (Toby T13
            // finding 2): it looks again every 0.5 s instead of trusting that something asks it later; a held half
            // question waited 21 s for Scribe's session to end after the answer fetched ahead for it was dropped.
            var waited = 0
            var quietSince: Date? // A72: when Lumen's voice last went quiet
            while true {
                guard let self, let host = self.host, !Task.isCancelled else { return }
                let speaking = host.playbackIsSpeaking || host.hasPendingSpeech
                quietSince = speaking ? nil : (quietSince ?? Date())
                // A72 (Toby T14 finding 2–3): never more than `quietMaxWait` after Lumen went quiet, whatever streams.
                let overdue = quietSince.map { Date().timeIntervalSince($0) >= Self.quietMaxWait } ?? false
                if !host.lumenIsBusyAnswering || overdue {
                    if overdue, host.lumenIsBusyAnswering {
                        host.modeLog("A question waited \(Int(Self.quietMaxWait)) s after Lumen went quiet: asked now (A72) · \(host.busyReason)")
                    }
                    if !host.activation.fireDue(now: Date()) { self.scheduleQuestionTimer() } // the cooldown moved it
                    return
                }
                waited += 1
                if waited == 6 { host.modeLog("A question waits 3 s: \(host.busyReason) (A70)") } // Toby T14
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }

    /// A8: a question that waited (cooldown, Lumen speaking, or split from the same utterance) goes now that the
    /// answer before it is over. Frågor only; Provläge asks its split turns when it would listen again.
    func askWaitingQuestionIfIdle() {
        guard let host, !host.study.isActive, host.isListening, !host.voiceIsSpeaking, !host.hasPendingSpeech else { return }
        if host.isAnswering { return }
        if host.activation.pendingDueAt != nil {
            if !host.activation.fireDue(now: Date()) { scheduleQuestionTimer() }
            return
        }
        host.activation.fireNextQueued(now: Date())
    }

    /// A63 (Toby T12 finding 1): the rest of a half question came, but Scribe kept it uncommitted until its session
    /// ended (11–17 s). Before the hold is over, Scribe is asked for its final, so the rest arrives in time to be joined.
    private func askForTheRestBeforeTheHoldEnds() {
        halfQuestionTask?.cancel()
        halfQuestionTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(max(0.5, UnfinishedQuestion.hold - 1.2)))
            guard let host = self?.host, !Task.isCancelled, host.isListening, host.activation.pendingIsUnfinished else { return }
            host.modeLog("Half a question: Scribe asked for the rest now, words waiting: \(host.hasWaitingWords) (A63)")
            host.commitWaitingWords()
        }
    }
}
