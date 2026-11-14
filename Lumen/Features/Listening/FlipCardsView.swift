import SwiftUI

/// A46 (N6): the exam's study cards to tap through, without the voice (in class, on the bus). The question on a card
/// (SYSTEM.md: `raised`, corner 20, shadow); a tap turns it; "Kunde" (blue, the one main button) or "Kunde inte"
/// (secondary). Each answer is recorded at once, so closing half way keeps what was done. At the end: how many, and
/// another round with the missed ones.
struct FlipCardsView: View {
    let plan: ExamPlan
    /// Called for each answered card (the model records it like a quiz answer).
    let onMark: (StudyCard, Bool) -> Void
    let onClose: () -> Void

    @State private var deck: FlipDeck
    /// The card's turn in degrees, 0 flat; the face changes at 90.
    @State private var turn: Double = 0
    @State private var isTurning = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(plan: ExamPlan, deck: FlipDeck, onMark: @escaping (StudyCard, Bool) -> Void, onClose: @escaping () -> Void) {
        self.plan = plan
        self.onMark = onMark
        self.onClose = onClose
        _deck = State(initialValue: deck)
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar.padding(.horizontal, 20)
            // A long answer at the largest text size scrolls inside; the buttons stay at the bottom.
            ScrollView {
                if let card = deck.current {
                    face(card)
                        .id(card.id)
                        .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.96)), removal: .opacity))
                        .padding(.vertical, 24)
                } else {
                    done.padding(.vertical, 24)
                }
            }
            // The card's shadow needs the screen edge's room, so the edge is inside the scroll view.
            .contentMargins(.horizontal, 20, for: .scrollContent)
            .scrollBounceBehavior(.basedOnSize)
            Group { if deck.isFinished { doneButtons } else { buttons } }
                .padding(.horizontal, 20)
        }
        .padding(.top, 12)
        .padding(.bottom, 16)
        .lumenScreen()
        .sensoryFeedback(.impact(weight: .light), trigger: deck.index)
    }

    // MARK: Parts

    private var topBar: some View {
        VStack(spacing: 12) {
            HStack {
                IconButton(systemName: "xmark", label: "Stäng", action: onClose)
                Spacer()
                VStack(spacing: 2) {
                    Text("Vändkort").font(LumenFont.text(17, .semibold, relativeTo: .headline))
                    Text(plan.name).font(LumenFont.text(13, relativeTo: .footnote)).foregroundStyle(LumenColor.muted)
                }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)
                Spacer()
                Text(deck.isFinished ? "" : deck.position)
                    .font(LumenFont.text(15, .semibold, relativeTo: .subheadline))
                    .foregroundStyle(LumenColor.muted)
                    .monospacedDigit()
                    .frame(width: 44, alignment: .trailing)
                    .accessibilityLabel(deck.isFinished ? "" : "Kort \(deck.position)")
            }
            ProgressView(value: Double(deck.index), total: Double(max(deck.cards.count, 1)))
                .tint(LumenColor.blue)
                .accessibilityHidden(true)
        }
    }

    private func face(_ card: StudyCard) -> some View {
        Button(action: flip) {
            VStack(alignment: .leading, spacing: 14) {
                SectionLabel(deck.isFlipped ? "Svar" : "Fråga")
                if deck.isFlipped {
                    Text(card.answer)
                        .font(LumenFont.text(20, relativeTo: .title3))
                        .lineSpacing(6)
                } else {
                    Text(card.question)
                        .font(LumenFont.text(24, .semibold, relativeTo: .title2))
                        .lineSpacing(4)
                }
                Spacer(minLength: 0)
                Text(deck.isFlipped ? "Tryck för att se frågan" : "Tryck för att vända")
                    .font(LumenFont.text(13, relativeTo: .footnote))
                    .foregroundStyle(LumenColor.muted)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .multilineTextAlignment(.leading)
            .foregroundStyle(LumenColor.ink)
            .padding(24)
            .frame(maxWidth: .infinity, minHeight: 320, alignment: .topLeading)
            .gridPaper()
            .contentShape(RoundedRectangle(cornerRadius: LumenCard.radius))
        }
        .buttonStyle(.plain)
        .rotation3DEffect(.degrees(turn), axis: (x: 0, y: 1, z: 0), perspective: 0.4)
        .accessibilityLabel(deck.isFlipped ? "Svar: \(card.answer)" : "Fråga: \(card.question)")
        .accessibilityHint(deck.isFlipped ? "Visar frågan igen" : "Vänder kortet och visar svaret")
    }

    private var buttons: some View {
        Group {
            if deck.isFlipped {
                HStack(spacing: 12) {
                    Button("Kunde inte") { mark(false) }
                        .buttonStyle(SystemButton(kind: .secondary))
                    Button("Kunde") { mark(true) }
                        .buttonStyle(SystemButton())
                }
            } else {
                Button("Vänd kortet", action: flip)
                    .buttonStyle(SystemButton())
            }
        }
        .disabled(isTurning)
    }

    private var done: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Klart")
            Text(deck.summary)
                .font(LumenFont.text(28, .bold, relativeTo: .title))
            Text(deck.missed.isEmpty
                 ? "Alla satt. Det räknas in i din plan."
                 : "Det räknas in i din plan. De du inte kunde kommer tidigare nästa gång.")
                .font(LumenFont.text(17))
                .foregroundStyle(LumenColor.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .gridPaper()
    }

    private var doneButtons: some View {
        VStack(spacing: 10) {
            if let again = deck.againWithMissed() {
                Button("Öva på \(again.cards.count == 1 ? "det" : "de \(again.cards.count)") igen") {
                    withAnimation(.easeOut(duration: 0.2)) { deck = again }
                }
                .buttonStyle(SystemButton())
                Button("Klar", action: onClose)
                    .buttonStyle(SystemButton(kind: .secondary))
            } else {
                Button("Klar", action: onClose)
                    .buttonStyle(SystemButton())
            }
        }
    }

    // MARK: Actions

    /// Half a turn, the face changes, the other half (an ease-in then an ease-out: one smooth turn). Without
    /// motion: the face changes in place.
    private func flip() {
        guard !isTurning else { return }
        guard !reduceMotion else {
            withAnimation(.easeOut(duration: 0.15)) { deck.flip() }
            return
        }
        isTurning = true
        let direction: Double = deck.isFlipped ? -1 : 1
        withAnimation(.easeIn(duration: 0.13)) {
            turn = 90 * direction
        } completion: {
            deck.flip()
            turn = -90 * direction
            withAnimation(.easeOut(duration: 0.17)) {
                turn = 0
            } completion: {
                isTurning = false
            }
        }
    }

    private func mark(_ knew: Bool) {
        guard !isTurning else { return }
        var next = deck
        guard let card = next.mark(knew: knew) else { return }
        onMark(card, knew)
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.22)) { deck = next }
    }
}
