import Foundation
import Observation

/// A9.3 / K10.2: a learned answer setting ("kortare svar i matte"). The backend makes it from a correction
/// (`POST /memory` with `correction`), the app keeps the list and sends it with every `/answer`.
struct PrefScope: Codable, Equatable, Sendable {
    var mode: String?
    var subject: String?
    var exam: String?
    /// `fact` | `explanation` | `math`.
    var answerType: String?

    private enum CodingKeys: String, CodingKey {
        case mode, subject, exam
        case answerType = "answer_type"
    }

    var isGlobal: Bool { mode == nil && subject == nil && exam == nil && answerType == nil }
}

struct PrefSetting: Codable, Equatable, Sendable, Identifiable {
    /// `length` | `simplicity` | `examples` | `accuracy`.
    var key: String
    var value: String
    var scope: PrefScope
    /// How many times the user gave this correction.
    var n: Int?

    var id: String { [key, value, scope.mode ?? "", scope.subject ?? "", scope.exam ?? "", scope.answerType ?? ""].joined(separator: "|") }

    /// The readable line for Minne, the same words as Kevin's `describe()` (`memory/settings.ts`).
    var text: String {
        let words: [String: String] = [
            "length:shorter": "kortare svar", "length:longer": "längre, utförligare svar", "simplicity:simpler": "enklare förklaringar",
            "examples:more": "fler exempel", "accuracy:careful": "extra noggrann kontroll av fakta",
        ]
        let kinds = ["fact": "faktasvar", "explanation": "förklaringar", "math": "matte"]
        let modes = ["prov": "Provläge", "fragor": "Frågor", "intervju": "Intervju", "socialt": "Socialt", "rizz": "Rizz"]
        let what = words["\(key):\(value)"] ?? "\(key) \(value)"
        var line = what.prefix(1).uppercased() + what.dropFirst()
        if let kind = scope.answerType {
            line += " i " + (kinds[kind] ?? kind)
        } else if let subject = scope.subject {
            line += " i " + subject.lowercased()
        } else if let exam = scope.exam {
            line += " inför " + exam
        } else if let mode = scope.mode {
            line += " i " + (modes[mode] ?? mode)
        }
        return line
    }
}

/// The backend's names for the modes (K10: `fragor|prov|intervju|socialt|rizz`).
extension ConversationMode {
    var backendName: String {
        switch self {
        case .standard: "fragor"
        case .prov: "prov"
        case .interview: "intervju"
        case .social: "socialt"
        case .rizz: "rizz"
        }
    }

    init?(backendName: String) {
        guard let mode = ConversationMode.allCases.first(where: { $0.backendName == backendName }) else { return nil }
        self = mode
    }
}

/// K10.2's reply to a correction.
struct CorrectionReply: Decodable, Equatable, Sendable {
    struct Changed: Decodable, Equatable, Sendable {
        var text: String?
    }

    var settings: [PrefSetting]?
    var setting: Changed?
    var profile: String?
    var skipped: String?
}

/// Minne › Inlärda inställningar (A9.3), kept on the phone (UserDefaults) and sent with every answer.
@MainActor
@Observable
final class PreferenceStore {
    static let key = "preferences.settings"
    static let limit = 30

    private(set) var settings: [PrefSetting] = []
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key), let stored = try? JSONDecoder().decode([PrefSetting].self, from: data) {
            settings = stored
        }
    }

    /// The backend's list after a correction.
    func replace(with new: [PrefSetting]) {
        settings = Array(new.prefix(Self.limit))
        persist()
    }

    func remove(_ setting: PrefSetting) {
        settings.removeAll { $0.id == setting.id }
        persist()
    }

    /// "Gäller överallt": the user widens a setting to every mode and subject.
    func makeGlobal(_ setting: PrefSetting) {
        guard let index = settings.firstIndex(where: { $0.id == setting.id }) else { return }
        settings[index].scope = PrefScope()
        // A global one replaces the narrower ones with the same key and value.
        let widened = settings[index]
        settings.removeAll { $0.key == widened.key && $0.value == widened.value && !$0.scope.isGlobal }
        if !settings.contains(where: { $0.id == widened.id }) { settings.append(widened) }
        persist()
    }

    /// K10.3's profile, made the same way on the phone so local edits count at once (≤ 300 characters).
    var profile: String {
        guard !settings.isEmpty else { return "" }
        let sorted = settings.sorted { ($0.n ?? 1) > ($1.n ?? 1) }
        let head = "Användaren vill ha: "
        var parts: [String] = []
        for setting in sorted {
            let line = setting.text
            let lower = line.prefix(1).lowercased() + line.dropFirst()
            if (head + (parts + [lower]).joined(separator: "; ") + ".").count > 300 { break }
            parts.append(lower)
        }
        return parts.isEmpty ? "" : head + parts.joined(separator: "; ") + "."
    }

    private func persist() {
        defaults.set(try? JSONEncoder().encode(settings), forKey: Self.key)
    }
}

/// K10.1: "kan vi byta till frågor" in the user's own words. Sure (≥ 0.8): the app does it, the backend says nothing.
struct AppCommand: Codable, Equatable, Sendable {
    /// `switch_mode` | `pause` | `stop` | `resume`.
    var action: String
    var mode: String?
    var confidence: Double?

    static let sure = 0.8
    var isSure: Bool { (confidence ?? 0) >= Self.sure }
}

/// A9.2: "nej", "ångra", "fel" right after an app command takes it back.
enum UndoWords {
    private static let phrases: Set<String> = [
        "nej", "ångra", "ångra det", "fel", "nej ångra", "nej fel", "det var fel", "nej det var fel", "inte det", "nej inte det",
        "no", "undo", "wrong",
    ]

    static func matches(_ text: String) -> Bool {
        phrases.contains(VoiceChannel.normalized(text))
    }
}
