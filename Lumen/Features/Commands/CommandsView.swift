import SwiftUI

/// Personal keyword commands (D37): list, add/replace, delete. Also created by voice: "spara kommando <ord>: <instruktion>".
struct CommandsView: View {
    let store: CommandStore
    @State private var keyword = ""
    @State private var instruction = ""

    var body: some View {
        Form {
            Section {
                TextField("Keyword (what you say)", text: $keyword)
                    .textInputAutocapitalization(.never)
                TextField("Instruction (what Lumen should do)", text: $instruction, axis: .vertical)
                    .lineLimit(2...5)
                Button(editsExisting ? "Replace command" : "Add command") {
                    store.save(keyword: keyword, instruction: instruction)
                    keyword = ""
                    instruction = ""
                }
                .buttonStyle(.borderedProminent)
                .disabled(keyword.trimmingCharacters(in: .whitespaces).isEmpty || instruction.trimmingCharacters(in: .whitespaces).isEmpty)
            } header: {
                Text("New command")
            } footer: {
                Text("Say the keyword in a question and Lumen follows the instruction for that answer. You can also say: \"spara kommando fission: förklara fission och jämför med fusion\".")
            }

            Section("Saved commands") {
                if store.commands.isEmpty {
                    Text("No commands yet.").foregroundStyle(.secondary)
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
        .navigationTitle("Commands")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var editsExisting: Bool {
        store.commands.contains { $0.keyword.lowercased() == keyword.trimmingCharacters(in: .whitespaces).lowercased() }
    }
}
