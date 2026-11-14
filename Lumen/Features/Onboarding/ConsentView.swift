import SwiftUI

/// Consent screen (ARCHITECTURE §12, MVP item 1). Shown before the first session and again when the policy
/// version changes; the same text is reachable later from the Listening screen as "Privacy & consent".
struct ConsentView: View {
    enum Mode {
        case onboarding(onAccept: () -> Void)
        case review(grantedAt: Date?, onWithdraw: () -> Void)
        /// A2: "Läs mer" from the intro's consent card: the full text, nothing to press.
        case readMore
    }

    let mode: Mode
    @State private var confirmingWithdrawal = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Innan du börjar")
                        .font(LumenFont.text(32, .bold, relativeTo: .largeTitle))
                        .accessibilityAddTraits(.isHeader)
                    Text("EarMind är en pluggkompis som lyssnar genom dina AirPods och svarar på det du frågar. Så här gör den med ljud och text.")
                        .font(LumenFont.text(17))
                        .foregroundStyle(LumenColor.muted)
                }

                // A41 (Deangelo G1, D116): a study app, the blue indicator, what is sent where, and other people's words.
                VStack(alignment: .leading, spacing: 18) {
                    point(symbol: "mic",
                          title: "Lyssnar bara när du har startat den",
                          text: "Du startar och stoppar själv. När mikrofonen är på syns en blå lyssnarbricka i appen, och iOS visar sin egen mikrofonsymbol.")
                    point(symbol: "waveform",
                          title: "Talet skrivs ut av ElevenLabs",
                          text: "Medan EarMind lyssnar skickas ljudet till ElevenLabs, som skriver ut det. Svaren läses också upp med en röst från ElevenLabs. Ljudet blir text och sparas inte av EarMind. Sömnläget sparar klippen bara på din telefon.")
                    point(symbol: "cloud",
                          title: "Svaren kommer från Claude",
                          text: "Texten skickas via EarMinds server till Claude från Anthropic, som tar fram svaret. Utan nät blir det inga svar.")
                    point(symbol: "paperplane",
                          title: "Frågor och svar skickas till oss",
                          text: "Dina frågor och EarMinds svar skickas till oss så att vi kan göra EarMind bättre. Ljudet blir text och sparas inte av EarMind. Sömnläget sparar klippen bara på din telefon. Texten raderas när vi har läst den.")
                    point(symbol: "person.2",
                          title: "Andras ord kan också komma med",
                          text: "I Standardläge svarar EarMind också på frågor som någon annan ställer, till exempel läraren. Då skrivs deras ord ut och skickas på samma sätt. Berätta för dem runt dig att du använder Lumen, och använd den inte där inspelning inte är tillåten, till exempel på prov.")
                    point(symbol: "clock.arrow.circlepath",
                          title: "Historik på telefonen",
                          text: "Dina frågor och svar sparas också i Historik på den här telefonen i högst två år. Du kan radera dem i Inställningar när du vill.")
                    point(symbol: "hand.raised",
                          title: "Du kan sluta när du vill",
                          text: "Ett tryck stoppar mikrofonen. Du kan ta tillbaka samtycket under Integritet och samtycke, och då visas den här sidan igen.")
                }

                if case .review(let grantedAt, _) = mode, let grantedAt {
                    Text("Samtycke givet \(grantedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(LumenFont.text(14, relativeTo: .footnote))
                        .foregroundStyle(LumenColor.muted)
                }
            }
            .padding(20)
        }
        .safeAreaInset(edge: .bottom) { footer }
        .background(LumenColor.background.ignoresSafeArea())
        .foregroundStyle(LumenColor.ink)
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var navigationTitle: LocalizedStringKey {
        switch mode {
        case .review: return "Integritet och samtycke"
        case .readMore: return "Läs mer"
        case .onboarding: return ""
        }
    }

    @ViewBuilder
    private var footer: some View {
        switch mode {
        case .onboarding(let onAccept):
            VStack(spacing: 8) {
                Button("Jag förstår, starta EarMind", action: onAccept)
                    .buttonStyle(LumenButtonStyle())
                Text("Genom att fortsätta bekräftar du att du har läst punkterna ovan.")
                    .font(LumenFont.text(14, relativeTo: .footnote))
                    .foregroundStyle(LumenColor.muted)
                    .multilineTextAlignment(.center)
            }
            .padding(20)
            .background(LumenColor.background)
        case .review(_, let onWithdraw):
            Button("Ta tillbaka samtycket") { confirmingWithdrawal = true }
                .buttonStyle(LumenButtonStyle(kind: .secondary, height: 50))
                .padding(20)
                .background(LumenColor.background)
                .confirmationDialog("Ta tillbaka samtycket?", isPresented: $confirmingWithdrawal, titleVisibility: .visible) {
                    Button("Sluta lyssna och ta tillbaka", role: .destructive, action: onWithdraw)
                } message: {
                    Text("Lyssningen stoppas, passets text raderas och samtyckessidan visas igen.")
                }
        case .readMore:
            EmptyView()
        }
    }

    private func point(symbol: String, title: LocalizedStringKey, text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(LumenColor.blue)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(LumenFont.text(17, .semibold, relativeTo: .headline))
                Text(text).font(LumenFont.text(16)).foregroundStyle(LumenColor.muted)
            }
        }
    }
}
