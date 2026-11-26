import AVFAudio
import SwiftUI
import UIKit

// A165 (D263): "Spela in själv – helt gratis", the views, after Kelly's Ke89 (`docs/design/spela-in-sjalv.md`):
// one way in on Start, one screen for a deck, the same player as the quizzes. The system's own parts (D160), no new
// colours, and no symbol of its own but the system's `mic`. The core is Angela Schrute's (A164, `OwnDeckModel`).

/// The tinted label "Helt gratis", in the style of "Bäst värde" in the shop. A label, not a button.
struct OwnFreeCapsule: View {
    var body: some View {
        Text(verbatim: OwnDeckText.free)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.accentColor.opacity(0.15), in: Capsule())
            .foregroundStyle(.tint)
            .lineLimit(1)
            .fixedSize()
    }
}

/// The way in on Start (Ke89 §1): `mic` · Spela in själv · the capsule Helt gratis · ›, and one line under it.
struct OwnDeckEntryRow: View {
    let action: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "mic")
                    .foregroundStyle(.tint)
                    .frame(width: 24)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    // With the largest text the capsule stands under the name instead of pushing it into three rows.
                    let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
                        : AnyLayout(HStackLayout(spacing: 8))
                    layout {
                        Text(verbatim: OwnDeckText.title).foregroundStyle(Color.primary)
                        OwnFreeCapsule()
                    }
                    Text(verbatim: OwnDeckText.entryLine).font(.subheadline).foregroundStyle(LumenColor.secondaryText)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color(.tertiaryLabel))
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(OwnDeckText.entry)
        .accessibilityHint(OwnDeckText.entryLine)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("home.ownDecks")
    }
}

/// The screen for a deck (Ke89 §2): the name, a card per question with Fråga and Svar and under each its
/// recording (Spela in, or the time and Spela in igen), Lägg till fråga, and Öva as the one filled button with
/// "Helt gratis. Ljudet stannar på din telefon." under it. Everything is saved as it is written; Klar closes.
struct OwnDeckView: View {
    let decks: OwnDeckModel
    let deckID: UUID
    /// Öva: the screen closes and the deck plays in the same player as a quiz.
    let onPractise: () -> Void
    @State private var name: String
    @FocusState private var focus: Field?
    @Environment(\.dismiss) private var dismiss

    enum Field: Hashable {
        case name
        case text(UUID, OwnPart)
    }

    init(decks: OwnDeckModel, deckID: UUID, onPractise: @escaping () -> Void) {
        self.decks = decks
        self.deckID = deckID
        self.onPractise = onPractise
        _name = State(initialValue: OwnDeckTidy.shownName(decks.deck(deckID)?.title ?? ""))
    }

    private var deck: OwnDeck? { decks.deck(deckID) }

    /// iOS has not asked about the microphone yet: one line says what it is used for before it does.
    private var microphoneNotAskedYet: Bool { AVAudioApplication.shared.recordPermission == .undetermined }

    var body: some View {
        let cards = deck?.cards ?? []
        return List {
            Section {
                TextField(OwnDeckText.namePrompt, text: $name)
                    .focused($focus, equals: .name)
                    .submitLabel(.done)
                    .accessibilityLabel(OwnDeckText.name)
                    .accessibilityIdentifier("ownDeck.name")
            } header: {
                Text(verbatim: OwnDeckText.name)
            }
            if let problem = decks.problem {
                Section { Text(verbatim: problem) }
            }
            ForEach(cards) { card in
                Section {
                    part(.question, of: card)
                    part(.answer, of: card)
                }
            }
            Section {
                Button {
                    if let card = decks.addCard(to: deckID) { focus = .text(card.id, .question) }
                } label: {
                    Label(OwnDeckText.addCard, systemImage: "plus").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.accentColor)
                .controlSize(.large)
                .disabled(cards.count >= OwnDeck.cardLimit)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .accessibilityIdentifier("ownDeck.addCard")
            } footer: {
                if microphoneNotAskedYet { Text(verbatim: OwnDeckText.micNote).foregroundStyle(LumenColor.secondaryText) }
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(.compact)
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(OwnDeckText.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(String(localized: "Klar")) { dismiss() }.accessibilityIdentifier("ownDeck.done")
            }
        }
        .safeAreaInset(edge: .bottom) {
            MainActionBar(title: OwnDeckText.practise, systemImage: "play.fill", note: OwnDeckText.staysOnPhone,
                          isDisabled: !(deck.map { decks.canStart($0) } ?? false) || decks.recording != nil) {
                focus = nil
                onPractise()
            }
            .accessibilityIdentifier("ownDeck.practise")
        }
        .onChange(of: name) { _, new in decks.rename(deckID, to: OwnDeckTidy.title(forName: new)) }
        // A pull does not throw away a recording that is being made.
        .interactiveDismissDisabled(decks.recording != nil)
        .onDisappear {
            decks.stopRecording()
            decks.stopPreview()
        }
        // What the microphone does is said as well as shown.
        .onChange(of: decks.recording) { old, new in
            if new != nil {
                AccessibilityNotification.Announcement(String(localized: "Spelar in")).post()
            } else if old != nil {
                AccessibilityNotification.Announcement(String(localized: "Inspelat")).post()
            }
        }
    }

    /// One part of a card: its text, and under it its recording. A swipe to the left takes the card away.
    @ViewBuilder
    private func part(_ part: OwnPart, of card: OwnCard) -> some View {
        TextField(OwnDeckText.field(part), text: Binding(
            get: { decks.deck(deckID)?.cards.first { $0.id == card.id }?.text(part) ?? "" },
            set: { decks.setText(String($0.prefix(OwnCard.textLimit)), for: part, card: card.id, in: deckID) }), axis: .vertical)
            .lineLimit(1...5)
            .focused($focus, equals: .text(card.id, part))
            .accessibilityIdentifier(part == .question ? "ownCard.question" : "ownCard.answer")
            .swipeActions(edge: .trailing) { deleteButton(card) }
        OwnTakeRow(decks: decks, deckID: deckID, card: card, part: part) { focus = nil }
            .swipeActions(edge: .trailing) { deleteButton(card) }
    }

    private func deleteButton(_ card: OwnCard) -> some View {
        Button(OwnDeckText.delete, role: .destructive) {
            if decks.recording?.cardID == card.id { decks.cancelRecording() }
            decks.deleteCard(card.id, in: deckID)
        }
    }
}

/// One recording's row (Ke89 §2): ● Spela in and "Inte inspelad"; while it records the red dot, the time counting
/// up and Stoppa (one more tap); then ▶ with the time, and ↻ Spela in igen. No confirmation.
struct OwnTakeRow: View {
    let decks: OwnDeckModel
    let deckID: UUID
    let card: OwnCard
    let part: OwnPart
    /// Before the microphone starts (the keyboard goes down, so its clicks are not recorded).
    var beforeRecording: () -> Void = {}

    private var target: OwnDeckModel.Target { OwnDeckModel.Target(deckID: deckID, cardID: card.id, part: part) }
    private var identifier: String { part == .question ? "ownCard.recordQuestion" : "ownCard.recordAnswer" }

    var body: some View {
        if decks.recording == target {
            Button { decks.stopRecording() } label: {
                HStack(spacing: 10) {
                    Circle().fill(Color.red).frame(width: 12, height: 12) // iOS's sign for recording
                    Text(verbatim: OwnDeckText.clock(decks.elapsed)).monospacedDigit().foregroundStyle(Color.primary)
                    LevelMeter(levelDBFS: decks.levelDBFS)
                    Spacer(minLength: 8)
                    Text(verbatim: OwnDeckText.stop).fontWeight(.semibold)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(OwnDeckText.stopLabel(decks.elapsed))
            .accessibilityAddTraits(.updatesFrequently)
            .accessibilityIdentifier(identifier + ".stop")
        } else if let take = card.take(part) {
            let isPlaying = decks.previewing == target
            // Two buttons in one row: each takes its own taps.
            HStack(spacing: 12) {
                Button {
                    if isPlaying { decks.stopPreview() } else { Task { await decks.preview(part, card: card.id, in: deckID) } }
                } label: {
                    Label(OwnDeckText.clock(take.seconds), systemImage: isPlaying ? "stop.fill" : "play.fill").monospacedDigit()
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(isPlaying ? OwnDeckText.stop : OwnDeckText.playLabel(part, seconds: take.seconds))
                .accessibilityIdentifier(identifier + ".play")
                Spacer(minLength: 8)
                Button { start() } label: {
                    Label(OwnDeckText.recordAgain, systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.borderless)
                .disabled(decks.recording != nil)
                .accessibilityLabel(OwnDeckText.recordAgainLabel(part))
                .accessibilityIdentifier(identifier)
            }
        } else {
            HStack(spacing: 12) {
                Button { start() } label: {
                    Label {
                        Text(verbatim: OwnDeckText.record)
                    } icon: {
                        Image(systemName: "circle.fill").foregroundStyle(decks.recording == nil ? Color.red : Color(.tertiaryLabel))
                    }
                }
                .buttonStyle(.borderless)
                .disabled(decks.recording != nil)
                .accessibilityLabel(OwnDeckText.recordLabel(part))
                .accessibilityIdentifier(identifier)
                Spacer(minLength: 8)
                Text(verbatim: OwnDeckText.notRecorded).font(.footnote).foregroundStyle(LumenColor.secondaryText)
            }
        }
    }

    private func start() {
        beforeRecording()
        decks.stopPreview()
        Task { await decks.record(part, card: card.id, in: deckID) }
    }
}

// MARK: The sheet when the credits are out or the model is down

/// Ke89 §4: "Slut på krediter? Spela in dina egna frågor och svar – helt gratis." A half sheet with one filled
/// button to "Spela in själv" and Inte nu; it goes away with a tap outside or a pull. No sales tone, no prices.
struct OwnDeckOfferSheet: View {
    let reason: OwnDeckOffer.Reason
    let onOpen: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 4)
            Image(systemName: "mic")
                .font(.system(size: 44, weight: .regular))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            Text(verbatim: OwnDeckText.offerTitle(reason))
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Text(verbatim: OwnDeckText.offerLine)
                .multilineTextAlignment(.center)
                .foregroundStyle(LumenColor.secondaryText)
            Spacer(minLength: 4)
            Button(action: onOpen) {
                FilledButtonLabel {
                    Text(verbatim: OwnDeckText.title).font(.headline).frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityIdentifier("ownDecks.offer.open")
            Button(OwnDeckText.notNow, action: onClose)
                .padding(.vertical, 6)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .accessibilityIdentifier("ownDecks.offer")
    }
}

/// The deck whose screen is up on Start.
struct OwnDeckSheet: Identifiable {
    let id: UUID
}

/// What Start shows for "Spela in själv": the screen of a deck as a sheet, and the sheet that points here when the
/// server says no. When the deck's screen has closed, what was never filled in goes, and Öva starts the deck in the
/// same player as a quiz (a cover cannot come up while the sheet is still there).
struct OwnDeckOnStart: ViewModifier {
    let model: RepetitionModel
    @Binding var shown: OwnDeckSheet?
    /// Nothing else of Start's own is over it.
    let isFront: Bool
    /// The sheet about the free way is down (its button may have been pressed).
    let onOfferClosed: () -> Void
    /// The deck whose screen is closing (the sheet's item is already nil when its onDismiss runs).
    @State private var closing: UUID?
    @State private var practises: UUID?

    func body(content: Content) -> some View {
        content
            .sheet(item: $shown, onDismiss: closed) { item in
                if let decks = model.ownDecks {
                    NavigationStack {
                        OwnDeckView(decks: decks, deckID: item.id) {
                            practises = item.id
                            shown = nil
                        }
                    }
                }
            }
            .onChange(of: shown?.id) { old, new in closing = new ?? old }
            .modifier(OwnDeckOfferPresenter(model: model, isFront: isFront && shown == nil, onDismiss: onOfferClosed))
    }

    private func closed() {
        guard let decks = model.ownDecks, let id = closing else { return }
        let kept = OwnDeckTidy.afterEditing(id, in: decks)
        if practises == id, kept, let deck = decks.deck(id), decks.canStart(deck) {
            Task { await model.start(own: deck) }
        }
        practises = nil
    }
}

/// Shows the sheet over the view that is in front when the server says no (Start, or Nytt prov's sheet).
struct OwnDeckOfferPresenter: ViewModifier {
    let model: RepetitionModel
    /// Nothing else of this view's own is over it.
    var isFront = true
    /// The sheet is down (its button may have been pressed: `OwnDeckOffer.opensDecks`).
    var onDismiss: () -> Void = {}

    func body(content: Content) -> some View {
        let offer = model.ownOffer
        content.sheet(isPresented: Binding(get: { isFront && offer.showing != nil }, set: { if !$0 { offer.close() } }),
                      onDismiss: onDismiss) {
            if let reason = offer.showing {
                OwnDeckOfferSheet(reason: reason, onOpen: { offer.open() }, onClose: { offer.close() })
            }
        }
    }
}
