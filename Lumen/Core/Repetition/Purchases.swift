import CryptoKit
import DeviceCheck
import Foundation
import Observation
import StoreKit

// A134 (D218, D214) and A141 (D224): credits can be bought. The App Store does the buying (StoreKit 2); the server
// decides what a purchase is worth: the signed transaction goes to `/purchase` (Kevin's K94), which checks Apple's
// signature and fills the wallet. The app never adds credits itself. No key and no price is in the app: the prices
// come from the App Store (`displayPrice`), the product ids stand in one place (`StoreCatalog`).

/// The four products (K94, `store_products` on the server; TILL-ARON #26). The only place their ids stand.
enum StoreCatalog {
    struct Entry: Equatable, Sendable {
        var id: String
        /// The credits of a pack; nil for the weekly card.
        var credits: Int?
    }

    static let weekly = "com.rsolutions.lumen.sub.week"
    static let entries = [Entry(id: "com.rsolutions.lumen.credits.100", credits: 100),
                          Entry(id: "com.rsolutions.lumen.credits.500", credits: 500),
                          Entry(id: "com.rsolutions.lumen.credits.2000", credits: 2000),
                          Entry(id: weekly, credits: nil)]
    static var ids: [String] { entries.map(\.id) }
    /// Ke77 (D224): the pack marked "Bäst värde".
    static let bestValue = "com.rsolutions.lumen.credits.2000"
}

/// A product as the sheet shows it: the App Store's own price text.
struct StoreItem: Equatable, Identifiable, Sendable {
    var id: String
    var displayPrice: String
    var credits: Int?

    var isWeekly: Bool { credits == nil }
}

/// A purchase the App Store has signed: what the server is given, and the transaction to finish once it has it.
struct StoreReceipt: Equatable, Sendable {
    var jws: String
    var transactionID: UInt64
}

enum StoreOutcome: Equatable, Sendable {
    case bought(StoreReceipt)
    case cancelled
    /// Ask to Buy and the like: nothing is bought yet; it arrives later as an update.
    case pending
}

enum StoreFailure: Error, Equatable {
    case unknownProduct
    case unverified
}

/// The App Store, as the shop needs it (the tests and the screenshots have their own).
@MainActor
protocol StoreFront: AnyObject {
    func items() async -> [StoreItem]
    func buy(_ id: String, account: UUID?) async throws -> StoreOutcome
    /// Told when the server has the purchase; until then the App Store keeps giving it back.
    func finish(_ transactionID: UInt64) async
    /// "Återställ köp": asks the App Store again and gives what this Apple account holds.
    func restore() async throws -> [StoreReceipt]
    /// Purchases that arrive outside a tap on a button (a renewal, Ask to Buy, one bought on another device).
    func listen(_ onReceipt: @escaping @MainActor (StoreReceipt) async -> Void)
}

/// StoreKit 2.
@MainActor
final class AppStoreFront: StoreFront {
    private var products: [String: Product] = [:]
    private var open: [UInt64: Transaction] = [:]
    private var updates: Task<Void, Never>?

    func items() async -> [StoreItem] {
        let found = (try? await Product.products(for: StoreCatalog.ids)) ?? []
        for product in found { products[product.id] = product }
        return StoreCatalog.entries.compactMap { entry in
            products[entry.id].map { StoreItem(id: entry.id, displayPrice: $0.displayPrice, credits: entry.credits) }
        }
    }

    func buy(_ id: String, account: UUID?) async throws -> StoreOutcome {
        guard let product = products[id] else { throw StoreFailure.unknownProduct }
        // K94: the purchase is tied to this account, so the server refuses it for another one.
        let options: Set<Product.PurchaseOption> = account.map { [.appAccountToken($0)] } ?? []
        switch try await product.purchase(options: options) {
        case .success(let result):
            guard case .verified(let transaction) = result else { throw StoreFailure.unverified }
            open[transaction.id] = transaction
            return .bought(StoreReceipt(jws: result.jwsRepresentation, transactionID: transaction.id))
        case .pending:
            return .pending
        case .userCancelled:
            return .cancelled
        @unknown default:
            return .cancelled
        }
    }

    func finish(_ transactionID: UInt64) async {
        await open[transactionID]?.finish()
        open[transactionID] = nil
    }

    func restore() async throws -> [StoreReceipt] {
        try await AppStore.sync()
        var receipts: [StoreReceipt] = []
        // What is still owed (a pack the server never got) and what is held now (the weekly card).
        for await result in Transaction.unfinished { keep(result, in: &receipts) }
        for await result in Transaction.currentEntitlements { keep(result, in: &receipts) }
        return receipts
    }

    private func keep(_ result: VerificationResult<Transaction>, in receipts: inout [StoreReceipt]) {
        guard case .verified(let transaction) = result, !receipts.contains(where: { $0.transactionID == transaction.id }) else { return }
        open[transaction.id] = transaction
        receipts.append(StoreReceipt(jws: result.jwsRepresentation, transactionID: transaction.id))
    }

    func listen(_ onReceipt: @escaping @MainActor (StoreReceipt) async -> Void) {
        updates?.cancel()
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                guard case .verified(let transaction) = result else { continue }
                self?.open[transaction.id] = transaction
                await onReceipt(StoreReceipt(jws: result.jwsRepresentation, transactionID: transaction.id))
            }
        }
    }
}

// MARK: - The server (`/purchase`, K94 and K98)

/// What `/purchase` answers for "verify" and "welcome".
struct PurchaseReply: Decodable, Sendable, Equatable {
    var ok: Bool? = nil
    /// "credits" or "subscription".
    var kind: String? = nil
    /// The credits this call added; 0 for a purchase the server already had.
    var added: Int? = nil
    /// "already" or "key_used" when the welcome credits were given before.
    var reason: String? = nil
}

/// K98: `{code, url, app_url}`.
struct InviteLink: Decodable, Sendable, Equatable {
    var code: String
    var url: String
    var app_url: String? = nil

    var shareURL: URL? { URL(string: url) }

    /// `earmind://invite/<code>`: the code of an invitation that was opened.
    static func code(in url: URL) -> String? {
        guard url.scheme == "earmind", url.host() == "invite" else { return nil }
        let code = url.lastPathComponent
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        guard (4...64).contains(code.count), code.unicodeScalars.allSatisfy(allowed.contains) else { return nil }
        return code
    }
}

@MainActor
protocol PurchaseServing: AnyObject {
    func verify(jws: String) async throws(DrillCloudError) -> PurchaseReply
    func attestChallenge() async throws(DrillCloudError) -> String
    func welcome(keyID: String, challenge: String, attestation: String) async throws(DrillCloudError) -> PurchaseReply
    func inviteCode() async throws(DrillCloudError) -> InviteLink
    func claimInvite(_ code: String) async throws(DrillCloudError)
}

@MainActor
final class PurchaseClient: PurchaseServing {
    private let config: BackendConfig
    private let auth: SupabaseAuth
    private let http: any HTTPStreaming

    init(config: BackendConfig, auth: SupabaseAuth, http: any HTTPStreaming) {
        self.config = config
        self.auth = auth
        self.http = http
    }

    func verify(jws: String) async throws(DrillCloudError) -> PurchaseReply {
        try await call(["action": "verify", "jws": jws])
    }

    func attestChallenge() async throws(DrillCloudError) -> String {
        struct Reply: Decodable { var challenge: String }
        let reply: Reply = try await call(["action": "attest_challenge"])
        return reply.challenge
    }

    func welcome(keyID: String, challenge: String, attestation: String) async throws(DrillCloudError) -> PurchaseReply {
        try await call(["action": "welcome", "key_id": keyID, "challenge": challenge, "attestation": attestation])
    }

    func inviteCode() async throws(DrillCloudError) -> InviteLink {
        try await call(["action": "invite_code"])
    }

    func claimInvite(_ code: String) async throws(DrillCloudError) {
        let _: PurchaseReply = try await call(["action": "invite_claim", "code": code])
    }

    private func call<Reply: Decodable>(_ body: [String: String]) async throws(DrillCloudError) -> Reply {
        let action = body["action"] ?? ""
        let response: HTTPURLResponse
        let data: Data
        do {
            let token = try await auth.accessToken()
            var request = URLRequest(url: config.projectURL.appending(path: "functions/v1/purchase"))
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue(config.publishableKey, forHTTPHeaderField: "apikey")
            request.markTestTraffic()
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 30
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            (response, data) = try await http.data(for: request)
        } catch {
            Log.repetition.error("purchase \(action, privacy: .public): \(error.localizedDescription, privacy: .public)")
            throw .offline(error.localizedDescription)
        }
        guard response.statusCode == 200 else {
            let refusal = DrillCloudClient.refusal(status: response.statusCode, data: data)
            Log.repetition.error("purchase \(action, privacy: .public): HTTP \(response.statusCode, privacy: .public) \(refusal.errorCode, privacy: .public)")
            throw refusal
        }
        do {
            return try JSONDecoder().decode(Reply.self, from: data)
        } catch {
            throw .offline("bad reply")
        }
    }
}

// MARK: - App Attest (K98)

/// Apple's proof that this is the real app on a real iPhone. The welcome credits are given once per proven
/// installation, so scripts and changed apps get none.
protocol DeviceAttesting: Sendable {
    var isSupported: Bool { get }
    func newKey() async throws -> String
    /// The attestation of the key over the server's challenge (clientDataHash = SHA-256 of the challenge's bytes).
    func attest(keyID: String, challenge: String) async throws -> Data
}

struct AppAttest: DeviceAttesting {
    var isSupported: Bool { DCAppAttestService.shared.isSupported }

    func newKey() async throws -> String {
        try await DCAppAttestService.shared.generateKey()
    }

    func attest(keyID: String, challenge: String) async throws -> Data {
        let hash = Data(SHA256.hash(data: Data(challenge.utf8)))
        return try await DCAppAttestService.shared.attestKey(keyID, clientDataHash: hash)
    }
}

// MARK: - The shop

/// What the credits sheet works with: the products, a purchase in progress, and the words when something did not
/// go through. It also asks for the welcome credits once (A141) and hands an opened invitation to the server.
@MainActor
@Observable
final class CreditShop {
    private(set) var items: [StoreItem] = []
    /// The product being bought (its button shows a spinner).
    private(set) var buying: String?
    private(set) var isRestoring = false
    /// What is said under the products after a purchase or a restore that needs words.
    var note: String?
    /// K98: this account's invitation, once asked for.
    private(set) var invite: InviteLink?

    /// The wallet changed on the server: the month's number is read again.
    @ObservationIgnored var onWalletChanged: (@MainActor () async -> Void)?
    /// K94: the signed-in account, so a purchase belongs to it.
    @ObservationIgnored var accountID: (@MainActor () async -> String?)?

    @ObservationIgnored private let front: any StoreFront
    @ObservationIgnored private let server: any PurchaseServing
    @ObservationIgnored private let attest: any DeviceAttesting
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var listens = false
    @ObservationIgnored private var askedWelcome = false

    // Kelly Ke73/Ke77 §5.
    static let failedLine = "Köpet gick inte igenom. Inget har dragits."
    static let nothingToRestoreLine = "Det fanns inga köp att hämta."
    // Mine (not in Ke77): the App Store took the purchase but the server could not be told yet.
    static let owedLine = "Köpet är gjort men kunde inte läggas in just nu. Det läggs in när EarMind har kontakt igen."
    static let pendingLine = "Köpet väntar på godkännande. Krediterna kommer när det är godkänt."
    static let restoreFailedLine = "Det gick inte att hämta köpen just nu. Försök igen om en stund."
    static let inviteText = "Plugga med EarMind. Du får 5 000 krediter att börja med."

    static let welcomeDoneKey = "credits.welcomeDone"
    static let welcomeTriesKey = "credits.welcomeTries"
    static let attestKeyKey = "credits.attestKeyID"
    static let pendingInviteKey = "credits.pendingInvite"
    /// A proof that keeps failing (a build Apple does not attest) is not asked for at every start for ever.
    static let maxWelcomeTries = 3

    init(front: any StoreFront, server: any PurchaseServing, attest: any DeviceAttesting = AppAttest(),
         defaults: UserDefaults = .standard) {
        self.front = front
        self.server = server
        self.attest = attest
        self.defaults = defaults
    }

    var packs: [StoreItem] { items.filter { !$0.isWeekly } }
    var weeklyCard: StoreItem? { items.first(where: \.isWeekly) }

    /// The products from the App Store, and from now on purchases that arrive by themselves.
    func load() async {
        if !listens {
            listens = true
            front.listen { [weak self] receipt in _ = await self?.deliver(receipt) }
        }
        if items.isEmpty { items = await front.items() }
    }

    func buy(_ item: StoreItem) async {
        guard buying == nil else { return }
        buying = item.id
        note = nil
        defer { buying = nil }
        do {
            let account = await accountID?().flatMap { UUID(uuidString: $0) }
            switch try await front.buy(item.id, account: account) {
            case .bought(let receipt):
                // The App Store has the purchase. It is only finished when the server has it too; until then the App
                // Store gives it back at the next start, so a paid pack is never lost.
                if await !deliver(receipt) { note = Self.owedLine }
            case .pending:
                note = Self.pendingLine
            case .cancelled:
                break // nothing happened, nothing is said
            }
        } catch {
            Log.repetition.error("Purchase: \(error.localizedDescription, privacy: .public)")
            note = Self.failedLine
        }
    }

    /// "Återställ köp".
    func restore() async {
        guard !isRestoring else { return }
        isRestoring = true
        note = nil
        defer { isRestoring = false }
        do {
            let receipts = try await front.restore()
            var delivered = 0
            for receipt in receipts {
                if await deliver(receipt) { delivered += 1 }
            }
            if receipts.isEmpty { note = Self.nothingToRestoreLine } else if delivered == 0 { note = Self.restoreFailedLine }
        } catch {
            Log.repetition.error("Restore: \(error.localizedDescription, privacy: .public)")
            note = Self.restoreFailedLine
        }
    }

    /// Gives the server the signed transaction. True when the server has it (also when it already had it).
    @discardableResult
    func deliver(_ receipt: StoreReceipt) async -> Bool {
        do throws(DrillCloudError) {
            _ = try await server.verify(jws: receipt.jws)
        } catch {
            Log.repetition.error("Purchase verify: \(error.errorCode, privacy: .public)")
            return false // not finished: the App Store gives it back, and it is tried again
        }
        await front.finish(receipt.transactionID)
        await onWalletChanged?()
        return true
    }

    // MARK: Bjud in (K98)

    /// The account's invitation link (the same every time).
    func loadInvite() async {
        guard invite == nil else { return }
        invite = try? await server.inviteCode()
    }

    /// `earmind://invite/<code>`: kept until the server has it. It is claimed after the welcome check, since the
    /// server wants a proven installation first.
    func handle(_ url: URL) -> Bool {
        guard let code = InviteLink.code(in: url) else { return false }
        defaults.set(code, forKey: Self.pendingInviteKey)
        Task { await claimWelcome() }
        return true
    }

    // MARK: Välkomstkrediter (K98, A141)

    /// Once per installation: proves the installation to the server (App Attest), which then gives the welcome
    /// credits if this account and this key have had none. Asked at most once per app run, and no more after it has
    /// been answered or has failed three times.
    func claimWelcome() async {
        if !defaults.bool(forKey: Self.welcomeDoneKey), !askedWelcome, attest.isSupported,
           defaults.integer(forKey: Self.welcomeTriesKey) < Self.maxWelcomeTries {
            askedWelcome = true
            await proveInstallation()
        }
        await claimInvite()
    }

    private func proveInstallation() async {
        let keyID: String
        do {
            if let stored = defaults.string(forKey: Self.attestKeyKey) {
                keyID = stored
            } else {
                keyID = try await attest.newKey()
                defaults.set(keyID, forKey: Self.attestKeyKey)
            }
        } catch {
            Log.repetition.info("Welcome: no key (\(error.localizedDescription, privacy: .public))")
            return
        }
        let challenge: String
        do throws(DrillCloudError) {
            challenge = try await server.attestChallenge()
        } catch {
            Log.repetition.info("Welcome: no challenge (\(error.errorCode, privacy: .public))")
            return // the server is not set up yet (503), or no network: asked again at the next start
        }
        let attestation: Data
        do {
            attestation = try await attest.attest(keyID: keyID, challenge: challenge)
        } catch {
            // A key is attested once. One that cannot be (used before, or a build Apple does not attest) is dropped.
            defaults.removeObject(forKey: Self.attestKeyKey)
            defaults.set(defaults.integer(forKey: Self.welcomeTriesKey) + 1, forKey: Self.welcomeTriesKey)
            Log.repetition.info("Welcome: no attestation (\(error.localizedDescription, privacy: .public))")
            return
        }
        do throws(DrillCloudError) {
            let reply = try await server.welcome(keyID: keyID, challenge: challenge, attestation: attestation.base64EncodedString())
            defaults.set(true, forKey: Self.welcomeDoneKey)
            if (reply.added ?? 0) > 0 { await onWalletChanged?() }
        } catch {
            // The key has been used for an attestation now, so the next try needs a new one.
            defaults.removeObject(forKey: Self.attestKeyKey)
            defaults.set(defaults.integer(forKey: Self.welcomeTriesKey) + 1, forKey: Self.welcomeTriesKey)
            Log.repetition.info("Welcome: refused (\(error.errorCode, privacy: .public))")
        }
    }

    private func claimInvite() async {
        guard defaults.bool(forKey: Self.welcomeDoneKey), let code = defaults.string(forKey: Self.pendingInviteKey) else { return }
        do throws(DrillCloudError) {
            try await server.claimInvite(code)
            defaults.removeObject(forKey: Self.pendingInviteKey)
        } catch {
            // A no that will stay a no (not found, one's own, already invited) is not asked again.
            if case .refused(let status, _, _) = error, status == 404 || status == 409 {
                defaults.removeObject(forKey: Self.pendingInviteKey)
            }
            Log.repetition.info("Invite: \(error.errorCode, privacy: .public)")
        }
    }
}

/// Ke73/Ke77: the words of the purchase part of the credits sheet.
enum ShopText {
    static let bestValue = "Bäst värde"
    static let examLine = "Ett prov ≈ 6 000 krediter."
    static let creditsPerExam = 6000
    static let weeklyTitle = "Veckokort"
    static let inviteTitle = "Få 2 000 krediter"
    static let inviteLine = "när en kompis har spelat sin första text"
    static let inviteButton = "Bjud in"
    static let refill = "Fyll på"
    static let included = "Ingår"
    static let weekIsOut = "Veckans tak är nått"
    static let manage = "Hantera veckokortet"
    static let termsURL = URL(string: "https://earmind.vercel.app/villkor")
    static let privacyURL = URL(string: "https://earmind.vercel.app/integritet")

    /// "100 krediter", "2 000 krediter".
    static func pack(_ credits: Int) -> String { "\(CreditText.number(credits)) krediter" }

    /// "79 kr i veckan · cirka 3 prov" (the week's ceiling over an exam's credits).
    static func weeklyLine(price: String, weekLimit: Int?) -> String {
        let exams = (weekLimit ?? 20_000) / creditsPerExam
        return exams > 0 ? "\(price) i veckan · cirka \(exams) prov" : "\(price) i veckan"
    }

    /// Apple's guideline 3.1.2: what the subscription costs, that it renews, and how it is ended.
    static func terms(price: String) -> String {
        "Veckokortet kostar \(price) i veckan och förnyas automatiskt tills du säger upp det, senast 24 timmar före nästa vecka. "
            + "Säg upp i Inställningar › ditt namn › Prenumerationer."
    }

    /// "24 nov" from the server's "2026-11-24T10:00:00.000Z".
    static func day(_ iso: String?) -> String? {
        guard let iso else { return nil }
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = withFraction.date(from: iso) ?? ISO8601DateFormatter().date(from: iso) else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "sv_SE")
        formatter.timeZone = TimeZone(identifier: "Europe/Stockholm")
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date).replacingOccurrences(of: ".", with: "")
    }

    /// "till 24 nov · 16 200 av 20 000 tecken kvar i veckan".
    static func weekLine(_ subscription: DrillQuota.Subscription) -> String {
        var parts: [String] = []
        if let day = day(subscription.until) { parts.append("till \(day)") }
        if let limit = subscription.week_limit {
            let left = max(0, limit - (subscription.week_used ?? 0))
            parts.append("\(CreditText.number(left)) av \(CreditText.number(limit)) tecken kvar i veckan")
        }
        return parts.joined(separator: " · ")
    }

    /// "Förnyas automatiskt den 24 nov för 79 kr."
    static func renews(_ subscription: DrillQuota.Subscription, price: String?) -> String? {
        guard let day = day(subscription.until) else { return nil }
        return price.map { "Förnyas automatiskt den \(day) för \($0)." } ?? "Förnyas automatiskt den \(day)."
    }

    /// K94: the week's characters are used up (the month's and the bought credits may still cover a text).
    static func weekIsOut(_ subscription: DrillQuota.Subscription?) -> Bool {
        guard let subscription, subscription.active == true, let limit = subscription.week_limit else { return false }
        return (subscription.week_used ?? 0) >= limit
    }
}
