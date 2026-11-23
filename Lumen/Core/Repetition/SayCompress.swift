import Foundation

/// A163 (D259): why the server did not shorten a text.
enum ShortenFailure: Error, Equatable {
    /// 503/502 `provider_*`: the model behind EarMind is out of credits, busy or down (O97, D258).
    case modelDown
    /// The server does not have the action yet (400 `invalid_request`).
    case notOnServer
    case offline
    /// The server's own words to the user (a limit).
    case refused(String)
    case server
}

/// What shortens a text on the server. The tests use a pretend one.
@MainActor
protocol TextShortening: AnyObject {
    func shorten(_ text: String) async -> Result<String, ShortenFailure>
}

/// `POST /exam {"action": "compress", "text", "lang"}` → `{"text"}`. The action is Kevin's to add (asked for in his
/// queue); until it is there the server answers 400 and the phone's own model shortens instead.
@MainActor
final class TextShortenClient: TextShortening {
    static let maxChars = 12_000

    private let config: BackendConfig
    private let auth: SupabaseAuth
    private let http: any HTTPStreaming

    init(config: BackendConfig, auth: SupabaseAuth, http: any HTTPStreaming) {
        self.config = config
        self.auth = auth
        self.http = http
    }

    func shorten(_ text: String) async -> Result<String, ShortenFailure> {
        let response: HTTPURLResponse
        let data: Data
        do {
            let token = try await auth.accessToken()
            var request = URLRequest(url: config.examURL)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue(config.publishableKey, forHTTPHeaderField: "apikey")
            request.markTestTraffic()
            request.markLanguage()
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 45
            let body: [String: Any] = ["action": "compress", "text": String(text.prefix(Self.maxChars))]
            request.httpBody = try JSONSerialization.data(withJSONObject: AppLanguage.stamped(body))
            (response, data) = try await http.data(for: request)
        } catch {
            Log.repetition.error("compress: \(error.localizedDescription, privacy: .public)")
            return .failure(.offline)
        }
        struct Reply: Decodable { var text: String }
        if response.statusCode == 200 {
            guard let reply = try? JSONDecoder().decode(Reply.self, from: data) else { return .failure(.server) }
            return .success(reply.text)
        }
        struct Fault: Decodable {
            struct Inner: Decodable { var code: String?; var message: String? }
            var error: Inner?
        }
        let fault = (try? JSONDecoder().decode(Fault.self, from: data))?.error
        Log.repetition.error("compress: HTTP \(response.statusCode, privacy: .public) \(fault?.code ?? "-", privacy: .public)")
        if ServerTrouble.isProvider(fault?.code) { return .failure(.modelDown) }
        if response.statusCode == 400 || response.statusCode == 404 { return .failure(.notOnServer) }
        if (400..<500).contains(response.statusCode), response.statusCode != 401, let message = fault?.message, !message.isEmpty {
            return .failure(.refused(message))
        }
        return .failure(.server)
    }
}

/// The mock mode (the Simulator tests and pictures, Debug only): no server and no model. The first half of the
/// text's sentences, so the way through the app can be seen: the shorter text in the field, and Ångra.
@MainActor
final class MockTextShortener: TextShortening {
    func shorten(_ text: String) async -> Result<String, ShortenFailure> {
        .success(Self.firstHalf(text))
    }

    static func firstHalf(_ text: String) -> String {
        let sentences = text.replacingOccurrences(of: "\n", with: " ").components(separatedBy: ". ").filter { !$0.isEmpty }
        guard sentences.count > 1 else {
            let words = text.split(separator: " ")
            return words.prefix(max(1, words.count / 2)).joined(separator: " ")
        }
        let kept = sentences.prefix(max(1, sentences.count / 2)).joined(separator: ". ")
        return kept.hasSuffix(".") ? kept : kept + "."
    }
}

/// Komprimera: the server's model first; when the server cannot (its model is down, it does not have the action,
/// no network), the phone's own model if it is there and knows the language (D258). No credits are counted for the
/// phone's work and nothing is sent for it.
@MainActor
final class SayCompressor {
    enum By: Equatable, Sendable {
        case server
        case phone
    }

    enum Outcome: Equatable, Sendable {
        case shortened(String, by: By)
        /// The text stays as it was; one line says why.
        case failed(String)
    }

    private let server: any TextShortening
    private let phone: any OnDeviceModel
    private let language: @MainActor () -> String

    init(server: any TextShortening, phone: any OnDeviceModel,
         language: @escaping @MainActor () -> String = { AppLanguage.current.code }) {
        self.server = server
        self.phone = phone
        self.language = language
    }

    static func instructions(_ language: String) -> String {
        language == "sv"
            ? "Du kortar en text till ungefär hälften. Behåll innehållet, fakta, namn och siffror. Ge bara den kortare texten, "
                + "utan inledning. Svara på svenska om texten är på svenska, annars på textens språk."
            : "You shorten a text to about half. Keep the content, facts, names and numbers. Give only the shorter text, "
                + "with no introduction. Answer in English if the text is in English, otherwise in the text's language."
    }

    func shorten(_ text: String) async -> Outcome {
        let original = text.trimmingCharacters(in: .whitespacesAndNewlines)
        switch await server.shorten(original) {
        case .success(let shorter):
            return Self.checked(shorter, against: original, by: .server)
        case .failure(.refused(let message)):
            return .failed(message)
        case .failure(let why):
            let code = language()
            if phone.isAvailable(for: code),
               let shorter = try? await phone.respond(to: original, instructions: Self.instructions(code)) {
                Log.repetition.info("Compress: the phone's model shortened the text (the server could not)")
                return Self.checked(shorter, against: original, by: .phone)
            }
            return .failed(why == .offline ? NetworkStatus.noNetworkLine : SayCompressText.failed)
        }
    }

    /// Only a text that really is shorter goes into the field.
    static func checked(_ shorter: String, against original: String, by: By) -> Outcome {
        let text = shorter.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.count < original.count else { return .failed(SayCompressText.noGain) }
        return .shortened(text, by: by)
    }
}

/// What the Say card remembers about a compression: the original (for Ångra) and the line under the field.
struct SayCompression: Equatable {
    /// A text shorter than this is not worth shortening; the button is not shown for it.
    static let minChars = 160

    private(set) var original: String?
    private(set) var note: String?

    var canUndo: Bool { original != nil }

    static func offers(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).count >= minChars
    }

    /// The outcome of Komprimera for the text in the field: the text the field should hold now.
    mutating func took(_ outcome: SayCompressor.Outcome, for text: String) -> String {
        switch outcome {
        case .shortened(let shorter, let by):
            original = original ?? text // compressing twice still undoes to the first text
            note = SayCompressText.note(before: text.count, after: shorter.count, by: by)
            return shorter
        case .failed(let line):
            note = line
            return text
        }
    }

    /// The field changed. An emptied field forgets the original; typing clears a failure's line.
    mutating func edited(_ text: String) {
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            original = nil
            note = nil
        } else if original == nil {
            note = nil
        }
    }

    /// Ångra: the original, once.
    mutating func undo() -> String? {
        defer {
            original = nil
            note = nil
        }
        return original
    }
}

enum SayCompressText {
    static var compress: String { String(localized: "Komprimera") }
    static var working: String { String(localized: "Komprimerar …") }
    static var undo: String { String(localized: "Ångra") }
    static var failed: String { String(localized: "Det gick inte att komprimera just nu.") }
    static var noGain: String { String(localized: "Texten blev inte kortare.") }
    static var hint: String { String(localized: "Gör texten kortare med samma innehåll. Inget spelas förrän du trycker Spela.") }

    static func note(before: Int, after: Int, by: SayCompressor.By) -> String {
        by == .phone
            ? String(localized: "Kortad av telefonens modell från \(before) till \(after) tecken. Ändra om du vill.")
            : String(localized: "Kortad från \(before) till \(after) tecken. Ändra om du vill.")
    }
}
