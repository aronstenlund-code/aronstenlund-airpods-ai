import StoreKit
import SwiftUI

/// A145 (Ke78, Apple 5.1.1(v), K101): Inställningar › Konto › Radera konto. A question that can be cancelled comes
/// first; only "Radera konto" in it deletes. The weekly pass is not ended by the deletion, so the way to cancel it is
/// shown next to the button.
struct AccountSection: View {
    let model: AccountDeletionModel
    @State private var asks = false
    @State private var managesSubscriptions = false

    var body: some View {
        Section {
            if model.isDeleting {
                // A148: while it deletes the row says so in readable text; a greyed button did not pass the contrast.
                HStack {
                    Text("Raderar kontot …").foregroundStyle(LumenColor.ink)
                    Spacer()
                    ProgressView()
                }
                .accessibilityElement(children: .combine)
            } else {
                Button(role: .destructive) { asks = true } label: {
                    Text("Radera konto").foregroundStyle(LumenColor.redText) // A148: the system's red is 3.6:1
                }
            }
            Button("Hantera prenumerationer") { managesSubscriptions = true }
                .manageSubscriptionsSheet(isPresented: $managesSubscriptions)
                .alert(AccountDeletionModel.question, isPresented: $asks) {
                    Button("Radera konto", role: .destructive) { Task { await model.delete() } }
                    Button("Avbryt", role: .cancel) {}
                } message: {
                    Text(verbatim: AccountDeletionModel.questionDetail)
                }
        } header: {
            Text("Konto").foregroundStyle(LumenColor.secondaryText)
        } footer: {
            VStack(alignment: .leading, spacing: 6) {
                if let line = model.failureLine {
                    Text(verbatim: line).foregroundStyle(LumenColor.ink)
                }
                // A148: VoiceOver reads the path with commas, not the arrow signs.
                Text(verbatim: AccountDeletionModel.passLine)
                    .foregroundStyle(LumenColor.secondaryText)
                    .accessibilityLabel(AccountDeletionModel.passLine.replacingOccurrences(of: " › ", with: ", "))
            }
        }
    }
}
