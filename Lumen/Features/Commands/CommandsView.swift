import SwiftUI

/// Personal keyword commands (D37): list, add/replace, delete. Also created by voice: "spara kommando <ord>: <instruktion>".
struct CommandsView: View {
    let store: CommandStore
    @State private var keyword = ""
    @State private var instruction = ""

    var body: some View {
        Form {
            Section {
                TextField("Ord (det du säger)", text: $keyword)
                    .textInputAutocapitalization(.never)
                TextField("Instruktion (det Earmind ska göra)", text: $instruction, axis: .vertical)
                    .lineLimit(2...5)
                Button(editsExisting ? "Ersätt kommandot" : "Lägg till kommando") {
                    store.save(keyword: keyword, instruction: instruction)
                    keyword = ""
                    instruction = ""
                }
                .buttonStyle(.borderedProminent)
                .disabled(keyword.trimmingCharacters(in: .whitespaces).isEmpty || instruction.trimmingCharacters(in: .whitespaces).isEmpty)
            } header: {
                Text("Nytt kommando")
            } footer: {
                Text("Säg ordet i en fråga, så följer Earmind instruktionen i det svaret. Du kan också säga: ”spara kommando fission: förklara fission och jämför med fusion”.")
            }

            Section("Sparade kommandon") {
                if store.commands.isEmpty {
                    Text("Inga kommandon än.").foregroundStyle(.secondary)
                }
                ForEach(store.commands) { command in
                    Button {
                        keyword = command.keyword
                        instruction = command.instruction
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(command.keyword).font(.headline)
                            Text(command.instruction).font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    .tint(.primary)
                }
                .onDelete { offsets in
                    let doomed = offsets.map { store.commands[$0] }
                    for command in doomed { store.delete(command) }
                }
            }
            if let error = store.lastError {
                Text(error).font(.footnote).foregroundStyle(.red)
            }
        }
        .lumenForm()
        .navigationTitle("Egna kommandon")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var editsExisting: Bool {
        store.commands.contains { $0.keyword.lowercased() == keyword.trimmingCharacters(in: .whitespaces).lowercased() }
    }
}
