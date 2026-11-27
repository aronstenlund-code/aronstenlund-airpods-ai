import SwiftUI

/// A162 (D259): the sentence with the user's own activation words in it, exactly as Aron wrote it:
/// "Fråga du inte är beredd på? Säg [ … ] så aktiveras vår AI." The field takes one or more words; they are kept
/// between starts, and an empty field is off. Shown on the listening screen and in Inställningar.
struct ActivationWordsField: View {
    let settings: ActivationSettings
    @State private var typed: String
    @FocusState private var isTyping: Bool

    init(settings: ActivationSettings) {
        self.settings = settings
        _typed = State(initialValue: settings.phrase)
    }

    /// Aron's sentence (D259), whole (Kelly Ke93 (1): one block, the field on its own row under it).
    static var sentence: String { String(localized: "Fråga du inte är beredd på? Säg [ … ] så aktiveras vår AI.") }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(Self.sentence)
                .fixedSize(horizontal: false, vertical: true)
            TextField(String(localized: "t.ex. Hjälp mig"), text: $typed)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .focused($isTyping)
                .onSubmit { isTyping = false }
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(LumenColor.line.opacity(0.6)))
                .accessibilityLabel(Text("Aktiveringsord"))
                .accessibilityIdentifier("activation.words")
        }
        .font(LumenFont.text(16))
        .frame(maxWidth: .infinity, alignment: .leading)
        // What is typed is kept tidy and remembered at once; the field itself keeps what the user sees while typing.
        .onChange(of: typed) { _, new in settings.setPhrase(new) }
    }
}
