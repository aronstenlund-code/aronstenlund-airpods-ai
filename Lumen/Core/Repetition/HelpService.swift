import Foundation

// MARK: - A92 (D166, K57): "Fråga om EarMind", the help AI

/// One question and its answer, for the chat (the server answers each question on its own).
struct HelpTurn: Equatable, Sendable {
    let question: String
    let answer: String
}

/// Where in the app the answer points ("Öppna Styr med dina AirPods").
enum HelpPlace: String, CaseIterable, Sendable {
    case controls, newDrill, share, publish, settings

    var title: String {
        switch self {
        case .controls: "Öppna Styr med dina AirPods"
        case .newDrill: "Öppna Nytt prov"
        case .share: "Öppna Dela"
        case .publish: "Öppna Publicera prov"
        case .settings: "Öppna Inställningar"
        }
    }

    /// The place the question or answer is about, read on the phone (K57 does not say it).
    static func guess(question: String, answer: String) -> HelpPlace? {
        let text = (question + " " + answer).lowercased()
        let rules: [(HelpPlace, [String])] = [
            (.controls, ["tryck", "airpods", "kontroll", "paus", "skaftet"]),
            (.publish, ["publicera", "din skola", "prov från"]),
            (.share, ["dela", "länk", "klasskompis"]),
            (.newDrill, ["nytt prov", "fota", "material", "dokument", "pdf", "skapa frågor"]),
            (.settings, ["inställning", "tempo", "röst", "avancerat", "längd"]),
        ]
        return rules.first { _, words in words.contains { text.contains($0) } }?.0
    }
}

struct HelpAnswer: Equatable, Sendable {
    /// Plain text; steps as "1. …" on their own lines.
    var text: String
    var place: HelpPlace?
    /// K57: outside the app, "Jag svarar bara på hur EarMind fungerar, …" after the answer.
    var hint: String?
    /// False when the question was not about the app.
    var inScope: Bool = true
}

enum HelpError: Error, Equatable {
    case offline
    case failed
    /// The server's own words (429 "För många frågor …", 402 "Du har inga frågor kvar …", 400 for a short text).
    case refused(String)

    var userMessage: String {
        switch self {
        case .offline: "Ingen internetanslutning."
        case .failed: "Det gick inte att svara just nu. Försök igen."
        case .refused(let message): message
        }
    }
}

@MainActor
protocol HelpAnswering: AnyObject, Sendable {
    func answer(_ question: String, history: [HelpTurn]) async throws(HelpError) -> HelpAnswer
    /// "Prova på en kort text": 3 questions with answers (K57 `try`, counts as 3 of the month's questions).
    func tryText(_ text: String) async throws(HelpError) -> DrillDraft
}

@MainActor
final class HelpClient: HelpAnswering {
    private let config: BackendConfig
    private let auth: SupabaseAuth
    private let http: any HTTPStreaming

    init(config: BackendConfig, auth: SupabaseAuth, http: any HTTPStreaming) {
        self.config = config
        self.auth = auth
        self.http = http
    }

    func answer(_ question: String, history: [HelpTurn]) async throws(HelpError) -> HelpAnswer {
        struct Reply: Decodable { var answer: String; var in_scope: Bool?; var hint: String? }
        let q = question.trimmingCharacters(in: .whitespacesAndNewlines)
        let reply: Reply = try await call(["question": String(q.prefix(500))], timeout: 30)
        let inScope = reply.in_scope ?? true
        return HelpAnswer(text: reply.answer, place: inScope ? HelpPlace.guess(question: q, answer: reply.answer) : nil,
                          hint: inScope ? nil : reply.hint, inScope: inScope)
    }

    func tryText(_ text: String) async throws(HelpError) -> DrillDraft {
        struct Reply: Decodable {
            struct Summary: Decodable { var subject: String?; var grade: String?; var covers: String? }
            struct Item: Decodable { var question: String; var short: String?; var long: String? }
            var summary: Summary?
            var notes: String?
            var items: [Item]?
        }
        let reply: Reply = try await call(["action": "try", "text": String(text.prefix(4_000))], timeout: 90)
        let items = (reply.items ?? []).compactMap { item -> DrillItem? in
            guard let short = item.short, !short.isEmpty else { return nil }
            return DrillItem(question: item.question, short: short, long: DrillItem.long(item.long ?? "", startingWith: short))
        }
        guard !items.isEmpty else { throw .failed }
        return DrillDraft(summary: DrillSummary(subject: reply.summary?.subject ?? "", grade: reply.summary?.grade ?? "",
                                                covers: reply.summary?.covers ?? ""),
                          items: items, notes: reply.notes ?? "")
    }

    private func call<Reply: Decodable>(_ body: [String: Any], timeout: TimeInterval) async throws(HelpError) -> Reply {
        let response: HTTPURLResponse
        let data: Data
        do {
            let token = try await auth.accessToken()
            var request = URLRequest(url: config.projectURL.appending(path: "functions/v1/help"))
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue(config.publishableKey, forHTTPHeaderField: "apikey")
            request.markTestTraffic() // T24: x-earmind-test in Debug UI tests
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = timeout
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            (response, data) = try await http.data(for: request)
        } catch {
            Log.repetition.error("help: \(error.localizedDescription, privacy: .public)")
            throw NetworkStatus.shared.isOnline ? HelpError.failed : HelpError.offline
        }
        guard response.statusCode == 200 else {
            Log.repetition.error("help: HTTP \(response.statusCode, privacy: .public)")
            throw Self.refusal(status: response.statusCode, data: data)
        }
        do {
            return try JSONDecoder().decode(Reply.self, from: data)
        } catch {
            throw .failed
        }
    }

    /// 4xx with K57's Swedish message is shown as it is; anything else is "Det gick inte att svara just nu."
    static func refusal(status: Int, data: Data) -> HelpError {
        struct Body: Decodable {
            struct Inner: Decodable { var message: String? }
            var error: Inner?
        }
        if (400..<500).contains(status), status != 401,
           let message = (try? JSONDecoder().decode(Body.self, from: data))?.error?.message, !message.isEmpty {
            return .refused(message)
        }
        return .failed
    }
}

/// The Simulator and the screenshots: fixed answers about the app, no network, no cost.
@MainActor
final class MockHelp: HelpAnswering {
    func answer(_ question: String, history: [HelpTurn]) async throws(HelpError) -> HelpAnswer {
        let q = question.lowercased()
        if q.contains("tryck") || q.contains("airpods") {
            let text = "Medan frågan spelas: tryck 1 gång för frågans A-svar. Tryck 2 gånger för ett kort A-svar på en till två meningar. Tryck 3 gånger för att pausa. Tryck igen för att fortsätta."
            return HelpAnswer(text: text, place: .controls)
        }
        if q.contains("fota") || q.contains("nytt prov") {
            let text = "1. Tryck Nytt prov.\n2. Tryck Fota sidor och fota alla sidor i följd.\n3. Tryck Skapa frågor.\n4. Kolla sammanfattningen och tryck Ser rätt ut."
            return HelpAnswer(text: text, place: .newDrill)
        }
        if q.contains("väd") || q.contains("fotboll") {
            return HelpAnswer(text: "Det kan jag inte svara på.", place: nil,
                              hint: "Jag svarar bara på hur EarMind fungerar, till exempel hur du gör ett nytt prov.", inScope: false)
        }
        return HelpAnswer(text: "Det vet jag inte. Skriv till oss under Inställningar › Om EarMind.", place: .settings)
    }

    func tryText(_ text: String) async throws(HelpError) -> DrillDraft {
        do {
            return try await MockDrillMaker().make(DrillMaterial(text: text), subject: nil, grade: nil, correction: nil,
                                                   questions: 3, longWords: 90)
        } catch {
            throw .failed
        }
    }
}
