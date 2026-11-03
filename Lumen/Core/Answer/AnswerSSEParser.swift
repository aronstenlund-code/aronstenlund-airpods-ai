import Foundation

/// One server-sent event: `event:` name and the joined `data:` lines.
struct SSEEvent: Equatable, Sendable {
    var name: String?
    var data: String
}

/// Incremental SSE line parser (text/event-stream): feed lines, get an event at every blank line.
/// Handles CRLF, multi-line `data:`, comments (`:`) and events without a name. Pure; unit-tested.
struct SSELineParser: Sendable {
    private var name: String?
    private var dataLines: [String] = []

    init() {}

    /// Returns a completed event when `line` is the blank separator, else nil.
    mutating func feed(_ rawLine: String) -> SSEEvent? {
        var line = rawLine
        if line.hasSuffix("\r") { line.removeLast() }
        if line.isEmpty {
            return flush()
        }
        if line.hasPrefix(":") { return nil } // comment / keep-alive
        let field: Substring
        let value: Substring
        if let colon = line.firstIndex(of: ":") {
            field = line[..<colon]
            var rest = line[line.index(after: colon)...]
            if rest.hasPrefix(" ") { rest = rest.dropFirst() }
            value = rest
        } else {
            field = Substring(line)
            value = ""
        }
        switch field {
        case "event": name = String(value)
        case "data": dataLines.append(String(value))
        default: break // id, retry: ignored
        }
        return nil
    }

    /// Emits whatever is pending (end of stream without a trailing blank line).
    mutating func flush() -> SSEEvent? {
        guard name != nil || !dataLines.isEmpty else { return nil }
        let event = SSEEvent(name: name, data: dataLines.joined(separator: "\n"))
        name = nil
        dataLines = []
        return event
    }
}

/// Maps the backend's SSE events to `AnswerEvent` (`backend/README.md`).
enum AnswerSSEDecoder {
    static func decode(_ event: SSEEvent) throws(AnswerError) -> AnswerEvent? {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let data = Data(event.data.utf8)
        do {
            switch event.name {
            case "meta":
                return .meta(try decoder.decode(AnswerMeta.self, from: data))
            case "delta":
                struct Delta: Decodable { var text: String }
                return .delta(try decoder.decode(Delta.self, from: data).text)
            case "done":
                return .done(try decoder.decode(AnswerDone.self, from: data))
            case "error":
                return .error(try decoder.decode(AnswerFailure.self, from: data))
            default:
                return nil // unknown event names are ignored (forward compatibility)
            }
        } catch {
            throw AnswerError.decoding(detail: "\(event.name ?? "?"): \(error.localizedDescription)")
        }
    }

    /// Pre-stream error body: `{"error":{"code","message","fallback"}}`.
    static func decodeErrorBody(_ data: Data, status: Int) -> AnswerFailure {
        struct Body: Decodable { var error: AnswerFailure }
        if let body = try? JSONDecoder().decode(Body.self, from: data) {
            return body.error
        }
        // Supabase Auth style: {"code":422,"error_code":"anonymous_provider_disabled","msg":"..."}
        struct AuthBody: Decodable { var error_code: String?; var msg: String?; var message: String? }
        if let auth = try? JSONDecoder().decode(AuthBody.self, from: data) {
            return AnswerFailure(code: auth.error_code ?? "http_\(status)", message: auth.msg ?? auth.message, fallback: status >= 500)
        }
        let text = String(decoding: data.prefix(200), as: UTF8.self)
        return AnswerFailure(code: "http_\(status)", message: text.isEmpty ? nil : text, fallback: status >= 500)
    }
}
