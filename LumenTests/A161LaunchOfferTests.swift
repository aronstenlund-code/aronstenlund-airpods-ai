import Foundation
import Testing
@testable import Lumen

/// A161 (D259, Aron 2026-11-23): 65 % off every credit pack for one week from the launch. The server says when the
/// week runs (Kevin's K119: `GET /purchase` → `launch_offer`), the App Store has the packs' launch twins
/// (`….credits.<n>.launch`, the same credits at the lower price), and the app shows the launch price with the ordinary
/// one struck through, "-65 %" and how long is left, plus one clear sheet when the app is opened (once a day at most).
/// A pretend App Store and a pretend server: no purchase is made, nothing is sent, 0 ElevenLabs characters (D180).
@MainActor
@Suite struct A161LaunchOfferTests {
    static let start = Date(timeIntervalSince1970: 1_796_112_000) // 2026-12-01 08:00 UTC
    static let end = start.addingTimeInterval(7 * 86_400)
    static let week = LaunchOffer(startsAt: start, endsAt: end, percent: 65, productSuffix: ".launch")
    static let ordinary = ["com.rsolutions.lumen.credits.100": "10,00 kr", "com.rsolutions.lumen.credits.500": "39,00 kr",
                           "com.rsolutions.lumen.credits.2000": "110,00 kr"]
    static let launch = ["com.rsolutions.lumen.credits.100.launch": "3,50 kr", "com.rsolutions.lumen.credits.500.launch": "13,65 kr",
                         "com.rsolutions.lumen.credits.2000.launch": "38,50 kr"]

    @MainActor final class Front: StoreFront {
        var launchPrices = A161LaunchOfferTests.launch
        /// The weekly pass's introductory price in the App Store (65 % off the first week); nil = none, or this
        /// Apple account has had the pass before.
        var passIntro: String? = "27,65 kr"
        var bought: [String] = []
        var launchAsks = 0

        func items() async -> [StoreItem] {
            StoreCatalog.entries.map {
                StoreItem(id: $0.id, displayPrice: A161LaunchOfferTests.ordinary[$0.id] ?? "79,00 kr", credits: $0.credits,
                          introPrice: $0.credits == nil ? passIntro : nil)
            }
        }
        func launchItems(suffix: String) async -> [StoreItem] {
            launchAsks += 1
            return StoreCatalog.entries.compactMap { entry in
                guard let credits = entry.credits, let price = launchPrices[entry.id + suffix] else { return nil }
                return StoreItem(id: entry.id + suffix, displayPrice: price, credits: credits)
            }
        }
        func buy(_ id: String, account: UUID?) async throws -> StoreOutcome {
            bought.append(id)
            return .bought(StoreReceipt(jws: "jws-\(id)", transactionID: 7))
        }
        func finish(_ transactionID: UInt64) async {}
        func restore() async throws -> [StoreReceipt] { [] }
        func listen(_ onReceipt: @escaping @MainActor (StoreReceipt) async -> Void) {}
    }

    @MainActor final class Server: PurchaseServing {
        var offer: LaunchOffer?
        var verified: [String] = []

        func launchOffer() async -> LaunchOffer? { offer }
        func verify(jws: String) async throws(DrillCloudError) -> PurchaseReply {
            verified.append(jws)
            return PurchaseReply(ok: true, kind: "credits", added: 500)
        }
        func attestChallenge() async throws(DrillCloudError) -> String { "c" }
        func welcome(keyID: String, challenge: String, attestation: String) async throws(DrillCloudError) -> PurchaseReply { PurchaseReply() }
        func inviteCode() async throws(DrillCloudError) -> InviteLink { InviteLink(code: "k", url: "https://earmind.vercel.app/i/k", app_url: "earmind://invite/k") }
        func claimInvite(_ code: String) async throws(DrillCloudError) {}
    }

    private func shop(offer: LaunchOffer?, front: Front = Front()) throws -> (CreditShop, Front, Server) {
        let server = Server()
        server.offer = offer
        let defaults = try #require(UserDefaults(suiteName: "a161-\(UUID().uuidString)"))
        return (CreditShop(front: front, server: server, defaults: defaults), front, server)
    }

    private func at(_ days: Double) -> Date { Self.start.addingTimeInterval(days * 86_400) }

    // MARK: What the server says (K119)

    @Test func theServersWeekIsRead() throws {
        let on = Data(#"{"launch_offer":{"starts_at":"2026-12-01T08:00:00.000Z","ends_at":"2026-12-08T08:00:00.000Z","percent":65,"product_suffix":".launch"}}"#.utf8)
        #expect(LaunchOffer.read(on) == Self.week)
        #expect(LaunchOffer.read(Data(#"{"launch_offer":null}"#.utf8)) == nil) // empty until the launch, and after it
        #expect(LaunchOffer.read(Data(#"{}"#.utf8)) == nil && LaunchOffer.read(Data("no".utf8)) == nil)
        // A week that cannot be right is no week.
        let backwards = Data(#"{"launch_offer":{"starts_at":"2026-12-08T08:00:00Z","ends_at":"2026-12-01T08:00:00Z","percent":65}}"#.utf8)
        #expect(LaunchOffer.read(backwards) == nil)
        let silly = Data(#"{"launch_offer":{"starts_at":"2026-12-01T08:00:00Z","ends_at":"2026-12-08T08:00:00Z","percent":0}}"#.utf8)
        #expect(LaunchOffer.read(silly) == nil)
        // The suffix has a default, so an older answer without it still works.
        let bare = Data(#"{"launch_offer":{"starts_at":"2026-12-01T08:00:00Z","ends_at":"2026-12-08T08:00:00Z","percent":65}}"#.utf8)
        #expect(LaunchOffer.read(bare) == Self.week)
    }

    @Test func theWeekRunsFromItsStartToItsEnd() {
        #expect(!Self.week.isOn(Self.start.addingTimeInterval(-1)))
        #expect(Self.week.isOn(Self.start) && Self.week.isOn(at(3)) && Self.week.isOn(Self.end.addingTimeInterval(-1)))
        #expect(!Self.week.isOn(Self.end))
        #expect(StoreCatalog.launchIDs(suffix: ".launch") == ["com.rsolutions.lumen.credits.100.launch",
                                                             "com.rsolutions.lumen.credits.500.launch",
                                                             "com.rsolutions.lumen.credits.2000.launch"])
    }

    /// Nobody is signed in for this question, and nothing about the account goes with it.
    @Test func theWeekIsAskedForWithoutSigningIn() async throws {
        let config = BackendConfig(projectURL: URL(string: "https://example.supabase.co")!, publishableKey: "pk")
        let body = #"{"launch_offer":{"starts_at":"2026-12-01T08:00:00.000Z","ends_at":"2026-12-08T08:00:00.000Z","percent":65,"product_suffix":".launch"}}"#
        let http = FakeHTTP([.init(status: 200, body: body), .init(status: 500, body: "{}")])
        let auth = SupabaseAuth(config: config, store: InMemorySessionStore(), http: http, now: { Date() })
        let client = PurchaseClient(config: config, auth: auth, http: http)
        #expect(await client.launchOffer() == Self.week)
        let request = try #require(http.requests.first)
        #expect(request.httpMethod == "GET" && request.url?.path == "/functions/v1/purchase")
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil && request.value(forHTTPHeaderField: "apikey") == "pk")
        #expect(http.requests.count == 1, "no sign-in was made for it")
        #expect(await client.launchOffer() == nil, "a server fault is no week")
    }

    // MARK: The shop during the week

    @Test func duringTheWeekThePacksAreTheLaunchPacksWithTheOrdinaryPriceStruck() async throws {
        let (shop, _, _) = try shop(offer: Self.week)
        await shop.load()
        await shop.loadOffer(now: at(1))
        let packs = shop.packs(now: at(1))
        #expect(packs.map(\.id) == ["com.rsolutions.lumen.credits.100.launch", "com.rsolutions.lumen.credits.500.launch",
                                    "com.rsolutions.lumen.credits.2000.launch"])
        #expect(packs.map(\.displayPrice) == ["3,50 kr", "13,65 kr", "38,50 kr"])
        #expect(packs.map(\.regularPrice) == ["10,00 kr", "39,00 kr", "110,00 kr"])
        #expect(packs.map(\.credits) == [100, 500, 2000], "the same credits as the ordinary packs")
        #expect(shop.activeOffer(now: at(1)) == Self.week)
        #expect(shop.weeklyCard?.id == StoreCatalog.weekly && shop.weeklyCard?.regularPrice == nil) // the pass is as it was
        #expect(StoreCatalog.isBestValue(packs[2].id) && !StoreCatalog.isBestValue(packs[0].id)) // the badge follows the pack
    }

    @Test func outsideTheWeekTheShopIsAsToday() async throws {
        // No week on the server.
        let (none, front, _) = try shop(offer: nil)
        await none.load()
        await none.loadOffer(now: at(1))
        #expect(none.packs(now: at(1)).map(\.id) == Array(StoreCatalog.ids.prefix(3)))
        #expect(none.packs(now: at(1)).allSatisfy { $0.regularPrice == nil } && none.activeOffer(now: at(1)) == nil)
        #expect(front.launchAsks == 0, "the App Store is not asked about launch packs when there is no week")
        // A week that has not begun on this phone's clock.
        let (early, _, _) = try shop(offer: Self.week)
        await early.load()
        await early.loadOffer(now: at(-1))
        #expect(early.activeOffer(now: at(-1)) == nil && early.packs(now: at(-1)).allSatisfy { $0.regularPrice == nil })
    }

    /// The sheet can be open when the week ends: from that moment the ordinary packs stand there again.
    @Test func whenTheWeekEndsWhileTheShopIsOpenTheOrdinaryPacksComeBack() async throws {
        let (shop, _, _) = try shop(offer: Self.week)
        await shop.load()
        await shop.loadOffer(now: at(6.9))
        #expect(shop.packs(now: Self.end.addingTimeInterval(-1)).first?.id == "com.rsolutions.lumen.credits.100.launch")
        let after = shop.packs(now: Self.end)
        #expect(after.map(\.id) == Array(StoreCatalog.ids.prefix(3)) && after.allSatisfy { $0.regularPrice == nil })
        #expect(shop.activeOffer(now: Self.end) == nil)
        #expect(shop.packs.count == 3, "the plain list works whatever the time is")
    }

    /// Until the launch packs exist in App Store Connect nothing is promised: no struck price, no sheet.
    @Test func withoutLaunchPacksInTheAppStoreNothingIsPromised() async throws {
        let front = Front()
        front.launchPrices = [:]
        front.passIntro = nil
        let (shop, _, _) = try shop(offer: Self.week, front: front)
        await shop.load()
        await shop.loadOffer(now: at(1))
        #expect(shop.activeOffer(now: at(1)) == nil && !shop.shouldShowLaunchSheet(now: at(1)))
        #expect(shop.packs(now: at(1)).allSatisfy { $0.regularPrice == nil })
        // One pack's twin is missing: that pack keeps its ordinary price, the others have the launch price.
        front.launchPrices = ["com.rsolutions.lumen.credits.500.launch": "13,65 kr"]
        await shop.loadOffer(now: at(1))
        #expect(shop.packs(now: at(1)).map(\.id) == ["com.rsolutions.lumen.credits.100", "com.rsolutions.lumen.credits.500.launch",
                                                    "com.rsolutions.lumen.credits.2000"])
        #expect(shop.activeOffer(now: at(1)) == Self.week)
    }

    @Test func aLaunchPackIsBoughtAsItself() async throws {
        let (shop, front, server) = try shop(offer: Self.week)
        await shop.load()
        await shop.loadOffer(now: at(2))
        let pack = try #require(shop.packs(now: at(2)).dropFirst().first)
        await shop.buy(pack)
        #expect(front.bought == ["com.rsolutions.lumen.credits.500.launch"])
        #expect(server.verified == ["jws-com.rsolutions.lumen.credits.500.launch"], "the server gives the ordinary pack's credits (K119)")
    }

    // MARK: The weekly pass (Deangelo 2026-11-23 20:55): an introductory offer on the same product

    @Test func duringTheWeekThePassShowsItsFirstWeeksPriceWithTheOrdinaryOneStruck() async throws {
        let (shop, front, _) = try shop(offer: Self.week)
        await shop.load()
        await shop.loadOffer(now: at(1))
        let pass = try #require(shop.weeklyOffer(now: at(1)))
        #expect(pass.id == StoreCatalog.weekly, "the same product: the App Store gives the first week's price by itself")
        #expect(pass.displayPrice == "27,65 kr" && pass.regularPrice == "79,00 kr")
        #expect(ShopText.weeklyIntroLine(intro: "27,65 kr", regular: "79,00 kr") == "Första veckan 27,65 kr, sedan 79,00 kr i veckan")
        #expect(ShopText.terms(price: "79,00 kr", intro: "27,65 kr").hasPrefix("Första veckan kostar 27,65 kr. Sedan kostar veckokortet 79,00 kr i veckan och förnyas automatiskt"))
        #expect(ShopText.terms(price: "79,00 kr", intro: nil) == ShopText.terms(price: "79,00 kr"))
        // The ordinary card is what the renewal and Apple's footnote speak of.
        #expect(shop.weeklyCard?.displayPrice == "79,00 kr" && shop.weeklyCard?.regularPrice == nil)
        await shop.buy(pass)
        #expect(front.bought == [StoreCatalog.weekly])
        // Outside the week, and when the week ends while the sheet is open: the pass as it is.
        #expect(shop.weeklyOffer(now: Self.end) == nil && shop.weeklyOffer(now: at(-1)) == nil)
    }

    @Test func aPassWithoutAnIntroductoryPriceIsShownAsItIs() async throws {
        let front = Front()
        front.passIntro = nil // not set up in App Store Connect, or this account has had the pass
        let (shop, _, _) = try shop(offer: Self.week, front: front)
        await shop.load()
        await shop.loadOffer(now: at(1))
        #expect(shop.weeklyOffer(now: at(1)) == nil)
        #expect(shop.activeOffer(now: at(1)) == Self.week, "the packs still have their launch prices")
        #expect(shop.offerCovers(now: at(1)) == LaunchOfferText.Covers(packs: true, pass: false))
        // Only the pass has an offer (the launch packs are not in the App Store yet): it is still an offer.
        front.passIntro = "27,65 kr"
        front.launchPrices = [:]
        let (passOnly, _, _) = try self.shop(offer: Self.week, front: front)
        await passOnly.load()
        await passOnly.loadOffer(now: at(1))
        #expect(passOnly.activeOffer(now: at(1)) == Self.week && passOnly.shouldShowLaunchSheet(now: at(1)))
        #expect(passOnly.offerCovers(now: at(1)) == LaunchOfferText.Covers(packs: false, pass: true))
        #expect(passOnly.packs(now: at(1)).allSatisfy { $0.regularPrice == nil })
    }

    // MARK: The sheet when the app is opened

    @Test func theSheetComesOnceADayDuringTheWeekAndNeverOutsideIt() async throws {
        let (shop, _, _) = try shop(offer: Self.week)
        await shop.load()
        #expect(!shop.shouldShowLaunchSheet(now: at(1)), "nothing is known before the server has answered")
        await shop.loadOffer(now: at(1))
        #expect(shop.shouldShowLaunchSheet(now: at(1)))
        shop.launchSheetShown(now: at(1))
        #expect(!shop.shouldShowLaunchSheet(now: at(1).addingTimeInterval(60)), "not again the same day")
        #expect(shop.shouldShowLaunchSheet(now: at(2.5)), "the next day it may come once more")
        shop.launchSheetShown(now: at(2.5))
        #expect(!shop.shouldShowLaunchSheet(now: Self.end.addingTimeInterval(3600)), "never after the week")
        let (none, _, _) = try self.shop(offer: nil)
        await none.load()
        await none.loadOffer(now: at(1))
        #expect(!none.shouldShowLaunchSheet(now: at(1)))
    }

    // MARK: The words

    @Test func theWordsSayThePercentAndHowLongIsLeft() {
        #expect(LaunchOfferText.badge(65) == "-65 %")
        #expect(LaunchOfferText.left(seconds: 2 * 86_400 + 4 * 3600 + 30 * 60) == "Slutar om 2 dagar 4 tim")
        #expect(LaunchOfferText.left(seconds: 86_400 + 60) == "Slutar om 1 dag 0 tim")
        #expect(LaunchOfferText.left(seconds: 4 * 3600 + 12 * 60 + 59) == "Slutar om 4 tim 12 min")
        #expect(LaunchOfferText.left(seconds: 12 * 60) == "Slutar om 12 min")
        #expect(LaunchOfferText.left(seconds: 20) == "Slutar om under en minut")
        #expect(LaunchOfferText.left(Self.week, now: Self.end.addingTimeInterval(-3 * 3600 - 60)) == "Slutar om 3 tim 1 min")
        #expect(LaunchOfferText.title == "Lanseringsrabatt")
        #expect(LaunchOfferText.line(65, covers: .init(packs: true, pass: true)) == "65 % rabatt på allt den här veckan.")
        #expect(LaunchOfferText.line(65, covers: .init(packs: true, pass: false)) == "65 % rabatt på alla kreditpaket den här veckan.")
        #expect(LaunchOfferText.line(65, covers: .init(packs: false, pass: true)) == "65 % rabatt på första veckan med veckokortet.")
        #expect(LaunchOfferText.spoken(title: "500 krediter", price: "13,65 kr", regular: "39,00 kr")
                == "Köp 500 krediter för 13,65 kr, ordinarie pris 39,00 kr")
    }

    @Test func theWordsAreInBothLanguages() {
        func english(_ key: String) -> String { AppLanguage.en.bundle.localizedString(forKey: key, value: "(missing)", table: nil) }
        #expect(english("Lanseringsrabatt") == "Launch offer")
        #expect(String(format: english("-%lld %%"), 65) == "-65%")
        #expect(String(format: english("%lld %% rabatt på alla kreditpaket den här veckan."), 65) == "65% off all credit packs this week.")
        #expect(english("Se paketen") == "See the packs" && english("Inte nu") == "Not now")
        #expect(String(format: english("%lld %% rabatt på allt den här veckan."), 65) == "65% off everything this week.")
        #expect(String(format: english("Första veckan %@, sedan %@ i veckan"), "$0.99", "$2.99") == "First week $0.99, then $2.99 a week")
        #expect(String(format: english("Slutar om %@"), "2 days 4 h") == "Ends in 2 days 4 h")
        #expect(String(format: english("%lld dagar"), 2) == "2 days" && english("1 dag") == "1 day")
        #expect(String(format: english("%lld tim"), 4) == "4 h")
    }
}
