import Foundation
import Testing
@testable import Lumen

/// A134 (D218) and A141 (D224): buying credits, the weekly card, the welcome credits and invitations. A fake App
/// Store, a fake server and a fake App Attest: no purchase is made, nothing is sent, 0 ElevenLabs characters (D180).
@MainActor
@Suite struct A134ShopTests {
    // MARK: Fakes

    @MainActor final class FakeFront: StoreFront {
        var outcome: Result<StoreOutcome, StoreFailure> = .success(.cancelled)
        var bought: [(id: String, account: UUID?)] = []
        var finished: [UInt64] = []
        var toRestore: [StoreReceipt] = []
        var restoreFails = false
        var onReceipt: (@MainActor (StoreReceipt) async -> Void)?

        func items() async -> [StoreItem] {
            StoreCatalog.entries.map { StoreItem(id: $0.id, displayPrice: $0.credits == nil ? "79,00 kr" : "10,00 kr", credits: $0.credits) }
        }
        func buy(_ id: String, account: UUID?) async throws -> StoreOutcome {
            bought.append((id, account))
            return try outcome.get()
        }
        func finish(_ transactionID: UInt64) async { finished.append(transactionID) }
        func restore() async throws -> [StoreReceipt] {
            if restoreFails { throw StoreFailure.unverified }
            return toRestore
        }
        func listen(_ onReceipt: @escaping @MainActor (StoreReceipt) async -> Void) { self.onReceipt = onReceipt }
    }

    @MainActor final class FakeServer: PurchaseServing {
        var verified: [String] = []
        var verifyError: DrillCloudError?
        var challengeError: DrillCloudError?
        var challenges = 0
        var welcomes: [(keyID: String, challenge: String, attestation: String)] = []
        var welcomeReply = PurchaseReply(ok: true, added: 5000)
        var welcomeError: DrillCloudError?
        var claimed: [String] = []
        var claimError: DrillCloudError?

        func verify(jws: String) async throws(DrillCloudError) -> PurchaseReply {
            if let verifyError { throw verifyError }
            verified.append(jws)
            return PurchaseReply(ok: true, kind: "credits", added: 100)
        }
        func attestChallenge() async throws(DrillCloudError) -> String {
            if let challengeError { throw challengeError }
            challenges += 1
            return "challenge-\(challenges)"
        }
        func welcome(keyID: String, challenge: String, attestation: String) async throws(DrillCloudError) -> PurchaseReply {
            if let welcomeError { throw welcomeError }
            welcomes.append((keyID, challenge, attestation))
            return welcomeReply
        }
        func inviteCode() async throws(DrillCloudError) -> InviteLink {
            InviteLink(code: "k7m2xq", url: "https://earmind.vercel.app/i/k7m2xq", app_url: "earmind://invite/k7m2xq")
        }
        func claimInvite(_ code: String) async throws(DrillCloudError) {
            if let claimError { throw claimError }
            claimed.append(code)
        }
    }

    @MainActor final class Counter { var reads = 0 }

    final class FakeAttest: DeviceAttesting, @unchecked Sendable {
        var supported = true
        var keys = 0
        var attestFails = false
        var attested: [String] = []
        struct Failed: Error {}

        var isSupported: Bool { supported }
        func newKey() async throws -> String {
            keys += 1
            return "key-\(keys)"
        }
        func attest(keyID: String, challenge: String) async throws -> Data {
            if attestFails { throw Failed() }
            attested.append("\(keyID)|\(challenge)")
            return Data("attestation".utf8)
        }
    }

    func make(_ name: String) throws -> (CreditShop, FakeFront, FakeServer, FakeAttest, UserDefaults) {
        let front = FakeFront()
        let server = FakeServer()
        let attest = FakeAttest()
        let defaults = try #require(UserDefaults(suiteName: "\(name)-\(UUID())"))
        return (CreditShop(front: front, server: server, attest: attest, defaults: defaults), front, server, attest, defaults)
    }

    static let receipt = StoreReceipt(jws: "signed.transaction.jws", transactionID: 42)

    // MARK: The products

    @Test func theProductsStandInOnePlace() async throws {
        #expect(StoreCatalog.ids == ["com.rsolutions.lumen.credits.100", "com.rsolutions.lumen.credits.500",
                                     "com.rsolutions.lumen.credits.2000", "com.rsolutions.lumen.sub.week"])
        #expect(StoreCatalog.entries.map(\.credits) == [100, 500, 2000, nil] && StoreCatalog.bestValue == StoreCatalog.ids[2])
        let (shop, front, _, _, _) = try make("a134-items")
        await shop.load()
        #expect(shop.packs.map(\.credits) == [100, 500, 2000] && shop.weeklyCard?.id == StoreCatalog.weekly)
        #expect(front.onReceipt != nil, "purchases that arrive by themselves are listened for")
    }

    // MARK: Buying

    @Test func aPurchaseGoesToTheServerAndIsFinishedOnlyThen() async throws {
        let (shop, front, server, _, _) = try make("a134-buy")
        await shop.load()
        let wallet = Counter()
        shop.onWalletChanged = { wallet.reads += 1 }
        let account = UUID()
        shop.accountID = { account.uuidString.lowercased() }
        front.outcome = .success(.bought(Self.receipt))

        await shop.buy(shop.packs[0])
        #expect(front.bought.count == 1 && front.bought[0].id == StoreCatalog.ids[0] && front.bought[0].account == account,
                "the purchase is tied to the account (appAccountToken)")
        #expect(server.verified == ["signed.transaction.jws"] && front.finished == [42] && wallet.reads == 1)
        #expect(shop.note == nil && shop.buying == nil)
    }

    @Test func aCancelledPurchaseChangesNothingAndSaysNothing() async throws {
        let (shop, front, server, _, _) = try make("a134-cancel")
        await shop.load()
        front.outcome = .success(.cancelled)
        await shop.buy(shop.packs[1])
        #expect(server.verified.isEmpty && front.finished.isEmpty && shop.note == nil)

        front.outcome = .success(.pending)
        await shop.buy(shop.packs[1])
        #expect(server.verified.isEmpty && shop.note == CreditShop.pendingLine)

        front.outcome = .failure(.unverified)
        await shop.buy(shop.packs[1])
        #expect(server.verified.isEmpty && shop.note == "Köpet gick inte igenom. Inget har dragits.")
    }

    @Test func aPaidPurchaseTheServerDidNotGetIsKeptAndTriedAgain() async throws {
        let (shop, front, server, _, _) = try make("a134-owed")
        await shop.load()
        front.outcome = .success(.bought(Self.receipt))
        server.verifyError = .offline("test")
        await shop.buy(shop.packs[0])
        #expect(front.finished.isEmpty, "not finished: the App Store gives it back")
        #expect(shop.note == CreditShop.owedLine, "never 'Inget har dragits' for a purchase that was made")

        // The App Store gives it back (at the next start): now the server has it.
        server.verifyError = nil
        await front.onReceipt?(Self.receipt)
        #expect(server.verified == ["signed.transaction.jws"] && front.finished == [42])
    }

    @Test func restoreGivesTheServerWhatTheAppleAccountHolds() async throws {
        let (shop, front, server, _, _) = try make("a134-restore")
        await shop.restore()
        #expect(shop.note == "Det fanns inga köp att hämta." && !shop.isRestoring)

        front.toRestore = [Self.receipt, StoreReceipt(jws: "second.jws", transactionID: 43)]
        await shop.restore()
        #expect(server.verified == ["signed.transaction.jws", "second.jws"] && front.finished == [42, 43] && shop.note == nil)

        server.verifyError = .offline("test")
        await shop.restore()
        #expect(shop.note == CreditShop.restoreFailedLine)
        front.restoreFails = true
        await shop.restore()
        #expect(shop.note == CreditShop.restoreFailedLine)
    }

    // MARK: Välkomstkrediter

    @Test func theWelcomeCreditsAreAskedForOnceWithAProof() async throws {
        let (shop, _, server, attest, defaults) = try make("a141-welcome")
        let wallet = Counter()
        shop.onWalletChanged = { wallet.reads += 1 }
        await shop.claimWelcome()
        #expect(attest.attested == ["key-1|challenge-1"], "the key attests the server's challenge")
        #expect(server.welcomes.count == 1 && server.welcomes[0].keyID == "key-1" && server.welcomes[0].challenge == "challenge-1")
        #expect(server.welcomes[0].attestation == Data("attestation".utf8).base64EncodedString())
        #expect(defaults.bool(forKey: CreditShop.welcomeDoneKey) && wallet.reads == 1)

        await shop.claimWelcome()
        let next = CreditShop(front: FakeFront(), server: server, attest: attest, defaults: defaults) // the next app run
        await next.claimWelcome()
        #expect(server.welcomes.count == 1 && attest.keys == 1, "never asked again")
    }

    @Test func withoutAProofNothingIsAskedAndAFailingProofIsGivenUp() async throws {
        let (shop, _, server, attest, defaults) = try make("a141-noproof")
        attest.supported = false // the Simulator
        await shop.claimWelcome()
        #expect(server.challenges == 0 && attest.keys == 0)

        // The server is not set up yet (503): asked again at the next start, with the same key.
        attest.supported = true
        server.challengeError = .refused(status: 503, code: "attest_unconfigured", message: "Inte tillgängligt än.")
        await CreditShop(front: FakeFront(), server: server, attest: attest, defaults: defaults).claimWelcome()
        #expect(attest.keys == 1 && defaults.string(forKey: CreditShop.attestKeyKey) == "key-1" && defaults.integer(forKey: CreditShop.welcomeTriesKey) == 0)

        // A build Apple does not attest: three tries, then no more.
        server.challengeError = nil
        attest.attestFails = true
        for _ in 0..<5 { await CreditShop(front: FakeFront(), server: server, attest: attest, defaults: defaults).claimWelcome() }
        #expect(server.challenges == 3 && server.welcomes.isEmpty && !defaults.bool(forKey: CreditShop.welcomeDoneKey))
        #expect(defaults.integer(forKey: CreditShop.welcomeTriesKey) == CreditShop.maxWelcomeTries)
    }

    // MARK: Bjud in

    @Test func anOpenedInvitationIsClaimedAfterTheWelcomeCheck() async throws {
        #expect(InviteLink.code(in: try #require(URL(string: "earmind://invite/k7m2xq"))) == "k7m2xq")
        #expect(InviteLink.code(in: try #require(URL(string: "earmind://prov/k7m2xq"))) == nil)
        #expect(InviteLink.code(in: try #require(URL(string: "earmind://invite/a%20b"))) == nil)
        #expect(InviteLink.code(in: try #require(URL(string: "https://earmind.vercel.app/i/k7m2xq"))) == nil)

        let (shop, _, server, _, defaults) = try make("a141-invite")
        #expect(shop.handle(try #require(URL(string: "earmind://invite/k7m2xq"))))
        #expect(!shop.handle(try #require(URL(string: "earmind://prov/abc123"))))
        for _ in 0..<100 where server.claimed.isEmpty { try? await Task.sleep(for: .milliseconds(2)) }
        #expect(server.welcomes.count == 1 && server.claimed == ["k7m2xq"], "the proof first, then the invitation")
        #expect(defaults.string(forKey: CreditShop.pendingInviteKey) == nil)

        // A no that stays a no is dropped; no network keeps it for later.
        defaults.set("other1", forKey: CreditShop.pendingInviteKey)
        server.claimError = .offline("test")
        await shop.claimWelcome()
        #expect(defaults.string(forKey: CreditShop.pendingInviteKey) == "other1")
        server.claimError = .refused(status: 409, code: "invite_already", message: "")
        await shop.claimWelcome()
        #expect(defaults.string(forKey: CreditShop.pendingInviteKey) == nil)

        await shop.loadInvite()
        #expect(shop.invite?.shareURL?.absoluteString == "https://earmind.vercel.app/i/k7m2xq")
    }

    // MARK: The words and the numbers

    @Test func theWordsAreKellys() {
        #expect(ShopText.pack(100) == "100 krediter" && ShopText.pack(2000) == "2\u{00A0}000 krediter")
        #expect(ShopText.bestValue == "Bäst värde" && ShopText.examLine == "Ett prov ≈ 6 000 krediter.")
        #expect(ShopText.weeklyLine(price: "79,00 kr", weekLimit: 20_000) == "79,00 kr i veckan · cirka 3 prov")
        #expect(ShopText.weeklyLine(price: "79,00 kr", weekLimit: nil) == "79,00 kr i veckan · cirka 3 prov")
        #expect(ShopText.terms(price: "79,00 kr").hasPrefix("Veckokortet kostar 79,00 kr i veckan och förnyas automatiskt tills du säger upp det"))
        #expect(ShopText.inviteTitle == "Få 2 000 krediter" && ShopText.inviteLine == "när en kompis har spelat sin första text")
        #expect(CreditShop.inviteText == "Plugga med EarMind. Du får 5 000 krediter att börja med.")
        #expect(ShopText.refill == "Fyll på" && ShopText.included == "Ingår" && ShopText.manage == "Hantera veckokortet")
    }

    @Test func theWeeklyCardSaysItsDayAndWhatIsLeftOfTheWeek() throws {
        let json = #"{"unit":"chars","limit":1500,"used":0,"remaining":17436,"subscription":{"active":true,"until":"2026-11-24T10:00:00.000Z","week_used":3800,"week_limit":20000}}"#
        let quota = try JSONDecoder().decode(DrillQuota.self, from: Data(json.utf8))
        let card = try #require(quota.subscription)
        #expect(ShopText.day(card.until) == "24 nov" && ShopText.day("2026-11-24T10:00:00Z") == "24 nov" && ShopText.day("nonsense") == nil)
        #expect(ShopText.weekLine(card) == "till 24 nov · 16\u{00A0}200 av 20\u{00A0}000 tecken kvar i veckan")
        #expect(ShopText.renews(card, price: "79,00 kr") == "Förnyas automatiskt den 24 nov för 79,00 kr.")

        // By Spela: "Ingår" while the week covers it; the usual line when the week is out and other credits pay;
        // "Veckans tak är nått" when nothing covers it. Without a card, the credits as before.
        #expect(SayText.costLine(cost: 120, left: 17_436, subscription: card) == "Ingår")
        var out = card
        out.week_used = 20_000
        #expect(ShopText.weekIsOut(out) && !ShopText.weekIsOut(card) && !ShopText.weekIsOut(nil))
        #expect(SayText.costLine(cost: 120, left: 1236, subscription: out) == "120 krediter")
        #expect(SayText.costLine(cost: 120, left: 88, subscription: out) == "Veckans tak är nått")
        #expect(SayText.costLine(cost: 120, left: 88, subscription: nil) == "120 krediter · du har 88")
        var ended = card
        ended.active = false
        #expect(SayText.costLine(cost: 120, left: 1236, subscription: ended) == "120 krediter")
    }

    @Test func theSheetSaysKrediterKvarWhenCreditsCanBeBought() {
        var quota = DrillQuota(used: 264, limit: 1500, per: "month", resets: "2026-12-01")
        quota.unit = "chars"
        quota.remaining = 1236
        #expect(CreditsText.leftLine(quota, withShop: true) == "krediter kvar")
        #expect(CreditsText.leftLine(quota, withShop: false) == "krediter kvar den här månaden")
    }

    @Test func theServersAnswerIsRead() throws {
        let json = #"{"ok":true,"kind":"credits","added":500,"transaction_id":"2000000123","product_id":"com.rsolutions.lumen.credits.500","wallet":{"unit":"chars","remaining":1736,"monthly_free":1236,"purchased":500,"subscription":{"active":false}}}"#
        let reply = try JSONDecoder().decode(PurchaseReply.self, from: Data(json.utf8))
        #expect(reply.ok == true && reply.kind == "credits" && reply.added == 500)
        let welcome = try JSONDecoder().decode(PurchaseReply.self, from: Data(#"{"ok":true,"added":0,"reason":"already"}"#.utf8))
        #expect(welcome.added == 0 && welcome.reason == "already")
        let link = try JSONDecoder().decode(InviteLink.self, from: Data(#"{"code":"k7m2xq","url":"https://earmind.vercel.app/i/k7m2xq","app_url":"earmind://invite/k7m2xq"}"#.utf8))
        #expect(link.code == "k7m2xq" && link.shareURL != nil)
    }
}
