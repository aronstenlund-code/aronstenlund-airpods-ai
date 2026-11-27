import SwiftUI

/// Deangelo 2026-11-27 04:10: Inställningar short and plain – the most important first (language, activation words,
/// voice, credits), what must always be found next (history, privacy, the account, help), the rest under Avancerat.
/// Every row says in one sentence what it does. The order and the sentences live here so they are tested.
enum SettingsRow: String, CaseIterable, Sendable {
    case language, activationWords, voice, credits
    case history, privacy, account, help, feedback, about
    case reminders, answerLength, voiceCommands, memory, appearance, spokenLanguage, notes, studyCards, preparations,
         customCommands, practiceQuestions

    /// At the top, in this order.
    static let top: [SettingsRow] = [.language, .activationWords, .voice, .credits]
    /// Always visible after the top: what must be found without opening Avancerat.
    static let always: [SettingsRow] = [.history, .privacy, .account, .help, .feedback, .about]
    /// Under Avancerat (with the technical sections: microphone, speech recognition, pauses, the voice profile, …).
    static let advanced: [SettingsRow] = [.reminders, .answerLength, .voiceCommands, .memory, .appearance, .spokenLanguage,
                                          .notes, .studyCards, .preparations, .customCommands, .practiceQuestions]

    var title: String {
        switch self {
        case .language: String(localized: "Språk")
        case .activationWords: String(localized: "Aktiveringsord")
        case .voice: String(localized: "Röst")
        case .credits: String(localized: "Krediter")
        case .history: String(localized: "Historik")
        case .privacy: String(localized: "Integritet och samtycke")
        case .account: String(localized: "Konto")
        case .help: String(localized: "Fråga om EarMind")
        case .feedback: String(localized: "Feedback och förslag")
        case .about: String(localized: "Om appen")
        case .reminders: String(localized: "Påminnelser")
        case .answerLength: String(localized: "Svarslängd")
        case .voiceCommands: String(localized: "Röstkommandon")
        case .memory: String(localized: "Minne")
        case .appearance: String(localized: "Utseende")
        case .spokenLanguage: String(localized: "Språk du pratar")
        case .notes: String(localized: "Anteckningar")
        case .studyCards: String(localized: "Studiekort")
        case .preparations: String(localized: "Förberedelser")
        case .customCommands: String(localized: "Egna kommandon")
        case .practiceQuestions: String(localized: "Provfrågor")
        }
    }

    /// One sentence: what the row does.
    var detail: String {
        switch self {
        case .language: String(localized: "Gäller appens texter och EarMinds svar.")
        case .activationWords: String(localized: "När orden hörs svarar EarMind på frågan som just ställdes.")
        case .voice: String(localized: "Rösten som läser upp svaren, eller tyst.")
        case .credits: String(localized: "Vad du har kvar, vad saker kostar och fyll på.")
        case .history: String(localized: "Dina frågor och svar: sök och spela upp igen.")
        case .privacy: String(localized: "Vad som skickas och sparas, och hur du tar tillbaka samtycket.")
        case .account: String(localized: "Radera ditt konto och allt som hör till det.")
        case .help: String(localized: "Ställ en fråga om appen och få svar direkt.")
        case .feedback: String(localized: "Berätta vad som är fel eller vad du saknar.")
        case .about: String(localized: "Version, licenser och hur EarMind fungerar.")
        case .reminders: String(localized: "En påminnelse om dagen att plugga.")
        case .answerLength: String(localized: "Hur långa svaren är när du lyssnar.")
        case .voiceCommands: String(localized: "Det du kan säga efter ”Lumen”.")
        case .memory: String(localized: "Det EarMind kommer ihåg om dig, och dina regler.")
        case .appearance: String(localized: "Ljust, mörkt eller som iPhonen.")
        case .spokenLanguage: String(localized: "Språket EarMind lyssnar efter.")
        case .notes: String(localized: "Samtal du har sparat.")
        case .studyCards: String(localized: "Vändkort från dina frågor.")
        case .preparations: String(localized: "Ord och ämnen EarMind ska kunna inför ett prov.")
        case .customCommands: String(localized: "Dina egna ord för det EarMind gör.")
        case .practiceQuestions: String(localized: "Bli förhörd på frågor från ett prov.")
        }
    }
}

/// A settings row's label: the title, and under it the one sentence about what it does.
struct SettingsRowLabel: View {
    let row: SettingsRow
    var value: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: row.title)
                Text(verbatim: row.detail).font(.subheadline).foregroundStyle(.secondary)
            }
            if let value {
                Spacer(minLength: 8)
                Text(verbatim: value).foregroundStyle(.secondary).monospacedDigit()
            }
        }
        .accessibilityElement(children: .combine)
    }
}
