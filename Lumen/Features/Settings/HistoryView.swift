import SwiftUI

/// Settings → History (D49/D56): read, search, delete one, delete everything. Also from Lyssnar's ⋯ menu (the flow).
/// Deangelo 2026-11-27: easy to find an answer again – the newest first under its day, search, and ▶ on every row
/// reads the answer again in the AirPods. All of it is on the phone, so it works without a network and credits.
struct HistoryView: View {
    let store: HistoryStore
    /// Reads an answer again; nil where nothing can play (a picture).
    var listening: ListeningModel?
    @State private var confirmingDeleteAll = false
    @State private var search: String

    init(store: HistoryStore, listening: ListeningModel? = nil, search: String = "") {
        self.store = store
        self.listening = listening
        _search = State(initialValue: search)
    }

    private var shown: [HistoryEntry] { HistoryEntry.matching(store.entries, search) }

    var body: some View {
        List {
            if store.entries.isEmpty {
                Section {
                    Text("No history yet. Your questions and EarMind's answers appear here.")
                        .foregroundStyle(.secondary)
                } footer: {
                    footer
                }
            } else if shown.isEmpty {
                ContentUnavailableView.search(text: search) // the system's own words, in the phone's language
            }
            let days = HistoryEntry.days(shown)
            ForEach(days) { day in
                Section {
                    ForEach(day.entries) { entry in
                        NavigationLink {
                            HistoryDetailView(store: store, entry: entry, listening: listening)
                        } label: {
                            row(entry)
                        }
                    }
                    .onDelete { offsets in
                        let doomed = offsets.map { day.entries[$0] } // the rows as shown, also while searching
                        for entry in doomed { store.delete(entry) }
                    }
                } header: {
                    Text(verbatim: day.title)
                } footer: {
                    if day.id == days.last?.id { footer }
                }
            }
            if !store.entries.isEmpty {
                Section {
                    Button("Delete all history", role: .destructive) { confirmingDeleteAll = true }
                }
            }
            if let error = store.lastError {
                Text(error).font(.footnote).foregroundStyle(.red)
            }
        }
        .lumenForm()
        .navigationTitle("Historik")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $search) // the flow: find an answer from last week without scrolling
        .confirmationDialog("Delete all history?", isPresented: $confirmingDeleteAll, titleVisibility: .visible) {
            Button("Delete all history", role: .destructive) { store.deleteAll() }
        } message: {
            Text("This cannot be undone.")
        }
    }

    private var footer: some View {
        Text("Saved only on this iPhone and deleted automatically after 2 years. Other people's speech is not saved.")
    }

    private func row(_ entry: HistoryEntry) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title).lineLimit(2)
                Text(entry.createdAt.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if let listening, !entry.answer.isEmpty {
                ReadAgainButton(listening: listening, entry: entry, compact: true)
            }
        }
    }
}

/// ▶ / ■ for one history row: reads the answer again in the AirPods, or stops it.
struct ReadAgainButton: View {
    let listening: ListeningModel
    let entry: HistoryEntry
    var compact = false

    private var isReading: Bool { listening.readingAgain == entry.id }

    var body: some View {
        Button {
            if isReading { listening.stopReadingAgain() } else { listening.readAgain(entry) }
        } label: {
            if compact {
                Image(systemName: isReading ? "stop.circle.fill" : "play.circle.fill")
                    .font(.title2)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            } else {
                Label(isReading ? String(localized: "Stoppa") : String(localized: "Spela upp i AirPods"),
                      systemImage: isReading ? "stop.fill" : "play.fill")
            }
        }
        .buttonStyle(.borderless) // in a row: the button, not the row's link
        .foregroundStyle(.tint)
        .accessibilityLabel(isReading ? String(localized: "Stoppa") : String(localized: "Spela upp igen"))
        .accessibilityIdentifier(compact ? "history.play" : "history.detail.play")
    }
}

struct HistoryDetailView: View {
    let store: HistoryStore
    let entry: HistoryEntry
    var listening: ListeningModel?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            if let listening, !entry.answer.isEmpty {
                Section { ReadAgainButton(listening: listening, entry: entry) } // Deangelo 2026-11-27: one tap
            }
            if let question = entry.question {
                Section("You") { Text(question).textSelection(.enabled) }
            }
            if !entry.answer.isEmpty {
                Section("EarMind") { Text(entry.answer).textSelection(.enabled) }
            }
            if let link = entry.link {
                Section("Länk") { LinkRow(link: link) } // A19 (K19), opens in Safari
            }
            if !entry.suggestions.isEmpty {
                Section("Suggestions") {
                    ForEach(entry.suggestions, id: \.self) { Text($0) }
                }
            }
            if let summary = entry.summary {
                Section("Summary") { Text(summary).textSelection(.enabled) }
            }
        }
        .lumenForm()
        .navigationTitle(entry.createdAt.formatted(date: .abbreviated, time: .shortened))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    store.delete(entry)
                    dismiss()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }
}
