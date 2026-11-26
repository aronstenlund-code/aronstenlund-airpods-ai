import SwiftUI
import UIKit

// A165 (D263): "Spela in själv – helt gratis", the views. The system's own parts, as the rest of the repetition
// (D160): a list of the user's decks, a deck with its questions and one filled button (Öva), and a sheet where a
// question and its answer are written and read in. The core behind `OwnDecking` is Angela Schrute's (A164).

/// The user's decks. Without any: what this is in one sentence, "Helt gratis", and Ny samling.
struct OwnDecksView: View {
    let decks: any OwnDecking
    @State private var naming = false
    @State private var name = ""
    @State private var opened: UUID?
    @State private var deleting: OwnDeck?

    var body: some View {
        Group {
            if decks.decks.isEmpty { empty } else { list }
        }
        .navigationTitle(OwnDeckText.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !decks.decks.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { naming = true } label: { Label(OwnDeckText.newDeck, systemImage: "plus") }
                        .accessibilityIdentifier("ownDecks.new")
                }
            }
        }
        .alert(OwnDeckText.newDeck, isPresented: $naming) {
            TextField(OwnDeckText.deckNamePrompt, text: $name)
            Button(OwnDeckText.create) { create() }
            Button(String(localized: "Avbryt"), role: .cancel) { name = "" }
        }
        .navigationDestination(item: $opened) { id in
            OwnDeckView(decks: decks, deckID: id)
        }
        .confirmationDialog(String(localized: "Radera samlingen och dess inspelningar?"),
                            isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
                            titleVisibility: .visible) {
            Button(String(localized: "Radera"), role: .destructive) {
                if let deleting { decks.deleteDeck(deleting.id) }
                deleting = nil
            }
            Button(String(localized: "Avbryt"), role: .cancel) { deleting = nil }
        }
    }

    /// A deck without a name is named after what it is.
    private func create() {
        let title = name.trimmingCharacters(in: .whitespacesAndNewlines)
        name = ""
        opened = decks.addDeck(title: title.isEmpty ? OwnDeckText.newDeck : title).id
    }

    private var empty: some View {
        ContentUnavailableView {
            Label(OwnDeckText.emptyTitle, systemImage: "mic")
        } description: {
            Text(verbatim: OwnDeckText.emptyLine)
        } actions: {
            Button { naming = true } label: {
                FilledButtonLabel { Text(verbatim: OwnDeckText.newDeck).font(.headline).frame(minWidth: 200) }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityIdentifier("ownDecks.new")
        }
    }

    private var list: some View {
        List {
            Section {
                ForEach(decks.decks) { deck in row(deck) }
            } footer: {
                Text(verbatim: OwnDeckText.staysOnPhone).foregroundStyle(LumenColor.secondaryText)
            }
        }
        .listStyle(.insetGrouped)
    }

    /// As the other quizzes on Start (Kelly R7): the row opens the deck, ▶ practises it directly.
    private func row(_ deck: OwnDeck) -> some View {
        HStack(spacing: 12) {
            Button { opened = deck.id } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: deck.title).foregroundStyle(.primary)
                    Text(verbatim: OwnDeckText.facts(cards: deck.cards.count, recorded: decks.recorded(in: deck)))
                        .font(.subheadline)
                        .foregroundStyle(LumenColor.secondaryText)
                        .monospacedDigit()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.pressFeedback)
            Button { Task { await decks.practise(deck.id) } } label: {
                Image(systemName: "play.circle.fill").font(.title).symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.borderless)
            .disabled(deck.cards.isEmpty)
            .accessibilityLabel(String(localized: "Öva \(deck.title)"))
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(String(localized: "Radera"), role: .destructive) { deleting = deck }
        }
    }
}

/// One deck: its questions (each says what is recorded), Ny fråga as the list's last row, and Öva as the screen's
/// one filled button.
struct OwnDeckView: View {
    let decks: any OwnDecking
    let deckID: UUID
    @State private var editing: Editing?
    @State private var renaming = false
    @State private var name = ""

    /// The card in the sheet: an existing one, or a new one.
    struct Editing: Identifiable {
        let id = UUID()
        var card: OwnCard?
    }

    private var deck: OwnDeck? { decks.deck(deckID) }

    var body: some View {
        let cards = deck?.cards ?? []
        return List {
            Section {
                ForEach(cards) { card in row(card) }
                    .onDelete { offsets in
                        for index in offsets where cards.indices.contains(index) { decks.deleteCard(cards[index].id, in: deckID) }
                    }
                Button { editing = Editing(card: nil) } label: {
                    Label(OwnDeckText.newCard, systemImage: "plus.circle.fill")
                }
                .accessibilityIdentifier("ownDeck.newCard")
            } footer: {
                Text(verbatim: OwnDeckText.staysOnPhone).foregroundStyle(LumenColor.secondaryText)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(deck?.title ?? OwnDeckText.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(String(localized: "Byt namn")) {
                    name = deck?.title ?? ""
                    renaming = true
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            MainActionBar(title: OwnDeckText.practise, systemImage: "play.fill",
                          note: cards.isEmpty ? OwnDeckText.addFirst : OwnDeckText.practiseNote,
                          isDisabled: cards.isEmpty) {
                Task { await decks.practise(deckID) }
            }
            .accessibilityIdentifier("ownDeck.practise")
        }
        .sheet(item: $editing) { item in
            NavigationStack { OwnCardEditor(decks: decks, deckID: deckID, card: item.card) }
        }
        .alert(String(localized: "Byt namn"), isPresented: $renaming) {
            TextField(OwnDeckText.deckNamePrompt, text: $name)
            Button(String(localized: "Klar")) {
                let title = name.trimmingCharacters(in: .whitespacesAndNewlines)
                if !title.isEmpty { decks.rename(deck: deckID, to: title) }
            }
            Button(String(localized: "Avbryt"), role: .cancel) {}
        }
    }

    private func row(_ card: OwnCard) -> some View {
        let hasAnswer = !card.answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let question = decks.seconds(of: OwnTake(deck: deckID, card: card.id, side: .question)) != nil
        let answer = decks.seconds(of: OwnTake(deck: deckID, card: card.id, side: .answer)) != nil
        let all = question && (answer || !hasAnswer)
        return Button { editing = Editing(card: card) } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: card.question).foregroundStyle(Color.primary).lineLimit(2)
                    if hasAnswer {
                        Text(verbatim: card.answer).font(.subheadline).foregroundStyle(LumenColor.secondaryText).lineLimit(1)
                    }
                    Text(verbatim: OwnDeckText.cardLine(question: question, answer: answer, hasAnswer: hasAnswer))
                        .font(.footnote)
                        .foregroundStyle(all ? AnyShapeStyle(.tint) : AnyShapeStyle(LumenColor.secondaryText))
                }
                Spacer(minLength: 0)
                Image(systemName: all ? "mic.fill" : "mic")
                    .foregroundStyle(all ? AnyShapeStyle(.tint) : AnyShapeStyle(Color(.tertiaryLabel)))
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .accessibilityHint(String(localized: "Öppnar frågan"))
    }
}

/// A question and its answer: each is written, and read in with one button under its text. While it records: the
/// red dot, the time, the level and Stoppa. After: Spela upp and Spela in igen. A new card is added with Lägg till;
/// an existing one saves with Klar.
struct OwnCardEditor: View {
    let decks: any OwnDecking
    let deckID: UUID
    @State private var draft: OwnCardDraft
    @State private var isSaved = false
    @FocusState private var focus: OwnSide?
    @Environment(\.dismiss) private var dismiss

    init(decks: any OwnDecking, deckID: UUID, card: OwnCard?) {
        self.decks = decks
        self.deckID = deckID
        _draft = State(initialValue: OwnCardDraft(editing: card))
    }

    var body: some View {
        Form {
            if let problem = decks.problem {
                Section { Text(verbatim: problem) }
            }
            side(.question, text: $draft.card.question)
            side(.answer, text: $draft.card.answer)
            if !draft.isNew {
                Section {
                    Button(String(localized: "Radera frågan"), role: .destructive) {
                        isSaved = true // nothing left to put back
                        decks.stopRecording()
                        decks.stopPlaying()
                        decks.deleteCard(draft.card.id, in: deckID)
                        dismiss()
                    }
                }
            }
        }
        .navigationTitle(draft.isNew ? OwnDeckText.newCard : OwnDeckText.sideTitle(.question))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if draft.isNew {
                ToolbarItem(placement: .cancellationAction) { Button(String(localized: "Avbryt")) { dismiss() } }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(draft.isNew ? String(localized: "Lägg till") : String(localized: "Klar")) { save() }
                    .disabled(!draft.canSave)
                    .accessibilityIdentifier("ownCard.save")
            }
        }
        // A pull does not throw away a recording that is being made.
        .interactiveDismissDisabled(decks.recording != nil)
        .onAppear { if draft.isNew { focus = .question } }
        .onDisappear {
            decks.stopRecording()
            decks.stopPlaying()
            // A new card that was never added leaves nothing behind, not its recordings either.
            if draft.isNew, !isSaved { decks.deleteCard(draft.card.id, in: deckID) }
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

    private func save() {
        guard draft.canSave else { return }
        decks.stopRecording()
        decks.stopPlaying()
        decks.save(draft.cleaned, in: deckID)
        isSaved = true
        dismiss()
    }

    private func side(_ side: OwnSide, text: Binding<String>) -> some View {
        Section {
            TextField(OwnDeckText.prompt(side), text: text, axis: .vertical)
                .lineLimit(1...5)
                .focused($focus, equals: side)
                .accessibilityIdentifier(side == .question ? "ownCard.question" : "ownCard.answer")
            OwnTakeRow(decks: decks, take: OwnTake(deck: deckID, card: draft.card.id, side: side)) { focus = nil }
        } header: {
            Text(verbatim: OwnDeckText.sideTitle(side))
        } footer: {
            if side == .answer { Text(verbatim: OwnDeckText.editorNote) }
        }
    }
}

/// One recording's row: Spela in, or the recording going on, or Spela upp and Spela in igen.
struct OwnTakeRow: View {
    let decks: any OwnDecking
    let take: OwnTake
    /// Before the microphone starts (the keyboard goes down, so its clicks are not recorded).
    var beforeRecording: () -> Void = {}

    private var identifier: String { take.side == .question ? "ownCard.recordQuestion" : "ownCard.recordAnswer" }

    var body: some View {
        if decks.recording == take {
            HStack(spacing: 10) {
                Circle().fill(Color.red).frame(width: 12, height: 12).accessibilityHidden(true) // iOS's sign for recording
                Text(verbatim: OwnDeckText.recording(decks.elapsed))
                    .monospacedDigit()
                    .accessibilityAddTraits(.updatesFrequently)
                Spacer(minLength: 8)
                LevelMeter(levelDBFS: decks.levelDBFS)
                Button(OwnDeckText.stop) { decks.stopRecording() }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .accessibilityIdentifier(identifier + ".stop")
            }
        } else if let seconds = decks.seconds(of: take) {
            let isPlaying = decks.playing == take
            // Two buttons in one row: each takes its own taps.
            HStack(spacing: 12) {
                Button {
                    if isPlaying { decks.stopPlaying() } else { decks.play(take) }
                } label: {
                    Label(isPlaying ? OwnDeckText.stop : OwnDeckText.listen(seconds), systemImage: isPlaying ? "stop.fill" : "play.fill")
                        .monospacedDigit()
                }
                .buttonStyle(.borderless)
                .accessibilityIdentifier(identifier + ".play")
                Spacer(minLength: 8)
                Button(OwnDeckText.recordAgain) { start() }
                    .buttonStyle(.borderless)
                    .disabled(decks.recording != nil)
                    .accessibilityIdentifier(identifier)
            }
        } else {
            Button { start() } label: {
                Label(OwnDeckText.record(take.side), systemImage: "mic")
            }
            .disabled(decks.recording != nil)
            .accessibilityIdentifier(identifier)
        }
    }

    private func start() {
        beforeRecording()
        decks.stopPlaying()
        Task { await decks.record(take) }
    }
}

// MARK: The sheet when the credits are out or the model is down

/// "Slut på krediter? Spela in dina egna frågor och svar – helt gratis." A half sheet with one button to "Spela in
/// själv"; it goes away with a tap on Inte nu or a pull.
struct OwnDeckOfferSheet: View {
    let reason: OwnDeckOffer.Reason
    let onOpen: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 4)
            Image(systemName: "mic.circle.fill")
                .font(.system(size: 56))
                .symbolRenderingMode(.hierarchical)
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

/// Shows the sheet over the view that is in front when the server says no (Start, or Nytt prov's sheet).
struct OwnDeckOfferPresenter: ViewModifier {
    let model: RepetitionModel
    /// Nothing else of this view's own is over it.
    var isFront = true

    func body(content: Content) -> some View {
        let offer = model.ownOffer
        content.sheet(isPresented: Binding(get: { isFront && offer.showing != nil }, set: { if !$0 { offer.close() } })) {
            if let reason = offer.showing {
                OwnDeckOfferSheet(reason: reason, onOpen: { offer.open() }, onClose: { offer.close() })
            }
        }
    }
}
