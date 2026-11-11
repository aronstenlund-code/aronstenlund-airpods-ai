import SwiftUI

/// A76 (Kelly Ke45 `ke45-bekrafta.png`, Ke46 T2): before the test mode is switched on, what it means: all the audio,
/// other people's voices and the background too, goes to us and is kept 14 days. A test account the server switched
/// on sees it once, with "Okej" only.
struct TestModeSheet: View {
    /// Switched on by the server (K43): only "Okej".
    var isNotice = false
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(isNotice ? "Testläget är på" : "Slå på testläget?")
                    .font(LumenFont.text(26, .bold, relativeTo: .title))
                    .accessibilityAddTraits(.isHeader)
                VStack(alignment: .leading, spacing: 14) {
                    point("waveform", "Allt ljud medan Earmind lyssnar skickas till oss, också andras röster och bakgrundsljud. Det hjälper oss att höra om frågan uppfattades rätt.")
                    point("calendar", "Ljudet sparas i 14 dagar och raderas sedan.")
                    point("record.circle", "Så länge ljud skickas står det ”Testläge · ljud skickas” där Earmind visar att den lyssnar.")
                    point("person.2", "Slå bara på det där de som hörs vet om det.")
                    point("switch.2", "Du stänger av det när du vill i Inställningar › Testläge.")
                }
                VStack(spacing: 10) {
                    Button(action: onConfirm) {
                        Text(isNotice ? "Okej" : "Slå på testläget")
                            .font(LumenFont.text(17, .semibold))
                            .foregroundStyle(LumenColor.onTest)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(LumenColor.test, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    if !isNotice {
                        Button("Inte nu", action: onCancel)
                            .font(LumenFont.text(17, .semibold))
                            .foregroundStyle(LumenColor.muted)
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                }
                .padding(.top, 6)
            }
            .padding(24)
        }
        .background(LumenColor.background)
        .presentationDetents([.large])
        .interactiveDismissDisabled(isNotice)
    }

    private func point(_ symbol: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(LumenColor.test)
                .frame(width: 24)
                .accessibilityHidden(true)
            Text(text)
                .font(LumenFont.text(17, relativeTo: .body))
                .foregroundStyle(LumenColor.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
