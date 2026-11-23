import Foundation
import Testing
@testable import Lumen

/// A163 (D259, Aron 2026-11-23): Komprimera in Säg i AirPods. The text is made shorter with the same content, shown
/// in the field so it can be changed, and only then is the sound made; Ångra gives the original back. The server's
/// model shortens it, and when the server cannot (its model is down, 503 `provider_*`, or it does not have the
/// action yet) the phone's own model does (D258). Nothing is played by Komprimera.
/// A pretend server and a pretend phone model only: no model call, no sound, 0 ElevenLabs characters (D180).
@MainActor
@Suite struct A163CompressTests {
    static let long = "Fotosyntesen är den process där gröna växter, alger och vissa bakterier använder solens ljus för att göra "
        + "socker av koldioxid och vatten. Den sker i kloroplasterna, där klorofyllet fångar ljuset. Som restprodukt bildas syre."
    static let short = "Fotosyntes: växter gör socker av koldioxid och vatten med solljus. Syre blir över."

    @MainActor final class Server: TextShortening {
        var reply: Result<String, ShortenFailure> = .success(A163CompressTests.short)
        private(set) var asked: [String] = []

        func shorten(_ text: String) async -> Result<String, ShortenFailure> {
            asked.append(text)
            return reply
        }
    }

    @MainActor final class Phone: OnDeviceModel {
        var languages: Set<String> = ["sv", "en"]
        var reply: String? = "Växter gör socker av koldioxid, vatten och ljus."
        private(set) var asked: [(prompt: String, instructions: String)] = []

        func isAvailable(for language: String) -> Bool { languages.contains(language) }
        func respond(to prompt: String, instructions: String) async throws -> String {
            asked.append((prompt, instructions))
            guard let reply else { throw AnswerError.offline }
            return reply
        }
    }

    private func compressor(_ server: Server, _ phone: Phone) -> SayCompressor {
        SayCompressor(server: server, phone: phone, language: { "sv" })
    }

    // MARK: Who shortens

    @Test func theServersModelShortensTheText() async {
        let server = Server(), phone = Phone()
        let result = await compressor(server, phone).shorten(Self.long)
        #expect(result == .shortened(Self.short, by: .server))
        #expect(server.asked == [Self.long] && phone.asked.isEmpty)
    }

    @Test func thePhonesModelShortensWhenTheServersModelIsDown() async {
        let server = Server(), phone = Phone()
        server.reply = .failure(.modelDown) // 503 provider_quota
        let result = await compressor(server, phone).shorten(Self.long)
        #expect(result == .shortened("Växter gör socker av koldioxid, vatten och ljus.", by: .phone))
        #expect(phone.asked.count == 1 && phone.asked.first?.prompt == Self.long)
        #expect(phone.asked.first?.instructions.contains("Svara på svenska") == true)
        // The same when the server does not have the action yet, and without a network.
        server.reply = .failure(.notOnServer)
        #expect(await compressor(server, phone).shorten(Self.long) == .shortened("Växter gör socker av koldioxid, vatten och ljus.", by: .phone))
        server.reply = .failure(.offline)
        #expect(await compressor(server, phone).shorten(Self.long) == .shortened("Växter gör socker av koldioxid, vatten och ljus.", by: .phone))
    }

    @Test func thePhoneAnswersInEnglishWhenTheAppIsInEnglish() async {
        let server = Server(), phone = Phone()
        server.reply = .failure(.modelDown)
        phone.reply = "Plants make sugar from light."
        let english = SayCompressor(server: server, phone: phone, language: { "en" })
        #expect(await english.shorten(Self.long) == .shortened("Plants make sugar from light.", by: .phone))
        #expect(phone.asked.first?.instructions.contains("Answer in English") == true)
    }

    @Test func withoutAnyModelTheTextStaysAndOneLineSaysWhy() async {
        let server = Server(), phone = Phone()
        server.reply = .failure(.modelDown)
        phone.languages = [] // no Apple Intelligence
        #expect(await compressor(server, phone).shorten(Self.long) == .failed(SayCompressText.failed))
        #expect(phone.asked.isEmpty)
        // The phone's model is there but gives nothing.
        phone.languages = ["sv"]
        phone.reply = nil
        #expect(await compressor(server, phone).shorten(Self.long) == .failed(SayCompressText.failed))
        // No network and no model on the phone: the network's own line.
        phone.languages = []
        server.reply = .failure(.offline)
        #expect(await compressor(server, phone).shorten(Self.long) == .failed(NetworkStatus.noNetworkLine))
        // The server said something meant for the user (a limit): its words.
        server.reply = .failure(.refused("Vänta en stund."))
        #expect(await compressor(server, phone).shorten(Self.long) == .failed("Vänta en stund."))
        #expect(SayCompressText.failed == "Det gick inte att komprimera just nu.")
    }

    /// A "shorter" text that is not shorter, or empty, is not put in the field.
    @Test func aTextThatDidNotGetShorterIsNotUsed() async {
        let server = Server(), phone = Phone()
        server.reply = .success(Self.long + " Och lite till.")
        #expect(await compressor(server, phone).shorten(Self.long) == .failed(SayCompressText.noGain))
        server.reply = .success("   ")
        #expect(await compressor(server, phone).shorten(Self.long) == .failed(SayCompressText.noGain))
        #expect(phone.asked.isEmpty, "the server answered; the phone is for when it cannot")
        server.reply = .success("  \(Self.short)\n")
        #expect(await compressor(server, phone).shorten(Self.long) == .shortened(Self.short, by: .server)) // trimmed
        #expect(SayCompressText.noGain == "Texten blev inte kortare.")
    }

    // MARK: The field: the shorter text, and Ångra

    @Test func theShorterTextStandsInTheFieldAndUndoGivesTheOriginalBack() {
        var field = SayCompression()
        #expect(!field.canUndo && field.note == nil)
        #expect(SayCompression.offers(Self.long) && !SayCompression.offers("Kort text."), "only a text worth shortening")
        var text = Self.long
        text = field.took(.shortened(Self.short, by: .server), for: text)
        #expect(text == Self.short && field.canUndo)
        #expect(field.note == "Kortad från \(Self.long.count) till \(Self.short.count) tecken. Ändra om du vill.")
        // The user changes the shorter text: Ångra is still there and still gives the original.
        text += " Det sker i bladen."
        field.edited(text)
        #expect(field.canUndo)
        text = field.undo() ?? text
        #expect(text == Self.long && !field.canUndo && field.note == nil)
    }

    @Test func thePhonesWorkIsSaidAsThePhones() {
        var field = SayCompression()
        _ = field.took(.shortened(Self.short, by: .phone), for: Self.long)
        #expect(field.note == "Kortad av telefonens modell från \(Self.long.count) till \(Self.short.count) tecken. Ändra om du vill.")
    }

    @Test func aFailureLeavesTheTextAndAnEmptyFieldForgetsTheOriginal() {
        var field = SayCompression()
        #expect(field.took(.failed(SayCompressText.failed), for: Self.long) == Self.long)
        #expect(!field.canUndo && field.note == SayCompressText.failed)
        _ = field.took(.shortened(Self.short, by: .server), for: Self.long)
        field.edited("") // the field was emptied (a new text is coming)
        #expect(!field.canUndo && field.note == nil && field.undo() == nil)
        // Typing again clears a failure's line.
        _ = field.took(.failed(SayCompressText.failed), for: Self.long)
        field.edited(Self.long + " mer")
        #expect(field.note == nil)
    }

    // MARK: The server's answers (the action is Kevin's to add)

    private let config = BackendConfig(projectURL: URL(string: "https://example.supabase.co")!, publishableKey: "pk")

    private func client(_ http: FakeHTTP) -> TextShortenClient {
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        let valid = SupabaseSession(accessToken: "jwt", refreshToken: "r1", expiresAt: t0.addingTimeInterval(3600))
        let auth = SupabaseAuth(config: config, store: InMemorySessionStore(valid), http: http, now: { t0 })
        return TextShortenClient(config: config, auth: auth, http: http)
    }

    @Test func theServerIsAskedToCompressInTheAppsLanguage() async throws {
        let http = FakeHTTP([.init(status: 200, body: #"{"text":"Kortare."}"#)])
        #expect(await client(http).shorten(Self.long) == .success("Kortare."))
        let request = try #require(http.requests.first)
        #expect(request.url?.path == "/functions/v1/exam" && request.httpMethod == "POST")
        let body = try #require(JSONSerialization.jsonObject(with: try #require(request.httpBody)) as? [String: Any])
        #expect(body["action"] as? String == "compress" && body["text"] as? String == Self.long)
        #expect(body["lang"] as? String == AppLanguage.current.code)
    }

    @Test func theServersNoIsReadAsWhatItIs() async {
        let down = #"{"error":{"code":"provider_quota","message":"LLM credits exhausted","fallback":true}}"#
        #expect(await client(FakeHTTP([.init(status: 503, body: down)])).shorten(Self.long) == .failure(.modelDown))
        let unknown = #"{"error":{"code":"invalid_request","message":"action must be parse, hint, grade"}}"#
        #expect(await client(FakeHTTP([.init(status: 400, body: unknown)])).shorten(Self.long) == .failure(.notOnServer))
        let limit = #"{"error":{"code":"rate_limited","message":"Vänta en stund."}}"#
        #expect(await client(FakeHTTP([.init(status: 429, body: limit)])).shorten(Self.long) == .failure(.refused("Vänta en stund.")))
        #expect(await client(FakeHTTP([.init(status: 500, body: "{}")])).shorten(Self.long) == .failure(.server))
        #expect(await client(FakeHTTP([.init(status: 200, body: #"{"nothing":1}"#)])).shorten(Self.long) == .failure(.server))
        #expect(await client(FakeHTTP([.init(status: 0, body: "", error: URLError(.notConnectedToInternet))])).shorten(Self.long) == .failure(.offline))
    }

    // MARK: The words, in both languages

    @Test func theWordsAreInBothLanguages() {
        func english(_ key: String) -> String { AppLanguage.en.bundle.localizedString(forKey: key, value: "(missing)", table: nil) }
        #expect(SayCompressText.compress == "Komprimera" && english("Komprimera") == "Compress")
        #expect(SayCompressText.working == "Komprimerar …" && english("Komprimerar …") == "Compressing …")
        #expect(SayCompressText.undo == "Ångra" && english("Ångra") == "Undo")
        #expect(english("Det gick inte att komprimera just nu.") == "Couldn't compress right now.")
        #expect(english("Texten blev inte kortare.") == "The text didn't get shorter.")
        #expect(String(format: english("Kortad från %lld till %lld tecken. Ändra om du vill."), 240, 90)
                == "Shortened from 240 to 90 characters. Edit it if you like.")
    }
}
