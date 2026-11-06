import SwiftUI

/// Settings → Memory (D49): what Lumen remembers about the user, sent with each question.
struct MemoryView: View {
    let store: MemoryStore
    @State private var newMemory = ""
    @State private var editing: MemoryItem?
    @State private var editedText = ""
    @State private var confirmingDeleteAll = false

    var body: some View {
        List {
            Section {
                HStack {
                    TextField("Add something to remember", text: $newMemory)
                        .submitLabel(.done)
                        .onSubmit(add)
                    Button("Add", action: add)
                        .disabled(newMemory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            } footer: {
                Text("You can also say \"kom ihåg …\". Lumen never saves anything you did not ask it to remember. Saved on this iPhone and sent with your questions. Memories expire 2 years after you last confirmed them.")
            }
            Section {
                if store.items.isEmpty {
                    Text("Nothing saved yet.").foregroundStyle(.secondary)
                }
                ForEach(store.items) { item in
                    Button {
                        editedText = item.text
                        editing = item
                    } label: {
                        Text(item.text).foregroundStyle(.primary)
                    }
                }
                .onDelete { offsets in
                    let doomed = offsets.map { store.items[$0] }
                    for item in doomed { store.delete(item) }
                }
            }
            if !store.items.isEmpty {
                Section {
                    Button("Delete all memories", role: .destructive) { confirmingDeleteAll = true }
                }
            }
            if let error = store.lastError {
                Text(error).font(.footnote).foregroundStyle(.red)
            }
        }
        .navigationTitle("Memory")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Edit memory", isPresented: isEditing, presenting: editing) { item in
            TextField("Memory", text: $editedText)
            Button("Save") { store.update(item, text: editedText) }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Delete all memories?", isPresented: $confirmingDeleteAll, titleVisibility: .visible) {
            Button("Delete all memories", role: .destructive) { store.deleteAll() }
        } message: {
            Text("This cannot be undone.")
        }
    }

    private var isEditing: Binding<Bool> {
        Binding(get: { editing != nil }, set: { if !$0 { editing = nil } })
    }

    private func add() {
        if store.add(newMemory) != nil { newMemory = "" }
    }
}
