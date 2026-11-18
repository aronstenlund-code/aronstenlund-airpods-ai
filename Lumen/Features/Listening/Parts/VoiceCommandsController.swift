import Foundation
import Observation

/// D231 (A149, G7 step 7b): what the voice channel uses of `ListeningModel`: the model's own calls, unchanged. What
/// touches the session and the sound stays in the model and is asked for here: the switch, the pause and the stop by
/// voice, the music, the loudness, and "upprepa" (the kept audio and the recogniser's gate).
@MainActor
protocol VoiceCommandsHost: ListeningModeHost {
    var mode: ConversationMode { get }
    var isListening: Bool { get }
    var speaker: Speaker { get }
    var tips: CommandTipStore { get }
    var memory: MemoryStore { get }
    var conversation: Conversation { get }
    var answers: AnswerEngine { get }
    var activation: ActivationController { get }
    var transcription: TranscriptionCoordinator { get }
    var examPlans: ExamPlanStore? { get }
    /// The exercises a tip never interrupts.
    var exam: ExamSession? { get }
    var practice: PracticeRun? { get }
    var miniTest: MiniTest? { get }
    /// When something was last heard: a tip waits for a natural pause.
    var lastHeardAt: Date? { get }
    func say(_ line: String)
    /// What follows the name when it is not a command (a question to Lumen, or D69's instruction path).
    func instruct(_ text: String)
    /// A9.3: a correction of the answer just given.
    func learnCorrection(_ text: String)
    func refreshKeyterms()
    func saveNote() -> Note?
    func switchByVoice(to target: ConversationMode) async
    func pauseByVoice() async
    func stopByVoice() async
    func musicByVoice(_ action: CommandAction) async
    /// "Det där var fel": the last turn goes to /feedback.
    func reportPreviousTurn() async
    /// A7: Lumen's loudness after "viska" / "högre".
    func applySpeechVolume()
    /// A7 "upprepa": the last answer again (the kept audio; the model owns the sound).
    func repeatLastAnswer()
}

/// D74, A7, A9 (A149, D231, G7 step 7b): the voice channel. "Lumen, …" in every mode: what the words mean and what is
/// done with them, the short commands that count without the name, and the tips. Moved unchanged out of
/// `ListeningModel`. It is no mode: it is asked before every mode.
@MainActor
@Observable
final class VoiceCommandsController {
    /// Set by the model right after its own init; weak, the model owns this part.
    @ObservationIgnored weak var host: (any VoiceCommandsHost)?
    /// A9.1: the tip being said, for the listening screen.
    private(set) var tipNotice: String?
    @ObservationIgnored private var tipTask: Task<Void, Never>?
    /// The same command twice within 5 s is one command (the partial and the final result both carry it).
    @ObservationIgnored private var lastVoice: (intent: VoiceIntent, at: Date)?

    /// "Lumen, …" in every mode. True when the words were for Lumen: they are never conversation.
    @discardableResult
    func heard(in text: String, at date: Date) -> Bool {
        guard let host else { return false }
        let utterance = VoiceChannel.parse(text)
        guard let intent = utterance.intent ?? universalIntent(text) else { return false }
        host.study.discardTurnText()
        if let before = utterance.before, host.study.isActive { host.study.transcriptFinal(before, at: date) }
        perform(intent)
        return true
    }

    /// A7: "upprepa", "viska", "kortare", "utveckla" … as the whole utterance count without "Lumen", only in
    /// Provläge and Frågor (the speaker is the user there) and only with the setting on.
    private func universalIntent(_ text: String) -> VoiceIntent? {
        guard let host, host.mode == .prov || host.mode == .standard, host.speaker.settings.universalCommands,
              let action = CommandBook.shared.table.universal(text) else { return nil }
        return action.level == 1 ? .command(action) : .instruction(action.instruction)
    }

    /// A13.3: the "Förhör mig" button on Provläge's empty screen: the same as saying "Lumen, förhör mig".
    func askForQuiz() {
        guard let host else { return }
        host.tips.markUsed(.quizMe)
        host.instruct("förhör mig")
    }

    /// A9.1: a used command is never tipped.
    private func markUsed(_ intent: VoiceIntent) {
        guard let tips = host?.tips else { return }
        switch intent {
        case .switchTo: tips.markUsed(.switchMode)
        case .pause: tips.markUsed(.musicHandOff)
        case .stopListening: tips.markUsed(.stop)
        case .music(let action), .command(let action): tips.markUsed(action)
        case .complaint: tips.markUsed(.wrong)
        case .instruction(let text):
            if let action = CommandAction.allCases.first(where: { $0.level == 2 && $0.instruction == text }) { tips.markUsed(action) }
            else if text.hasPrefix("förhör mig") { tips.markUsed(.quizMe) }
        case .remember, .forget, .rule: break
        }
    }

    /// A9.1: after an answer, in a natural pause, at most one tip per session and per day. Never during an exam
    /// session, a mini test, Intervjuläge's question or while anything is heard or said.
    func scheduleTip() {
        tipTask?.cancel()
        guard let host, host.tips.enabled, !host.tips.tippedThisSession, host.conversation.answers.count >= 2 else { return }
        tipTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.tipPause))
            guard let self, let host = self.host, !Task.isCancelled, host.isListening else { return }
            let quietFor = host.lastHeardAt.map { Date().timeIntervalSince($0) } ?? .infinity
            var busy = host.exam != nil || host.practice != nil || host.miniTest != nil || host.speaker.isSpeaking || host.speaker.hasPendingSpeech
                || host.activation.pendingDueAt != nil || host.activation.hasQueued || quietFor < Self.tipPause
                || host.transcription.hasWaitingWords || host.transcription.vadSpeaking() == true // A56 (Toby T5b finding 3)
            if case .answering = host.answers.status { busy = true }
            guard let action = host.tips.next(for: host.mode, busy: busy) else { return }
            let text = CommandTips.tip(action, table: CommandBook.shared.table)
            host.tips.tipped(action)
            self.tipNotice = text
            host.modeLog("Tip: \(action.rawValue)")
            host.say(text)
        }
    }

    /// A new answer begins: no tip is waiting, and none is shown.
    func clearTip() {
        tipTask?.cancel()
        tipNotice = nil
    }

    static let tipPause: TimeInterval = 4

    /// The listening screen's line: the three most useful commands for the mode, from the command table.
    func commandsLine(for shown: ConversationMode) -> String {
        CommandTips.line(for: shown, table: CommandBook.shared.table)
    }

    func perform(_ intent: VoiceIntent) {
        guard let host else { return }
        let now = Date()
        if let last = lastVoice, last.intent == intent, now.timeIntervalSince(last.at) < 5 { return }
        lastVoice = (intent, now)
        markUsed(intent)
        switch intent {
        case .switchTo(let target):
            host.modeLog("Voice: switch to \(target.rawValue)")
            Task { await host.switchByVoice(to: target) }
        case .pause:
            host.modeLog("Voice: pause")
            Task { await host.pauseByVoice() }
        case .stopListening:
            host.modeLog("Voice: stop listening")
            Task { await host.stopByVoice() }
        case .instruction(let text):
            host.modeLog("Voice: instruction (\(text.count) characters)") // the words stay out of the log
            // A9.3: these presets are also corrections of the answer just given.
            if ["förklara enklare", "ge ett exempel"].contains(text) { host.learnCorrection(text == "ge ett exempel" ? "mer exempel" : "enklare") }
            host.instruct(text)
        case .remember(let text):
            if host.memory.add(text, kind: .fact, source: .voice) != nil {
                host.modeLog("Voice: remembered (\(text.count) characters)")
                host.say(host.language == .swedish ? "Sparat." : "Saved.")
                host.refreshKeyterms()
            }
        case .forget(let text):
            let removed = host.memory.forget(text)
            host.modeLog("Voice: forgot \(removed) item(s)")
            host.say(removed > 0 ? (host.language == .swedish ? "Glömt." : "Forgotten.")
                                 : (host.language == .swedish ? "Hittade inget att glömma." : "Nothing to forget."))
            host.refreshKeyterms()
        case .rule(let text):
            if host.memory.add(text, kind: .rule, source: .voice) != nil {
                host.modeLog("Voice: rule saved")
                host.say(host.language == .swedish ? "Regel sparad." : "Rule saved.")
            }
        case .music(let action):
            host.modeLog("Voice: music \(action.rawValue)")
            Task { await host.musicByVoice(action) }
        case .complaint:
            host.modeLog("Voice feedback: the last turn goes to /feedback")
            host.learnCorrection("det där var fel")
            Task { await host.reportPreviousTurn() }
        case .command(let action):
            host.modeLog("Voice: command \(action.rawValue)")
            runCommand(action)
        }
    }

    /// A7 level 1: done on the phone, no API call. Confirmed briefly, only when nothing else is being said.
    func runCommand(_ action: CommandAction) {
        guard let host else { return }
        func confirm(_ line: String?) {
            guard let line, !host.speaker.isSpeaking, !host.speaker.hasPendingSpeech else { return }
            host.say(line)
        }
        switch action {
        case .repeatAnswer:
            host.repeatLastAnswer()
        case .whisper, .louder:
            let settings = host.speaker.settings
            if action == .louder, settings.speechGain >= 1 {
                confirm("Det är redan högsta volymen i EarMind. Höj på telefonen.")
                return
            }
            settings.speechGain = action == .whisper ? settings.speechGain * 0.6 : settings.speechGain / 0.6
            host.applySpeechVolume()
            host.modeLog("Voice gain \(String(format: "%.2f", settings.speechGain))")
            confirm(action.confirmation)
        case .shorter, .longer:
            host.learnCorrection(action == .shorter ? "kortare" : "längre")
            host.answers.sessionLength = action == .shorter ? .short : .long
            host.modeLog("Session length \(host.answers.sessionLength?.rawValue ?? "-")")
            confirm(action.confirmation)
        case .saveAnswer:
            confirm(host.saveNote() != nil ? action.confirmation : "Det finns inget svar att spara.")
        case .nextExam:
            if let plan = host.examPlans?.nearest() {
                host.say("\(plan.name), \(plan.whenLine()).")
            } else {
                host.say("Du har inget prov inlagt.")
            }
        default:
            break
        }
    }
}
