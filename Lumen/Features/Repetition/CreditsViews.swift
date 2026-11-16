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
    static func capsule(_ quota: DrillQuota) -> String { "\(DrillText.questions(quota.left)) kvar" }

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
        var rows = prices.classes.map { Row(title: className($0.name), value: number($0.questions)) }
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
        }
    }
}

/// Ke69 "Frågor kvar": the number big, what costs what, and when it is filled up.
struct CreditsSheet: View {
    let model: RepetitionModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if let quota = model.quota {
                    Section {
                        VStack(spacing: 2) {
                            Text(verbatim: "\(quota.left)")
                                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                                .monospacedDigit()
                            Text(quota.left == 1 ? "fråga kvar den här månaden" : "frågor kvar den här månaden")
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .accessibilityElement(children: .combine)
                        .listRowBackground(Color.clear)
                    }
                    let rows = CreditsText.rows(quota.prices)
                    if !rows.isEmpty {
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
            .navigationTitle("Frågor kvar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Klar") { dismiss() } } }
            .task { await model.refreshQuota() }
        }
        .presentationDetents([.medium, .large])
    }
}
