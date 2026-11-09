import Foundation
import Observation

/// A9.1: the three most useful commands per mode (the listening screen) and, now and then, one short tip about a
/// command the user has not used. Rules: at most one tip per session and one per day, only in a natural pause,
/// never during an exam session, a mini test or an interview question, never a command already used, and off with
/// one switch. The wording comes from `CommandRegistry`, so a renamed phrase shows up here too.
enum CommandTips {
    /// The screen's three, most useful first.
    static func top(for mode: ConversationMode) -> [CommandAction] {
        switch mode {
        case .prov: [.quizMe, .shorter, .musicHandOff]
        case .standard: [.switchMode, .repeatAnswer, .musicHandOff]
        case .interview: [.interviewHelp, .interviewStuck, .stop]
        case .social: [.socialReply, .threeOptions, .musicHandOff]
        case .rizz: [.rizz, .rescue, .threeOptions]
        }
    }

    /// Tip candidates, in order: what helps most in that mode.
    static func candidates(for mode: ConversationMode) -> [CommandAction] {
        switch mode {
        case .prov: [.shorter, .repeatAnswer, .moreDetail, .example, .quickQuiz, .whisper, .saveAnswer, .nextExam]
        case .standard: [.shorter, .repeatAnswer, .saveAnswer, .moreDetail, .whisper, .nextTrack]
        case .interview: [.interviewStuck, .interviewBetter, .interviewCounter]
        case .social: [.threeOptions, .followUp, .changeTopic]
        case .rizz: [.rescue, .subtler, .threeOptions]
        }
    }

    /// How the screen and the tip say a command: "Lumen, kortare", "Lumen, byt till provläge".
    static func spoken(_ action: CommandAction, table: CommandTable) -> String {
        if action == .switchMode { return "Lumen, byt till provläge" }
        let phrase = table.phrases(for: action).first ?? action.defaultPhrases.first ?? action.rawValue
        return "Lumen, " + phrase
    }

    /// "Säg ”Lumen, förhör mig”, ”Lumen, kortare” eller ”Lumen, pausa”."
    static func line(for mode: ConversationMode, table: CommandTable) -> String {
        let quoted = top(for: mode).map { "”" + spoken($0, table: table) + "”" }
        guard quoted.count > 1 else { return "Säg " + (quoted.first ?? "”Lumen, …”") + "." }
        return "Säg " + quoted.dropLast().joined(separator: ", ") + " eller " + quoted.last! + "."
    }

    /// The one-line tip, said in a pause and shown on the screen.
    static func tip(_ action: CommandAction, table: CommandTable) -> String {
        "Tips: säg ”" + spoken(action, table: table) + "”" + (reason(action).map { " " + $0 } ?? "") + "."
    }

    private static func reason(_ action: CommandAction) -> String? {
        switch action {
        case .shorter: "om svaren är för långa"
        case .repeatAnswer: "om du vill höra svaret igen"
        case .moreDetail: "om du vill veta mer"
        case .example: "för ett exempel"
        case .quickQuiz: "för fem snabba frågor"
        case .whisper: "om rösten är för hög"
        case .saveAnswer: "så hamnar svaret i Anteckningar"
        case .nextExam: "så hör du när nästa prov är"
        case .nextTrack: "medan du lyssnar för att byta låt"
        case .interviewStuck: "när du inte vet vad du ska säga"
        case .threeOptions: "för fler förslag"
        case .rescue: "när samtalet går dåligt"
        default: nil
        }
    }
}

/// What has been used and when the last tip came (UserDefaults), and the switch.
@MainActor
@Observable
final class CommandTipStore {
    static let usedKey = "commands.tips.used"
    static let lastTipKey = "commands.tips.lastAt"
    static let enabledKey = "commands.tips.enabled"
    static let minimumGap: TimeInterval = 24 * 3_600

    var enabled: Bool {
        didSet { defaults.set(enabled, forKey: Self.enabledKey) }
    }
    private(set) var used: Set<CommandAction>
    private(set) var lastTipAt: Date?
    /// One per session: set when a tip is given, cleared when a session starts.
    private(set) var tippedThisSession = false
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        enabled = defaults.object(forKey: Self.enabledKey) as? Bool ?? true
        used = Set((defaults.stringArray(forKey: Self.usedKey) ?? []).compactMap(CommandAction.init(rawValue:)))
        lastTipAt = defaults.object(forKey: Self.lastTipKey) as? Date
    }

    func markUsed(_ action: CommandAction) {
        guard used.insert(action).inserted else { return }
        defaults.set(used.map(\.rawValue).sorted(), forKey: Self.usedKey)
    }

    func sessionStarted() {
        tippedThisSession = false
    }

    /// The command to tip now, or nil. `busy`: an exam session, a mini test, a quiz, Lumen speaking or a question
    /// waiting. The caller asks only in a pause.
    func next(for mode: ConversationMode, busy: Bool, now: Date = Date()) -> CommandAction? {
        guard enabled, !busy, !tippedThisSession else { return nil }
        if let last = lastTipAt, now.timeIntervalSince(last) < Self.minimumGap { return nil }
        return CommandTips.candidates(for: mode).first { !used.contains($0) }
    }

    func tipped(_ action: CommandAction, at now: Date = Date()) {
        tippedThisSession = true
        lastTipAt = now
        defaults.set(now, forKey: Self.lastTipKey)
        // A tipped command is not tipped again, used or not.
        markUsed(action)
    }
}
