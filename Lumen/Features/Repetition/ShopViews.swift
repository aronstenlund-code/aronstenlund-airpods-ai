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
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    private var reduceMotion: Bool { SayMotion.reduces(systemReduceMotion) }

    var body: some View {
        if !shop.newRewards.isEmpty {
            // Ke77 §1c (K99): an invitation has given credits since the sheet was last shown.
            Section {
                ForEach(Array(shop.newRewards.enumerated()), id: \.offset) { _, credits in
                    Text(verbatim: ShopText.rewardLine(credits)).font(.subheadline.weight(.semibold))
                }
            }
        }
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
                // A161 (D259): during the launch week the offer stands first, and each pack shows its launch price
                // with the ordinary one struck through.
                if let offer = shop.activeOffer() { LaunchOfferRow(offer: offer, shop: shop) }
                ForEach(shop.packs) { item in
                    row(item, title: ShopText.pack(item.credits ?? 0), line: nil, badge: StoreCatalog.isBestValue(item.id))
                }
            } header: {
                Text("Fyll på").foregroundStyle(LumenColor.secondaryText) // A148: AA
            } footer: {
                Text(verbatim: ShopText.examLine).foregroundStyle(LumenColor.secondaryText)
            }
        }
        if shop.hasNoProducts {
            // Toby T48: nothing came from the App Store. Said where the packs would be, with a way to ask again.
            Section {
                Text(verbatim: ShopText.noProducts).foregroundStyle(LumenColor.secondaryText)
                Button(ShopText.tryAgain) { Task { await shop.reload() } }
            } header: {
                Text("Fyll på").foregroundStyle(LumenColor.secondaryText) // A148: AA
            }
        }
        if let card = shop.weeklyCard, !quota.hasWeeklyCard {
            Section {
                if let offered = shop.weeklyOffer() {
                    // A161 (D259): during the launch week the first week's price, with the ordinary one struck through.
                    row(offered, title: ShopText.weeklyTitle,
                        line: ShopText.weeklyIntroLine(intro: offered.displayPrice, regular: card.displayPrice), badge: false)
                } else {
                    row(card, title: ShopText.weeklyTitle,
                        line: ShopText.weeklyLine(price: card.displayPrice, weekLimit: quota.subscription?.week_limit), badge: false)
                }
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
                        .transition(SayMotion.appear)
                }
                if let card = shop.weeklyCard {
                    // A148: VoiceOver reads the path with commas, not the arrow signs.
                    // A161: with the launch week's first-week price the footnote says both prices (3.1.2).
                    let terms = ShopText.terms(price: card.displayPrice, intro: quota.hasWeeklyCard ? nil : shop.weeklyOffer()?.displayPrice)
                    Text(verbatim: terms)
                        .foregroundStyle(LumenColor.secondaryText)
                        .accessibilityLabel(terms.replacingOccurrences(of: " › ", with: ", "))
                }
                links
            }
        }
        .task { await shop.loadInvite() }
        // A150: a purchase that the server has taken is felt once (the number above rolls up at the same moment).
        .sensoryFeedback(trigger: quota.left) { (old: Int, new: Int) -> SensoryFeedback? in
            new > old ? .success : nil
        }
        .sensoryFeedback(trigger: shop.note) { (_: String?, new: String?) -> SensoryFeedback? in
            guard let new else { return nil }
            let failed = new == CreditShop.failedLine || new == CreditShop.restoreFailedLine
            return failed ? .error : nil
        }
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
                if let line {
                    Text(verbatim: line).font(.footnote).foregroundStyle(LumenColor.secondaryText)
                } else if let regular = item.regularPrice {
                    // A161: the ordinary price, struck through, under the name so the name keeps its row (the picture
                    // with it beside the button broke "2 000 krediter" in two). The pass says both prices in its line.
                    Text(verbatim: regular)
                        .font(.footnote)
                        .strikethrough()
                        .monospacedDigit()
                        .foregroundStyle(LumenColor.secondaryText)
                        .accessibilityHidden(true) // said with the button
                }
            }
            if !typeSize.isAccessibilitySize { Spacer(minLength: 8) }
            Button {
                Task { await shop.buy(item) }
            } label: {
                // A150 (D231): the price keeps its place while the spinner shows, so the button never changes width.
                Text(verbatim: item.displayPrice).font(.subheadline.weight(.semibold)).monospacedDigit().lineLimit(1)
                    .opacity(shop.buying == item.id ? 0 : 1)
                    .overlay { if shop.buying == item.id { ProgressView().controlSize(.small).transition(SayMotion.appear) } }
                    .animation(SayMotion.change(reduceMotion), value: shop.buying)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .tint(.accentColor)
            .disabled(shop.buying != nil)
            .accessibilityLabel((item.regularPrice.map { LaunchOfferText.spoken(title: title, price: item.displayPrice, regular: $0) }
                                    ?? String(localized: "Köp \(title) för \(item.displayPrice)"))
                                + (badge ? ", \(ShopText.bestValue.lowercased())" : "")) // Ke79
        }
    }

    @ViewBuilder
    private var inviteRow: some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(spacing: 8))
        layout {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: ShopText.inviteTitle)
                Text(verbatim: shop.invite?.monthIsFull == true ? ShopText.inviteFullLine : ShopText.inviteLine)
                    .font(.footnote).foregroundStyle(LumenColor.secondaryText)
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
            // A148: each link is a finger's size (the audit: "Hit area is too small", 16 points high before).
            if let url = ShopText.termsURL { Link(destination: url) { Self.linkLabel(Text("Villkor")) } }
            if let url = ShopText.privacyURL { Link(destination: url) { Self.linkLabel(Text("Integritet")) } }
            Button {
                Task { await shop.restore() }
            } label: {
                Self.linkLabel(Group {
                    if shop.isRestoring { ProgressView().controlSize(.small) } else { Text("Återställ köp") }
                })
            }
            .accessibilityLabel("Återställ köp")
            .buttonStyle(.pressFeedback) // A150: answers the touch on the way down
            .foregroundStyle(.tint)
            .disabled(shop.isRestoring)
        }
        .font(.footnote)
    }

    private static func linkLabel(_ content: some View) -> some View {
        content.frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
    }
}

#if DEBUG
/// The Simulator screenshots: the four products without the App Store, and a server that answers nothing.
@MainActor
final class StagedStoreFront: StoreFront {
    /// The App Store gives nothing (Toby T48).
    var isEmpty = false
    /// A161: the launch packs are in the App Store (35 % of the ordinary prices).
    var hasLaunchPacks = false
    func launchItems(suffix: String) async -> [StoreItem] {
        guard hasLaunchPacks else { return [] }
        return [StoreItem(id: StoreCatalog.entries[0].id + suffix, displayPrice: "3,50 kr", credits: 100),
                StoreItem(id: StoreCatalog.entries[1].id + suffix, displayPrice: "13,65 kr", credits: 500),
                StoreItem(id: StoreCatalog.entries[2].id + suffix, displayPrice: "38,50 kr", credits: 2000)]
    }
    func items() async -> [StoreItem] {
        if isEmpty { return [] }
        return [StoreItem(id: StoreCatalog.entries[0].id, displayPrice: "10,00 kr", credits: 100),
         StoreItem(id: StoreCatalog.entries[1].id, displayPrice: "39,00 kr", credits: 500),
         StoreItem(id: StoreCatalog.entries[2].id, displayPrice: "110,00 kr", credits: 2000),
         StoreItem(id: StoreCatalog.weekly, displayPrice: "79,00 kr", credits: nil, introPrice: hasLaunchPacks ? "27,65 kr" : nil)]
    }
    func buy(_ id: String, account: UUID?) async throws -> StoreOutcome { .cancelled }
    func finish(_ transactionID: UInt64) async {}
    func restore() async throws -> [StoreReceipt] { [] }
    func listen(_ onReceipt: @escaping @MainActor (StoreReceipt) async -> Void) {}
}

@MainActor
final class StagedPurchaseServer: PurchaseServing {
    /// An invitation has just given credits.
    var rewarded = false
    /// A161: the launch week runs.
    var offer: LaunchOffer?
    func launchOffer() async -> LaunchOffer? { offer }
    func verify(jws: String) async throws(DrillCloudError) -> PurchaseReply { PurchaseReply() }
    func attestChallenge() async throws(DrillCloudError) -> String { throw .offline("staged") }
    func welcome(keyID: String, challenge: String, attestation: String) async throws(DrillCloudError) -> PurchaseReply { PurchaseReply() }
    func inviteCode() async throws(DrillCloudError) -> InviteLink {
        var link = InviteLink(code: "k7m2xq", url: "https://earmind.vercel.app/i/k7m2xq", app_url: "earmind://invite/k7m2xq")
        if rewarded {
            link.month_rewarded = 2000
            link.month_max = 10
            link.invite_credits = 2000
            link.rewards = [InviteLink.Reward(credits: 2000, at: "2026-11-18T09:00:00.000Z")]
        }
        return link
    }
    func claimInvite(_ code: String) async throws(DrillCloudError) {}
}
#endif
