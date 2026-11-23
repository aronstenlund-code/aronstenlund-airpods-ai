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

    var body: some View {
        FlowLayout(spacing: 6) {
            Text(String(localized: "Fråga du inte är beredd på? Säg"))
                .frame(minHeight: 36)
            TextField("…", text: $typed)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .focused($isTyping)
                .onSubmit { isTyping = false }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 10)
                .frame(minWidth: 96, maxWidth: 220, minHeight: 36)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(LumenColor.line.opacity(0.6)))
                .fixedSize(horizontal: true, vertical: false)
                .accessibilityLabel(Text("Aktiveringsord"))
                .accessibilityIdentifier("activation.words")
            Text(String(localized: "så aktiveras vår AI."))
                .frame(minHeight: 36)
        }
        .font(LumenFont.text(16))
        .frame(maxWidth: .infinity, alignment: .leading)
        // What is typed is kept tidy and remembered at once; the field itself keeps what the user sees while typing.
        .onChange(of: typed) { _, new in settings.setPhrase(new) }
    }
}
