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
            Button(role: .destructive) {
                asks = true
            } label: {
                HStack {
                    Text("Radera konto")
                    Spacer()
                    if model.isDeleting { ProgressView() }
                }
            }
            .disabled(model.isDeleting)
            .alert(AccountDeletionModel.question, isPresented: $asks) {
                Button("Radera konto", role: .destructive) { Task { await model.delete() } }
                Button("Avbryt", role: .cancel) {}
            } message: {
                Text(verbatim: AccountDeletionModel.questionDetail)
            }
            Button("Hantera prenumerationer") { managesSubscriptions = true }
                .manageSubscriptionsSheet(isPresented: $managesSubscriptions)
        } header: {
            Text("Konto")
        } footer: {
            VStack(alignment: .leading, spacing: 6) {
                if model.isDeleting {
                    Text("Raderar kontot …")
                } else if let line = model.failureLine {
                    Text(verbatim: line).foregroundStyle(LumenColor.ink)
                }
                Text(verbatim: AccountDeletionModel.passLine)
            }
        }
    }
}
