import Foundation

/// D80: what never goes into Minne by itself. Health, beliefs, sexuality, politics, origin, union membership, crime
/// and similar (GDPR art. 9/10 categories). The user can still add such a thing by hand or by voice. Pure; unit-tested.
enum SensitiveFilter {
    /// A27 (Oscar O28): the categories as patterns with word boundaries where a short stem would also hit ordinary
    /// words ("lånat", "sjukt", "brottslighet", "kristendomen" are kept). Same categories as the backend's
    /// `SENSITIVE_RAW` plus O28's additions; the 47 cases of `scripts/qa/o28_memory_sensitive_offline.mjs` are tests.
    private static let patterns = [
        // health
        #"allerg|\bsjuk(?:dom\p{L}*|a|e|skriven)?\b|diagnos|\badhd\b|\badd\b|autism|diabet|astma|depress|deprimerad|ångest"#,
        #"medicin|\bterapi|psykiatri|\bpsykisk|psykolog(?!i)|cancer|gravid|abort|\bhiv\b|funktionsnedsättning|ätstörning|epilepsi"#,
        #"celiaki|gluten|laktos|intolerans|dyslexi|\bmens\b|\bväger\b|\bkilo\b|concerta|elvanse|ritalin|melatonin"#,
        // crisis (the words of the backend's crisis.ts that fit a memory)
        #"självmord|skär sig|skär mig|självskad|skada mig själv|vill inte leva|orkar inte leva"#,
        // sexuality and relationships
        #"\bgay\b|\bbi\b|homosex|bisex|lesbisk|transperson|sexuell|\b(?:pojkvän|flickvän|partner)\p{L}*"#,
        // religion
        #"religi|\bkristen\b|\bmuslim|\bjude\b|\bjudisk|ateist|tror på gud|ramadan|\bfasta(?:r)?\b|\bkyrka|moské|synagog|\bbön\b|\bber till\b"#,
        // politics
        #"politi|parti(?!k|ell)|röstar på|röstade på|socialist|socialdemokrat|sverigedemokrat|\bmoderat|kommunist|nazist|ungdomsförbund"#,
        // origin, union, crime
        #"etnisk|ursprung|invandrare|\bromsk|\bär same\b|fackförening|\bfacket\b|\bbrott\b|\bdömd|polisanmäl|\bstraff\b|fängelse|snatta|\bgripen\b"#,
        // address, money
        #"adress|\bbor (?:på|i)\b|gatan\b|postnummer|skuld|\blån(?:et|en|a)?\b|kredit|inkasso|kronofogd|betalningsanmärk|\blön\b|inkomst"#,
        #"tjänar |ekonomi|hyra|\bcsn\b|pengar|förmögenhet|bankkonto|kontonummer|personnummer|lösenord|\b\d+ ?kr\b|kronor"#,
        // contact details
        #"@|\b\d{2,4}[ -]?\d{2,3}[ -]?\d{2}[ -]?\d{2}\b|instagram|\binsta\b|snapchat|\bsnap\b|tiktok|e-?post|\bmejl|telefonnummer"#,
        // other people by name
        #"\b(?:mamma|pappa|bror|brorsan|syster|systern|kompis\p{L}*|vän\p{L}*|farmor|farfar|mormor|morfar)\b.{0,24}\bheter\b"#,
        // English
        #"health|religion|sexual|ethnic|address|i live at|debt|loan|credit|salary|income|bank account|password|anxiety|therapy|pregnan"#,
    ]

    /// K8 (backend) and O28: a school subject or what is studied is not about the student: "Läser religionskunskap",
    /// "Skriver en uppsats om brottslighet", "Har prov om partiklar". A study word and the four words after it are
    /// taken out before the check ("Pluggar trots att jag är deprimerad" still stops).
    private static let studyWords =
        #"\b(?:läser|pluggar|plugga|skriver|prov|provet|läxa|läxan|uppsats\p{L}*|kurs\p{L}*|lektion\p{L}*|ämnet)\b(?:\s+[\p{L}\p{N}]+){0,4}"#

    static func isSensitive(_ text: String) -> Bool {
        // "Kommer från Syrien": a capital after "kommer från" is a country or a place, before lower-casing.
        if text.range(of: #"(?i:kommer från) [A-ZÅÄÖ]"#, options: .regularExpression) != nil { return true }
        let lowered = " " + text.lowercased()
            .replacingOccurrences(of: studyWords, with: " ", options: .regularExpression) + " "
        return patterns.contains { lowered.range(of: $0, options: .regularExpression) != nil }
    }
}

/// `POST /memory` (D80, Kevin builds the backend side): after a turn, outside the answer path, the turn goes to the
/// backend's memory extraction, and what it finds about the user is saved in Minne. Contract the app sends:
/// `{"turn": {"question": "…", "answer": "…", "mode": "prov"}, "memories": ["…"], "today": "2026-11-07",
/// "weekday": "fredag", "timezone": "Europe/Stockholm", "language": "sv"}`. Reply: `{"add": ["Biologiprov fredag 14 nov"]}`
/// (strings, or objects with `text`). Dates come back absolute. A missing endpoint (404) is not an error.
struct MemoryExtraction: Equatable, Sendable {
    struct Turn: Encodable, Equatable, Sendable {
        var question: String
        var answer: String
        var mode: String
    }

    struct Body: Encodable, Equatable, Sendable {
        var turn: Turn
        var memories: [String]
        var today: String
        var weekday: String
        var timezone: String
        var language: String
    }

    static func body(question: String, answer: String, mode: String, memories: [String], language: String,
                     now: Date = Date(), timeZone: TimeZone = .current) -> Body {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let day = calendar.dateComponents([.year, .month, .day], from: now)
        let today = String(format: "%04d-%02d-%02d", day.year ?? 0, day.month ?? 0, day.day ?? 0)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: language == "sv" ? "sv_SE" : "en_US")
        formatter.timeZone = timeZone
        formatter.dateFormat = "EEEE"
        return Body(turn: Turn(question: String(question.prefix(1000)), answer: String(answer.prefix(2000)), mode: mode),
                    memories: memories, today: today, weekday: formatter.string(from: now), timezone: timeZone.identifier,
                    language: language)
    }

    /// The facts to keep: deduplicated, short enough, never a sensitive category.
    static func decode(_ data: Data) -> [String] {
        struct Item: Decodable { var text: String }
        struct Reply: Decodable {
            var add: [String]
            init(from decoder: any Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                if let strings = try? container.decode([String].self, forKey: .add) {
                    add = strings
                } else {
                    add = (try? container.decode([Item].self, forKey: .add))?.map(\.text) ?? []
                }
            }
            enum CodingKeys: String, CodingKey { case add }
        }
        guard let reply = try? JSONDecoder().decode(Reply.self, from: data) else { return [] }
        var seen = Set<String>()
        return reply.add
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !SensitiveFilter.isSensitive($0) && seen.insert($0.lowercased()).inserted }
    }
}

/// Sends a finished turn for extraction. Never in the answer path: the caller fires and forgets.
@MainActor
final class MemoryExtractor {
    private let config: BackendConfig
    private let auth: SupabaseAuth
    private let http: any HTTPStreaming

    init(config: BackendConfig, auth: SupabaseAuth, http: any HTTPStreaming) {
        self.config = config
        self.auth = auth
        self.http = http
    }

    /// A9.3 / K10.2: a correction ("kortare" right after an answer) becomes a setting with a scope. Code only on the
    /// server, no model call. Nil: no network or not a correction.
    func correct(text: String, context: PrefScope, settings: [PrefSetting]) async -> CorrectionReply? {
        struct Body: Encodable {
            struct Correction: Encodable {
                var text: String
                var context: PrefScope
            }
            var correction: Correction
            var settings: [PrefSetting]
        }
        do {
            let token = try await auth.accessToken()
            var request = URLRequest(url: config.memoryURL)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue(config.publishableKey, forHTTPHeaderField: "apikey")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 15
            request.httpBody = try JSONEncoder().encode(Body(correction: .init(text: String(text.prefix(200)), context: context), settings: settings))
            let (response, data) = try await http.data(for: request)
            guard response.statusCode == 200 else { return nil }
            return try JSONDecoder().decode(CorrectionReply.self, from: data)
        } catch {
            return nil
        }
    }

    func extract(_ body: MemoryExtraction.Body) async -> [String] {
        do {
            let token = try await auth.accessToken()
            var request = URLRequest(url: config.memoryURL)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue(config.publishableKey, forHTTPHeaderField: "apikey")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 15
            request.httpBody = try JSONEncoder().encode(body)
            let (response, data) = try await http.data(for: request)
            guard response.statusCode == 200 else {
                if response.statusCode != 404 {
                    Log.answer.error("memory extraction: HTTP \(response.statusCode, privacy: .public)")
                }
                return []
            }
            return MemoryExtraction.decode(data)
        } catch {
            return []
        }
    }
}

/// D80: Scribe keyterms (max 20) from what the conversation is about, so topic words are heard right ("fotosyntes",
/// not "få tes"). Order: own commands, the active topic, the latest answers, course goals, memory, prep. Pure.
enum KeytermBuilder {
    static let limit = 20
    private static let stopwords: Set<String> = [
        "vad", "varför", "eftersom", "alltså", "därför", "kanske", "också", "skulle", "kommer", "finns", "mellan",
        "något", "några", "sedan", "efter", "innan", "under", "genom", "själv", "detta", "denna", "dessa", "deras",
        "vilken", "vilket", "vilka", "where", "which", "there", "their", "about", "would", "could", "should",
    ]

    static func terms(commands: [String], topic: String?, answers: [String], goals: [String], memory: [String],
                      prep: [String]) -> [String] {
        var out: [String] = []
        var seen = Set<String>()
        func add(_ term: String) {
            let clean = term.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
            guard !clean.isEmpty, out.count < limit, seen.insert(clean.lowercased()).inserted else { return }
            out.append(clean)
        }
        commands.forEach(add)
        words(topic ?? "").forEach(add)
        answers.flatMap(words).forEach(add)
        goals.flatMap(words).forEach(add)
        memory.flatMap(words).forEach(add)
        prep.forEach(add)
        return out
    }

    /// Content words: long enough to be easy to mishear, not function words.
    static func words(_ text: String) -> [String] {
        text.split(whereSeparator: { !$0.isLetter && $0 != "-" })
            .map(String.init)
            .filter { $0.count >= 6 && !stopwords.contains($0.lowercased()) }
    }
}
