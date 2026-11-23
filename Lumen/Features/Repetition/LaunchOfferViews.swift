import SwiftUI

/// A161 (D259): the launch week said once, clearly, when the app is opened: the percent, one line about what it is
/// on, how long is left, one button to the packs and one to close. A half sheet that goes away with one tap or a
/// pull. Shown once a day at most (`CreditShop.shouldShowLaunchSheet`).
struct LaunchOfferSheet: View {
    let offer: LaunchOffer
    /// "Se paketen": the sheet closes and the credits sheet opens.
    let onSeePacks: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 4)
            Text(verbatim: LaunchOfferText.badge(offer.percent))
                .font(.system(size: 60, weight: .bold, design: .rounded))
                .foregroundStyle(.tint)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text(verbatim: LaunchOfferText.title)
                .font(.title2.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            Text(verbatim: LaunchOfferText.line(offer.percent))
                .multilineTextAlignment(.center)
                .foregroundStyle(LumenColor.secondaryText)
            // The minutes move; the sheet is read again every half minute, not every second.
            TimelineView(.periodic(from: .now, by: 30)) { context in
                Text(verbatim: LaunchOfferText.left(offer, now: context.date))
                    .font(.subheadline.weight(.medium))
                    .monospacedDigit()
            }
            Spacer(minLength: 4)
            Button {
                dismiss()
                onSeePacks()
            } label: {
                FilledButtonLabel {
                    Text(verbatim: LaunchOfferText.seePacks).font(.headline).frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            Button(LaunchOfferText.notNow) { dismiss() }
                .padding(.vertical, 6)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .accessibilityIdentifier("launchOffer.sheet")
    }
}

/// The offer's row at the top of the packs in the credits sheet: the name, the percent, and how long is left. When
/// the week ends while the sheet is open the shop is told, and the ordinary packs stand there again.
struct LaunchOfferRow: View {
    let offer: LaunchOffer
    let shop: CreditShop

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Text(verbatim: LaunchOfferText.title).font(.subheadline.weight(.semibold))
                Text(verbatim: LaunchOfferText.badge(offer.percent))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.tint)
            }
            TimelineView(.periodic(from: .now, by: 30)) { context in
                Text(verbatim: LaunchOfferText.left(offer, now: context.date))
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(LumenColor.secondaryText)
            }
        }
        .accessibilityElement(children: .combine)
        .task(id: offer.endsAt) {
            let left = offer.endsAt.timeIntervalSinceNow
            if left > 0 { try? await Task.sleep(for: .seconds(left)) }
            if !Task.isCancelled { shop.launchWeekHasEnded() }
        }
    }
}
