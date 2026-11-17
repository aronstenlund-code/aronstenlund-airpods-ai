import StoreKit
import SwiftUI

/// A134 (D218) and A141 (D224), Kelly Ke73/Ke77: the purchase part of the credits sheet. FYLL PÅ (the packs),
/// VARJE VECKA (the weekly card) and BJUD IN, then Apple's subscription footnote and the links. The price buttons are
/// tinted capsules (nothing is chosen beforehand); the prices are the App Store's own text.
struct ShopSections: View {
    let model: RepetitionModel
    let shop: CreditShop
    let quota: DrillQuota
    @State private var managing = false
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        if let subscription = quota.subscription, quota.hasWeeklyCard {
            Section {
                Button(ShopText.manage) { managing = true }
            } footer: {
                if let line = ShopText.renews(subscription, price: shop.weeklyCard?.displayPrice) { Text(verbatim: line) }
            }
            .manageSubscriptionsSheet(isPresented: $managing)
        }
        if !shop.packs.isEmpty {
            Section {
                ForEach(shop.packs) { item in
                    row(item, title: ShopText.pack(item.credits ?? 0), line: nil, badge: item.id == StoreCatalog.bestValue)
                }
            } header: {
                Text("Fyll på")
            } footer: {
                Text(verbatim: ShopText.examLine)
            }
        }
        if let card = shop.weeklyCard, !quota.hasWeeklyCard {
            Section {
                row(card, title: ShopText.weeklyTitle,
                    line: ShopText.weeklyLine(price: card.displayPrice, weekLimit: quota.subscription?.week_limit), badge: false)
            } header: {
                Text("Varje vecka")
            }
        }
        Section {
            inviteRow
        } header: {
            Text("Bjud in")
        } footer: {
            VStack(alignment: .leading, spacing: 10) {
                if let note = shop.note {
                    Text(verbatim: note).font(.footnote.weight(.semibold)).foregroundStyle(.primary)
                        .accessibilityAddTraits(.updatesFrequently)
                }
                if let card = shop.weeklyCard { Text(verbatim: ShopText.terms(price: card.displayPrice)) }
                links
            }
        }
        .task { await shop.loadInvite() }
    }

    /// A product: its name (and a line under it), and the price as a tinted capsule. With the largest text the price
    /// stands under the name.
    private func row(_ item: StoreItem, title: String, line: String?, badge: Bool) -> some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(spacing: 8))
        return layout {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(verbatim: title)
                    if badge {
                        Text(verbatim: ShopText.bestValue)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.accentColor.opacity(0.15), in: Capsule())
                            .foregroundStyle(.tint)
                    }
                }
                if let line { Text(verbatim: line).font(.footnote).foregroundStyle(.secondary) }
            }
            if !typeSize.isAccessibilitySize { Spacer(minLength: 8) }
            Button {
                Task { await shop.buy(item) }
            } label: {
                if shop.buying == item.id {
                    ProgressView().controlSize(.small).frame(minWidth: 44)
                } else {
                    Text(verbatim: item.displayPrice).font(.subheadline.weight(.semibold)).monospacedDigit().lineLimit(1)
                }
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .tint(.accentColor)
            .disabled(shop.buying != nil)
            .accessibilityLabel("Köp \(title) för \(item.displayPrice)")
        }
    }

    @ViewBuilder
    private var inviteRow: some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(spacing: 8))
        layout {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: ShopText.inviteTitle)
                Text(verbatim: ShopText.inviteLine).font(.footnote).foregroundStyle(.secondary)
            }
            if !typeSize.isAccessibilitySize { Spacer(minLength: 8) }
            if let url = shop.invite?.shareURL {
                ShareLink(item: url, message: Text(verbatim: CreditShop.inviteText)) {
                    Text(verbatim: ShopText.inviteButton).font(.subheadline.weight(.semibold)).lineLimit(1)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .tint(.accentColor)
            } else {
                // The link is not here yet (or the server has none): the button waits.
                Button(ShopText.inviteButton) { Task { await shop.loadInvite() } }
                    .font(.subheadline.weight(.semibold))
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .tint(.accentColor)
            }
        }
    }

    /// "Villkor · Integritet · Återställ köp".
    private var links: some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10)) : AnyLayout(HStackLayout(spacing: 16))
        return layout {
            if let url = ShopText.termsURL { Link("Villkor", destination: url) }
            if let url = ShopText.privacyURL { Link("Integritet", destination: url) }
            Button {
                Task { await shop.restore() }
            } label: {
                if shop.isRestoring { ProgressView().controlSize(.small) } else { Text("Återställ köp") }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.tint)
            .disabled(shop.isRestoring)
        }
        .font(.footnote)
    }
}

#if DEBUG
/// The Simulator screenshots: the four products without the App Store, and a server that answers nothing.
@MainActor
final class StagedStoreFront: StoreFront {
    func items() async -> [StoreItem] {
        [StoreItem(id: StoreCatalog.entries[0].id, displayPrice: "10,00 kr", credits: 100),
         StoreItem(id: StoreCatalog.entries[1].id, displayPrice: "39,00 kr", credits: 500),
         StoreItem(id: StoreCatalog.entries[2].id, displayPrice: "110,00 kr", credits: 2000),
         StoreItem(id: StoreCatalog.weekly, displayPrice: "79,00 kr", credits: nil)]
    }
    func buy(_ id: String, account: UUID?) async throws -> StoreOutcome { .cancelled }
    func finish(_ transactionID: UInt64) async {}
    func restore() async throws -> [StoreReceipt] { [] }
    func listen(_ onReceipt: @escaping @MainActor (StoreReceipt) async -> Void) {}
}

@MainActor
final class StagedPurchaseServer: PurchaseServing {
    func verify(jws: String) async throws(DrillCloudError) -> PurchaseReply { PurchaseReply() }
    func attestChallenge() async throws(DrillCloudError) -> String { throw .offline("staged") }
    func welcome(keyID: String, challenge: String, attestation: String) async throws(DrillCloudError) -> PurchaseReply { PurchaseReply() }
    func inviteCode() async throws(DrillCloudError) -> InviteLink {
        InviteLink(code: "k7m2xq", url: "https://earmind.vercel.app/i/k7m2xq", app_url: "earmind://invite/k7m2xq")
    }
    func claimInvite(_ code: String) async throws(DrillCloudError) {}
}
#endif
