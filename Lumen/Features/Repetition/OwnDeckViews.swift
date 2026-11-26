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
                // A167: the name wraps instead of being cut ("Biologi kapit…" with the largest text on an SE).
                TextField(OwnDeckText.namePrompt, text: $name, axis: .vertical)
                    .lineLimit(1...3)
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
            ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                Section {
                    part(.question, of: card, number: index + 1)
                    part(.answer, of: card, number: index + 1)
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
        .onChange(of: name) { _, new in
            // The field wraps, so Return would make a new line: it ends the name instead (a name is one line).
            if new.contains("\n") {
                name = new.replacingOccurrences(of: "\n", with: "")
                focus = nil
                return
            }
            decks.rename(deckID, to: OwnDeckTidy.title(forName: new))
        }
        // A pull does not throw away a recording that is being made.
        .interactiveDismissDisabled(decks.recording != nil)
        .onDisappear {
            decks.stopRecording()
            decks.stopPreview()
        }
        // What the microphone does is said as well as shown.
        .onChange(of: decks.recording) { old, new in
            // A167: what is being read in is said, and when it is done ("Spelar in frågan", "Klar, frågan är inspelad").
            if let new {
                AccessibilityNotification.Announcement(OwnDeckText.nowRecording(new.part)).post()
            } else if let old {
                AccessibilityNotification.Announcement(OwnDeckText.doneRecording(old.part)).post()
            }
        }
    }

    /// One part of a card: its text, and under it its recording. A swipe to the left takes the card away.
    @ViewBuilder
    private func part(_ part: OwnPart, of card: OwnCard, number: Int) -> some View {
        TextField(OwnDeckText.field(part), text: Binding(
            get: { decks.deck(deckID)?.cards.first { $0.id == card.id }?.text(part) ?? "" },
            set: { decks.setText(String($0.prefix(OwnCard.textLimit)), for: part, card: card.id, in: deckID) }), axis: .vertical)
            .lineLimit(1...5)
            .focused($focus, equals: .text(card.id, part))
            // A167: with several cards "Fråga" alone does not say which; VoiceOver hears "Fråga 2", "Svar 2".
            .accessibilityLabel(OwnDeckText.field(part, number: number))
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
    /// Another part is being read in: this row's buttons wait, and look it (grey, not half blue).
    private var waits: Bool { decks.recording != nil }
    private var ink: AnyShapeStyle { waits ? AnyShapeStyle(Color(.tertiaryLabel)) : AnyShapeStyle(.tint) }
    @Environment(\.dynamicTypeSize) private var typeSize
    /// A167: with the accessibility text sizes the row's two things stand under each other (side by side they were
    /// cut on a small phone).
    private var isLarge: Bool { typeSize.isAccessibilitySize }
    private var row: AnyLayout {
        isLarge ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12)) : AnyLayout(HStackLayout(spacing: 12))
    }

    var body: some View {
        // The line above the row begins at the row's edge, as above the text (a row with a symbol sets it in).
        content.alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
    }

    @ViewBuilder
    private var content: some View {
        if decks.recording == target {
            Button { decks.stopRecording() } label: {
                row {
                    HStack(spacing: 10) {
                        Circle().fill(Color.red).frame(width: 12, height: 12) // iOS's sign for recording
                        Text(verbatim: OwnDeckText.clock(decks.elapsed)).monospacedDigit().foregroundStyle(Color.primary)
                        LevelMeter(levelDBFS: decks.levelDBFS)
                    }
                    if !isLarge { Spacer(minLength: 8) }
                    Text(verbatim: OwnDeckText.stop).fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            // A167: "Stoppa inspelningen" is the name; the time is its value, so VoiceOver does not say the whole
            // name again every second.
            .accessibilityLabel(OwnDeckText.stopRecording)
            .accessibilityValue(OwnDeckText.seconds(decks.elapsed))
            .accessibilityAddTraits(.updatesFrequently)
            .accessibilityIdentifier(identifier + ".stop")
        } else if let take = card.recording(part) {
            let isPlaying = decks.previewing == target
            // Two buttons in one row: each takes its own taps.
            row {
                Button {
                    if isPlaying { decks.stopPreview() } else { Task { await decks.preview(part, card: card.id, in: deckID) } }
                } label: {
                    Label(OwnDeckText.clock(take.seconds), systemImage: isPlaying ? "stop.fill" : "play.fill")
                        .monospacedDigit()
                        .foregroundStyle(ink)
                }
                .buttonStyle(.borderless)
                .disabled(waits)
                .accessibilityLabel(isPlaying ? OwnDeckText.stop : OwnDeckText.playLabel(part, seconds: take.seconds))
                .accessibilityIdentifier(identifier + ".play")
                if !isLarge { Spacer(minLength: 8) }
                Button { start() } label: {
                    Label(OwnDeckText.recordAgain, systemImage: "arrow.counterclockwise").foregroundStyle(ink)
                }
                .buttonStyle(.borderless)
                .disabled(waits)
                .accessibilityLabel(OwnDeckText.recordAgainLabel(part))
                .accessibilityIdentifier(identifier)
            }
        } else {
            row {
                Button { start() } label: {
                    Label {
                        Text(verbatim: OwnDeckText.record).foregroundStyle(ink)
                    } icon: {
                        // The record sign, at the size of the dot that shows while it records.
                        Image(systemName: "circle.fill").imageScale(.small).foregroundStyle(waits ? Color(.tertiaryLabel) : Color.red)
                    }
                }
                .buttonStyle(.borderless)
                .disabled(waits)
                .accessibilityLabel(OwnDeckText.recordLabel(part))
                // A167: what stands beside the button is said with it ("Spela in svaret, inte inspelad · läses av
                // telefonen"), not as a loose line after it.
                .accessibilityValue(OwnDeckText.notRecorded(hasText: card.has(part)))
                .accessibilityIdentifier(identifier)
                if !isLarge { Spacer(minLength: 8) }
                Text(verbatim: OwnDeckText.notRecorded(hasText: card.has(part)))
                    .font(.footnote)
                    .foregroundStyle(LumenColor.secondaryText)
                    .multilineTextAlignment(isLarge ? .leading : .trailing)
                    .accessibilityHidden(true)
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
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        // A167: with the largest text on a small phone the half sheet cut the button off. It then takes the whole
        // height, and what still does not fit scrolls.
        ViewThatFits(in: .vertical) {
            content
            ScrollView { content }
        }
        .presentationDetents(typeSize.isAccessibilitySize ? [.large] : [.medium])
        .presentationDragIndicator(.visible)
        .accessibilityIdentifier("ownDecks.offer")
    }

    private var content: some View {
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
                .frame(minHeight: 44)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
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
