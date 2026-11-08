import SwiftUI

/// Settings → Minne (D49/D80): what Lumen remembers about the user, the rules for how it answers, and the user's own
/// commands (D37). Everything can be seen, changed and deleted; items Lumen found by itself are marked.
struct MemoryView: View {
    let store: MemoryStore
    let commands: CommandStore
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
                Text("Säg \"Lumen, kom ihåg …\", \"Lumen, glöm …\" eller \"Lumen, regel: …\". Efter varje tur sparar Lumen också viktiga saker du säger om dig själv, med datum. Känsliga uppgifter (hälsa, tro, politik och liknande) sparas aldrig av sig själva. Allt ligger på den här iPhonen, skickas med dina frågor och går ut efter 2 år.")
            }
            Section("Regler") {
                if store.rules.isEmpty {
                    Text("Inga regler. Säg till exempel \"Lumen, regel: svara alltid kort\".").foregroundStyle(.secondary)
                }
                ForEach(store.rules) { item in row(item) }
                    .onDelete { offsets in
                        let doomed = offsets.map { store.rules[$0] }
                        for item in doomed { store.delete(item) }
                    }
            }
            Section("Om dig") {
                if store.facts.isEmpty {
                    Text("Inget sparat ännu.").foregroundStyle(.secondary)
                }
                ForEach(store.facts) { item in row(item) }
                    .onDelete { offsets in
                        let doomed = offsets.map { store.facts[$0] }
                        for item in doomed { store.delete(item) }
                    }
            }
            Section("Egna kommandon") {
                if commands.commands.isEmpty {
                    Text("Inga kommandon. Säg \"spara kommando ord: instruktion\".").foregroundStyle(.secondary)
                }
                ForEach(commands.commands) { command in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(command.keyword).font(.subheadline.weight(.semibold))
                        Text(command.instruction).font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .onDelete { offsets in
                    let doomed = offsets.map { commands.commands[$0] }
                    for command in doomed { commands.delete(command) }
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
        .lumenForm()
        .navigationTitle("Minne")
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

    private func row(_ item: MemoryItem) -> some View {
        Button {
            editedText = item.text
            editing = item
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.text).foregroundStyle(.primary)
                Text(caption(item)).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func caption(_ item: MemoryItem) -> String {
        let source = switch item.source {
        case .voice: "sagt"
        case .manual: "skrivet"
        case .automatic: "hittat av Lumen"
        }
        return "\(item.createdAt.formatted(date: .abbreviated, time: .omitted)), \(source)"
    }

    private var isEditing: Binding<Bool> {
        Binding(get: { editing != nil }, set: { if !$0 { editing = nil } })
    }

    private func add() {
        if store.add(newMemory) != nil { newMemory = "" }
    }
}
