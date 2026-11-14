import SwiftUI

/// A94 (D160, Kelly Ke55 `docs/design/forsta-starten.md`, `bilder/apple/fs-1-valkommen.png`): the first screen of the
/// first start, built as Apple's own welcome screens: the app icon, "Välkommen till EarMind", three rows with a symbol,
/// a bold line and a sentence, and **Fortsätt** fixed at the bottom. What is sent stands in one line above the button,
/// with "Läs mer" for all of it. Nothing here is about listening: the modes that listen are BETA under Fler lägen and
/// ask for their own consent (`ConsentView`) when one is started. The view stores nothing; Fortsätt calls `onContinue`.
struct WelcomeView: View {
    let onContinue: () -> Void
    @State private var isReadingMore = false
    @Environment(\.dynamicTypeSize) private var typeSize

    private var isLarge: Bool { typeSize.isAccessibilitySize }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // With the largest text the icon gives way to the words, so the first row starts above the bar
                // with Fortsätt on an iPhone SE (Kelly G2, 10:51).
                if !isLarge {
                    AppMark(size: 72) // the app icon (D139)
                        .padding(.top, 56)
                }
                Text("Välkommen till EarMind")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.top, isLarge ? 8 : 20)
                VStack(alignment: .leading, spacing: isLarge ? 20 : 26) {
                    row("camera", "Fota materialet", "EarMind gör provfrågor med A-svar.")
                    row("waveform", "Lyssna i dina AirPods", "Frågorna läses upp. Tryck för svaret.")
                    row("book.closed", "Plugga utan mobilen", "Telefonen kan ligga i fickan.")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, isLarge ? 16 : 36)
                .padding(.bottom, 24)
            }
            .padding(.horizontal, isLarge ? 20 : 36)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .foregroundStyle(Color.primary)
        .background(Color(.systemBackground).ignoresSafeArea())
        .safeAreaInset(edge: .bottom) { bottom }
        .sheet(isPresented: $isReadingMore) { DataPrivacySheet() }
    }

    /// A symbol in the accent colour, a bold line and one sentence. With the largest text the symbol stands above
    /// the text, so the words get the whole width.
    private func row(_ symbol: String, _ title: String, _ detail: String) -> some View {
        let layout = isLarge ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
                             : AnyLayout(HStackLayout(alignment: .top, spacing: 16))
        return layout {
            Image(systemName: symbol)
                .font(.title)
                .foregroundStyle(.tint)
                .frame(width: isLarge ? nil : 44)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: title).font(.headline)
                Text(verbatim: detail).font(.subheadline).foregroundStyle(Color.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    /// What Fortsätt agrees to stands at the button (as Apple's line about data above Fortsätt), then the one button.
    private var bottom: some View {
        VStack(spacing: 0) {
            // Kelly (A95): this line is what Fortsätt agrees to, so it has the text colour, not the grey.
            Text("Fotona och texten skickas en gång för att göra frågorna och sparas inte. Starta prov använder aldrig mikrofonen.")
                .font(.footnote)
                .foregroundStyle(Color.primary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button { isReadingMore = true } label: { // "Läs mer": the words Toby's screen tour looks for
                // A95 (audit: hit area 48 × 15): the whole 44 pt row is the button.
                Text("Läs mer")
                    .font(.footnote)
                    .padding(.horizontal, 24)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            Button(action: onContinue) {
                FilledButtonLabel { // A95: dark label on the light accent in dark mode
                    Text("Fortsätt")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityShowsLargeContentViewer() // A95: the bar is capped at the first accessibility size
            .accessibilityHint("Godkänner att materialet skickas för att göra frågorna.")
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
        // As `MainActionBar`: the bar stops growing at the first accessibility size, so the three rows stay readable
        // above it on an iPhone SE with the largest text.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .background(Color(.systemBackground))
    }
}

/// "Läs mer" on Välkommen (Kelly Ke55, `fs-1b-lasmer.png`): a sheet with what is sent, what is saved and the
/// microphone, as a plain list with Klar. The line about ChatGPT is Kelly's from Ke58 (D169).
struct DataPrivacySheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Det här skickas") {
                    Text("Foton, dokument och text du lägger till skickas en gång till vår server och vår AI-leverantör för att göra frågorna. De sparas inte.")
                    Text("Frågorna och svaren skickas till vår röstleverantör för att bli ljud.")
                    Text("Använder du Gör med ChatGPT skickar du filerna till ChatGPT själv.")
                }
                Section("Det här sparas") {
                    Text("Dina prov, med frågor, svar och ljud, sparas hos EarMind tills du tar bort dem.")
                }
                Section {
                    Text("Starta prov använder aldrig mikrofonen. Lägena som lyssnar finns under Fler lägen och frågar först.")
                } header: {
                    Text("Mikrofonen")
                } footer: {
                    Text("Du behöver inte skapa något konto. Du kan ta bort allt under Inställningar.")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Data och integritet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Klar") { dismiss() } }
            }
        }
    }
}
