import SwiftUI

/// Saved sessions (item 8): list → detail with Markdown text, share and delete.
struct NotesView: View {
    let store: NotesStore

    var body: some View {
        List {
            if store.notes.isEmpty {
                Text("No notes yet. Save a session from the Listening screen.")
                    .foregroundStyle(.secondary)
            }
            ForEach(store.notes) { note in
                NavigationLink {
                    NoteDetailView(store: store, note: note)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(note.title)
                        Text("\(note.createdAt.formatted(date: .abbreviated, time: .shortened)), \(note.answers.count) svar")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete { offsets in
                let doomed = offsets.map { store.notes[$0] }
                for note in doomed { store.delete(note) }
            }
            if let error = store.lastError {
                Text(error).font(.footnote).foregroundStyle(.red)
            }
        }
        .lumenForm()
        .navigationTitle("Anteckningar")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct NoteDetailView: View {
    let store: NotesStore
    let note: Note
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            Text(note.markdown)
                .font(.body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .lumenForm()
        .navigationTitle(note.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: note.markdown, subject: Text(note.title)) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    store.delete(note)
                    dismiss()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }
}
