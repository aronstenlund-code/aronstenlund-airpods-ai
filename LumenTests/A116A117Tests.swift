import Foundation
import Testing
@testable import Lumen

/// A116 (D204): a pasted link becomes an address the server takes. A117 (D205): the month's questions and the price
/// table come from the server (Kevin's K82), and the sheet's rows are made from them. No network, 0 ElevenLabs (D180).
@MainActor
@Suite struct A116A117Tests {
    // MARK: A116

    @Test func aPastedLinkBecomesAnAddressTheServerTakes() {
        #expect(FetchedPage.address("https://sv.wikipedia.org/wiki/Fotosyntes") == "https://sv.wikipedia.org/wiki/Fotosyntes")
        #expect(FetchedPage.address("  sv.wikipedia.org/wiki/Fotosyntes \n") == "https://sv.wikipedia.org/wiki/Fotosyntes")
        #expect(FetchedPage.address("HTTP://example.com") == "HTTP://example.com")
        #expect(FetchedPage.address("") == nil)
        #expect(FetchedPage.address("inte en länk") == nil)
        #expect(FetchedPage.address("fotosyntes") == nil)
    }

    @Test func kevinsAnswerIsDecoded() throws {
        let json = #"{"url": "https://example.com/a", "title": "Fotosyntes", "text": "Växter gör socker.", "chars": 18, "truncated": true}"#
        let page = try JSONDecoder().decode(FetchedPage.self, from: Data(json.utf8))
        #expect(page.title == "Fotosyntes")
        #expect(page.text == "Växter gör socker.")
        #expect(page.truncated == true)
        let short = try JSONDecoder().decode(FetchedPage.self, from: Data(#"{"text": "Hej."}"#.utf8))
        #expect(short.title == nil)
    }

    @Test func theServersWordsAreSaidWhenItRefusesAPage() {
        let body = #"{"error": {"code": "url_not_text", "message": "Länken går till en fil, inte en sida. Lägg till filen i stället."}}"#
        #expect(DrillClient.refusal(status: 415, data: Data(body.utf8)) == .refused("Länken går till en fil, inte en sida. Lägg till filen i stället."))
        #expect(DrillClient.refusal(status: 500, data: Data()) == .server("HTTP 500"))
    }

    // MARK: A117

    static let quotaJSON = """
    {"used": 88, "limit": 400, "left": 312, "suggest": 20, "per": "month", "resets": "2026-12-01",
     "prices": {"classes": [{"class": "normal", "max_chars": 800, "questions": 1, "tokens": 40},
                            {"class": "longer", "min_chars": 801, "max_chars": 1600, "questions": 1, "tokens": 60},
                            {"class": "too_long", "min_chars": 1601, "max_chars": 4000, "questions": 1, "tokens": 80}],
                "read": {"chars_per_question": 800},
                "free": ["shared", "published", "imported", "existing_audio"]}}
    """

    @Test func theQuotaWithItsPricesIsDecodedFromKevinsJSON() throws {
        let quota = try JSONDecoder().decode(DrillQuota.self, from: Data(Self.quotaJSON.utf8))
        #expect(quota.left == 312)
        #expect(quota.prices?.classes.map(\.name) == ["normal", "longer", "too_long"])
        #expect(quota.prices?.read?.chars_per_question == 800)
        #expect(CreditsText.capsule(quota) == "312 frågor kvar")
    }

    @Test func anOlderServerWithoutPricesStillGivesTheNumber() throws {
        let quota = try JSONDecoder().decode(DrillQuota.self, from: Data(#"{"used": 14, "limit": 15}"#.utf8))
        #expect(quota.prices == nil)
        #expect(CreditsText.capsule(quota) == "1 fråga kvar")
        #expect(CreditsText.rows(quota.prices).isEmpty)
    }

    @Test func theRowsSayWhatTheServersTableSays() throws {
        let quota = try JSONDecoder().decode(DrillQuota.self, from: Data(Self.quotaJSON.utf8))
        let rows = CreditsText.rows(quota.prices)
        #expect(rows.map(\.title) == ["Vanlig fråga", "Lite längre fråga", "Mycket lång fråga", "Läs upp eller Säg i AirPods",
                                      "Upprepa samma text"])
        // Today every question with new sound counts as 1 (K82); the table decides, not the app.
        #expect(rows.map(\.value) == ["1", "1", "1", "1 per 800 tecken", "0"])
        #expect(CreditsText.number(1.5) == "1,5")
    }

    @Test func theSheetSaysWhenItIsFilledUp() {
        #expect(CreditsText.refill("2026-12-01") == "Fylls på den 1 december.")
        #expect(CreditsText.refill("2027-01-15") == "Fylls på den 15 januari.")
        #expect(CreditsText.refill(nil).hasPrefix("Fylls på den 1 "))
    }
}
