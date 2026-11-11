import SwiftUI

/// Settings → History (D49/D56): read, delete one, delete everything.
struct HistoryView: View {
    let store: HistoryStore
    @State private var confirmingDeleteAll = false

    var body: some View {
        List {
            Section {
                if store.entries.isEmpty {
                    Text("No history yet. Your questions and Earmind's answers appear here.")
                        .foregroundStyle(.secondary)
                }
                ForEach(store.entries) { entry in
                    NavigationLink {
                        HistoryDetailView(store: store, entry: entry)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.title).lineLimit(2)
                            Text(entry.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete { offsets in
                    let doomed = offsets.map { store.entries[$0] }
                    for entry in doomed { store.delete(entry) }
                }
            } footer: {
                Text("Saved only on this iPhone and deleted automatically after 2 years. Other people's speech is not saved.")
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
        .confirmationDialog("Delete all history?", isPresented: $confirmingDeleteAll, titleVisibility: .visible) {
            Button("Delete all history", role: .destructive) { store.deleteAll() }
        } message: {
            Text("This cannot be undone.")
        }
    }
}

struct HistoryDetailView: View {
    let store: HistoryStore
    let entry: HistoryEntry
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            if let question = entry.question {
                Section("You") { Text(question).textSelection(.enabled) }
            }
            if !entry.answer.isEmpty {
                Section("Earmind") { Text(entry.answer).textSelection(.enabled) }
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
