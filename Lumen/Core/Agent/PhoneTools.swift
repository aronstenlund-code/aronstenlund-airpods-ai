import Foundation

/// A48 (D122, Kevin K35): phone tools the agent may use. The model picks one in `/answer`, the server checks its
/// input and sends `tool_call`; the app asks the user when the call changes something (`confirm`), runs it only after a
/// yes, and sends `tool_round` with the result, so the model can say one short sentence about it.
/// Protocol: `docs/AGENT.md` ("Telefonverktyg: protokollet").

/// Any JSON value: the tool's input and result go back to the server exactly as they came.
enum JSONValue: Codable, Equatable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null }
        else if let value = try? container.decode(Bool.self) { self = .bool(value) }
        else if let value = try? container.decode(Double.self) { self = .number(value) }
        else if let value = try? container.decode(String.self) { self = .string(value) }
        else if let value = try? container.decode([JSONValue].self) { self = .array(value) }
        else { self = .object(try container.decode([String: JSONValue].self)) }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }

    subscript(key: String) -> JSONValue? {
        if case .object(let value) = self { return value[key] }
        return nil
    }

    var string: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    var number: Double? {
        if case .number(let value) = self { return value }
        return nil
    }

    var bool: Bool? {
        if case .bool(let value) = self { return value }
        return nil
    }
}

enum PhoneTool: String, CaseIterable, Sendable {
    case calendarAdd = "calendar_add"
    case calendarList = "calendar_list"
    case reminderAdd = "reminder_add"
    case timerStart = "timer_start"
    case alarmSet = "alarm_set"
    case noteAdd = "note_add"
}

/// SSE `tool_call`: `{id, name, input, confirm, kind}`. The server writes `confirm` (Swedish yes/no question) for the
/// tools that change something; null means run at once.
struct PhoneToolCall: Decodable, Equatable, Sendable {
    var id: String
    var name: String
    var input: JSONValue
    var confirm: String?
    var kind: String?

    var tool: PhoneTool? { PhoneTool(rawValue: name) }
}

/// `tool_round` in the second `/answer` call.
struct ToolRound: Encodable, Equatable, Sendable {
    struct Call: Encodable, Equatable, Sendable {
        var id: String
        var name: String
        var input: JSONValue
    }

    enum Status: String, Encodable, Sendable {
        case ok, declined, error
    }

    var call: Call
    var status: Status
    var result: JSONValue?

    init(call: PhoneToolCall, status: Status, result: JSONValue? = nil) {
        self.call = Call(id: call.id, name: call.name, input: call.input)
        self.status = status
        self.result = result
    }
}

/// The user's answer to `confirm`, by voice.
enum ToolConfirmReply: Equatable, Sendable {
    case yes, no, other

    static func parse(_ text: String) -> ToolConfirmReply {
        let key = AheadAnswer.key(text)
        let yes = ["ja", "japp", "jajamen", "ja tack", "ja gör det", "gör det", "okej", "ok", "absolut", "visst", "kör", "yes", "yes please", "sure"]
        let no = ["nej", "nej tack", "nä", "nää", "avbryt", "stopp", "strunta i det", "låt bli", "no", "cancel"]
        if yes.contains(key) || yes.contains(where: { key.hasPrefix($0 + " ") && key.count <= $0.count + 12 }) { return .yes }
        if no.contains(key) || no.contains(where: { key.hasPrefix($0 + " ") && key.count <= $0.count + 12 }) { return .no }
        return .other
    }
}

/// Times from the server: local Swedish time in ISO without a zone ("2026-11-12T15:00"), or a date ("2026-11-12").
enum PhoneToolTime {
    static func date(_ text: String?, calendar: Calendar = .current) -> Date? {
        guard let text else { return nil }
        let parts = text.split(whereSeparator: { "-T:".contains($0) }).compactMap { Int($0) }
        guard parts.count >= 3 else { return nil }
        var components = DateComponents(year: parts[0], month: parts[1], day: parts[2],
                                        hour: parts.count > 3 ? parts[3] : 0, minute: parts.count > 4 ? parts[4] : 0)
        components.calendar = calendar
        return calendar.date(from: components)
    }

    /// "06:30" → the next 06:30 from now (today if still ahead, else tomorrow).
    static func nextTime(_ text: String?, now: Date = Date(), calendar: Calendar = .current) -> Date? {
        guard let text else { return nil }
        let parts = text.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2, (0..<24).contains(parts[0]), (0..<60).contains(parts[1]) else { return nil }
        guard let today = calendar.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: now) else { return nil }
        return today > now ? today : calendar.date(byAdding: .day, value: 1, to: today)
    }

    /// "2026-11-12T15:00" for `calendar_list`'s events.
    static func text(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return String(format: "%04d-%02d-%02dT%02d:%02d", c.year ?? 2000, c.month ?? 1, c.day ?? 1, c.hour ?? 0, c.minute ?? 0)
    }
}

/// What runs a tool. `LivePhoneTools` on the phone; a fake in the tests.
@MainActor
protocol PhoneToolRunning: AnyObject {
    /// The tools this phone can run (AlarmKit needs iOS 26; all of them here).
    var available: [PhoneTool] { get }
    /// Runs the call (after the user said yes when it changes something). Permission is asked here, the first time.
    func run(_ call: PhoneToolCall) async -> (status: ToolRound.Status, result: JSONValue?)
}
