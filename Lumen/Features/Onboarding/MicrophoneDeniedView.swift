import SwiftUI

/// A18 (Kelly Ke10, T3 finding 3): with the microphone off, the whole screen is about fixing it: three short steps,
/// "Öppna Inställningar" as the one blue button, "Hoppa över" quiet. Red is not needed: nothing is broken, a switch
/// is off.
struct MicrophoneDeniedView: View {
    let onSkip: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("EarMind hör dig inte")
                        .font(LumenFont.text(36, .bold, relativeTo: .largeTitle))
                        .accessibilityAddTraits(.isHeader)
                    Text("Mikrofonen är avstängd för EarMind. Slå på den, så kan du fråga direkt.")
                        .font(LumenFont.text(17))
                        .foregroundStyle(LumenColor.muted)
                }
                VStack(alignment: .leading, spacing: 12) {
                    step(1, "Tryck Öppna Inställningar")
                    step(2, "Slå på Mikrofon")
                    step(3, "Kom tillbaka hit")
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(LumenColor.chip, in: RoundedRectangle(cornerRadius: 10))
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 6) {
                Button("Öppna Inställningar") { ErrorCard.openSettings() }
                    .buttonStyle(LumenButtonStyle())
                Button("Hoppa över", action: onSkip)
                    .font(LumenFont.text(17, .semibold))
                    .foregroundStyle(LumenColor.muted)
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
            .background(LumenColor.background)
        }
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("\(number).").font(LumenFont.text(16, .bold))
            Text(text).font(LumenFont.text(16))
        }
        .accessibilityElement(children: .combine)
    }
}
