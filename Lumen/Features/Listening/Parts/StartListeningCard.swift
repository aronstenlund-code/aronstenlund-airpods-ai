import SwiftUI

/// Deangelo 2026-11-27 05:52: Start's main button – listening, what one does most – with one line under it that says how
/// things stand: the AirPods, the credits, the phone's own model. The rest of Start is smaller. Placed by Start
/// (Angela Fable's `RepetitionHomeSection`); this view holds no state of its own.
struct StartListeningCard: View {
    let model: ListeningModel
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Button(action: onStart) {
                FilledButtonLabel {
                    Label(model.isActiveSession ? String(localized: "Tillbaka till EarMind") : String(localized: "Starta EarMind"),
                          systemImage: "waveform")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityIdentifier("start.listen")
            Text(verbatim: model.startStatus.line)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("start.status")
        }
        .task { model.refreshStartStatus() }
    }
}
