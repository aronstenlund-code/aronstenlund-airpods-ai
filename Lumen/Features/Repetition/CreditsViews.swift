import SwiftUI

// A117 (D205, Kelly Ke69 `sag/krediter.png`): the month's questions, visible. A small capsule on Start ("312 frågor
// kvar") opens a sheet with the number, what costs what and when it is filled up. The numbers and the price table
// come from the server (`/drill quota`, Kevin's K82); nothing is hard-coded here. That more would be used than is
// left is said before the action (Nytt prov, Starta prov, Säg i AirPods), never after.

/// The sheet's rows, made from the server's table.
@MainActor
enum CreditsText {
    struct Row: Equatable, Identifiable {
        var title: String
        var value: String
        var id: String { title }
    }

    /// "312 frågor kvar".
    static func capsule(_ quota: DrillQuota) -> String {
        if quota.isUnlimited { return "Obegränsat" } // A133 (D216): the owner's account
        if quota.hasWeeklyCard { return "Veckokort" } // A139 (D222, K94): a subscription
        return quota.isCredits ? CreditText.capsule(quota.left) : "\(DrillText.questions(quota.left)) kvar" // A131 (D213)
    }

    /// The words under the sheet's number. With purchases the credits are not only the month's (Ke73: "krediter kvar").
    static func leftLine(_ quota: DrillQuota, withShop: Bool) -> String {
        if quota.isCredits {
            let noun = quota.left == 1 ? "kredit kvar" : "krediter kvar"
            return withShop ? noun : "\(noun) den här månaden"
        }
        return quota.left == 1 ? "fråga kvar den här månaden" : "frågor kvar den här månaden"
    }

    /// "1", "1,5", "2".
    static func number(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(format: "%.1f", value).replacingOccurrences(of: ".", with: ",")
    }

    static func className(_ name: String) -> String {
        switch name {
        case "normal": "Vanlig fråga"
        case "longer": "Lite längre fråga"
        case "too_long": "Mycket lång fråga"
        default: name
        }
    }

    /// What costs what: the classes the server names, reading aloud per so many characters, and repeating for nothing.
    static func rows(_ prices: DrillPrices?) -> [Row] {
        guard let prices else { return [] }
        // Kelly (review of A117): while every length costs the same, one row says it; the three come back when the
        // server's numbers differ.
        var rows: [Row]
        if let first = prices.classes.first, prices.classes.allSatisfy({ $0.questions == first.questions }) {
            rows = [Row(title: "En fråga", value: number(first.questions))]
        } else {
            rows = prices.classes.map { Row(title: className($0.name), value: number($0.questions)) }
        }
        if let read = prices.read {
            rows.append(Row(title: "Läs upp eller Säg i AirPods", value: "1 per \(read.chars_per_question) tecken"))
        }
        rows.append(Row(title: "Upprepa samma text", value: "0"))
        return rows
    }

    /// "Fylls på den 1 december." from the server's "2026-12-01"; without a date, the first of next month.
    static func refill(_ resets: String?) -> String {
        let parts = (resets ?? "").split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, (1...12).contains(parts[1]), (1...31).contains(parts[2]) else {
            return "Fylls på den 1 \(ChatGPTImportView.nextMonth())."
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "sv_SE")
        return "Fylls på den \(parts[2]) \(calendar.monthSymbols[parts[1] - 1])."
    }
}

/// The capsule on Start. Shown once the month's quota is known.
struct CreditsCapsule: View {
    let model: RepetitionModel
    @State private var showsSheet = false

    var body: some View {
        if let quota = model.quota {
            Button {
                showsSheet = true
            } label: {
                Text(verbatim: CreditsText.capsule(quota)).font(.subheadline).monospacedDigit()
            }
            .accessibilityHint("Visar vad som kostar vad")
            .sheet(isPresented: $showsSheet) { CreditsSheet(model: model) }
            // A141 (D224, K98): the welcome credits are asked for once per installation, when Start is first shown.
            .task { await model.shop?.claimWelcome() }
        }
    }
}

/// Ke69 "Frågor kvar": the number big, what costs what, and when it is filled up.
struct CreditsSheet: View {
    let model: RepetitionModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        NavigationStack {
            List {
                if let quota = model.quota {
                    Section {
                        VStack(spacing: 2) {
                            // A134 (Ke73 §3): with the weekly card the sheet says so, and how much of the week is left.
                            let weekly = quota.hasWeeklyCard && !quota.isUnlimited ? quota.subscription : nil
                            Text(verbatim: quota.isUnlimited ? "Obegränsat" : weekly != nil ? ShopText.weeklyTitle
                                 : quota.isCredits ? CreditText.number(quota.left) : "\(quota.left)")
                                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                                .monospacedDigit()
                            Text(verbatim: quota.isUnlimited ? "Det här kontot har ingen gräns"
                                 : weekly.map(ShopText.weekLine)
                                 ?? (quota.isOnlyWelcome ? ShopText.welcomeLine : CreditsText.leftLine(quota, withShop: model.shop != nil)))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 8)
                        .accessibilityElement(children: .combine)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                    }
                    // A134 (D218), A141 (D224): the packs, the weekly card and the invitation.
                    if quota.isCredits, !quota.isUnlimited, let shop = model.shop {
                        ShopSections(model: model, shop: shop, quota: quota)
                    }
                    let rows = CreditsText.rows(quota.prices)
                    if quota.isCredits {
                        // A131 (D213, Kelly Ke71): how it is counted, in credits.
                        Section {
                            ForEach(CreditText.rows, id: \.title) { row in
                                LabeledContent(row.title, value: row.value)
                            }
                        } header: {
                            Text("Så räknas det")
                        } footer: {
                            Text(verbatim: CreditText.footnote(limit: quota.limit, resetsDay: quota.resetsDay))
                        }
                    } else if !rows.isEmpty {
                        Section {
                            ForEach(rows) { row in
                                LabeledContent(row.title, value: row.value)
                            }
                        } header: {
                            Text("Vad det kostar")
                        } footer: {
                            Text(verbatim: "\(CreditsText.refill(quota.resets)) Prov som andra har delat eller publicerat kostar inget.")
                        }
                    } else {
                        Section {
                            Text(verbatim: "\(CreditsText.refill(quota.resets)) Prov som andra har delat eller publicerat kostar inget.")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .contentMargins(.top, 8, for: .scrollContent) // Kelly (review of A134): the number stands right under the title
            .navigationTitle(model.quota?.isCredits == true ? "Krediter" : "Frågor kvar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Klar") { dismiss() } } }
            .task { await model.refreshQuota() }
            .task { await model.shop?.load() }
        }
        // A134: with the purchase part the sheet is a whole page.
        .presentationDetents(typeSize.isAccessibilitySize || (model.shop != nil && model.quota?.isCredits == true && model.quota?.isUnlimited != true)
                             ? [.large] : [.fraction(model.quota?.isCredits == true ? 0.72 : 0.64), .large]) // Kelly K3: half the height cut the footnote; the largest text needs it all
    }
}
