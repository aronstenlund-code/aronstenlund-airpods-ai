import SwiftUI

/// A161 (D259): the launch week said once, clearly, when the app is opened: the percent, one line about what it is
/// on, how long is left, one button to the packs and one to close. A half sheet that goes away with one tap or a
/// pull. Shown once a day at most (`CreditShop.shouldShowLaunchSheet`).
struct LaunchOfferSheet: View {
    let offer: LaunchOffer
    var covers = LaunchOfferText.Covers(packs: true, pass: false)
    /// "Se paketen": the sheet closes and the credits sheet opens.
    let onSeePacks: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        // A167: with the largest text on a small phone the half sheet cut its buttons off. It then takes the whole
        // height, and what still does not fit scrolls.
        ViewThatFits(in: .vertical) {
            content
            ScrollView { content }
        }
        .presentationDetents(typeSize.isAccessibilitySize ? [.large] : [.medium])
        .presentationDragIndicator(.visible)
        .accessibilityIdentifier("launchOffer.sheet")
    }

    private var content: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 4)
            // Kelly Ke93: the discount is said once, in the line under the title (not also as "−65 %" above it).
            Image(systemName: "tag")
                .font(.system(size: 44, weight: .regular))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            Text(verbatim: LaunchOfferText.title)
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Text(verbatim: LaunchOfferText.line(offer.percent, covers: covers))
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
                .frame(minHeight: 44) // A167: the whole of a 44-point row takes the tap
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
    }
}

/// The offer's row at the top of the packs in the credits sheet: the name, the percent, and how long is left. When
/// the week ends while the sheet is open the shop is told, and the ordinary packs stand there again.
struct LaunchOfferRow: View {
    let offer: LaunchOffer
    let shop: CreditShop
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // A167: with the largest text the name and the percent stand under each other ("Lanse-rings-rabatt" was
            // broken into three pieces beside "-65 %").
            let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
                : AnyLayout(HStackLayout(spacing: 8))
            layout {
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
