import SwiftUI

/// A13.1: Inställningar › Mer › Om appen: the promises and one line about the AI server. A22 (Deangelo): the licences
/// moved one level down, to "Licenser". The full texts are in `THIRD_PARTY_NOTICES.md` and in the app bundle.
struct AboutView: View {
    var body: some View {
        List {
            Section {
                Text("Lumen lyssnar bara när du har startat den, du ser alltid när den lyssnar, och ljud sparas inte.")
                Text("Frågor och svar går via Lumens server till en AI-modell. Röstprofilen och dina inställningar ligger bara på den här telefonen.")
                    .foregroundStyle(.secondary)
            }
            Section {
                NavigationLink("Licenser") { LicencesView() }
            } footer: {
                Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–") (\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "–"))")
            }
        }
        .lumenForm()
        .navigationTitle("Om appen")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// The parts from others, with their licences.
struct LicencesView: View {
    private struct Item: Identifiable {
        let name: String
        let licence: String
        let use: String
        var id: String { name }
    }

    private let items: [Item] = [
        Item(name: "ElevenLabs Scribe", licence: "Tjänst", use: "Taligenkänning i molnet. Ljudet skickas för att skrivas ut och sparas inte."),
        Item(name: "Silero VAD (via FluidAudio)", licence: "MIT", use: "Röstdetektor i telefonen: bara tal skickas till Scribe."),
        Item(name: "FluidAudio", licence: "Apache 2.0", use: "Kör röstdetektorn och röstavtrycket i telefonen."),
        Item(name: "WeSpeaker ResNet34", licence: "CC BY 4.0", use: "Röstprofilen (din röst känns igen). Ändrad Core ML-konvertering av Fluid Inference."),
        Item(name: "pyannote segmentation-3.0", licence: "MIT, © 2023 CNRS", use: "Delar upp tal per talare för röstprofilen."),
        Item(name: "fastcluster", licence: "BSD-2", use: "Länkas av FluidAudio."),
        Item(name: "Volocal SentenceBuffer", licence: "MIT", use: "Delar upp hörd text i meningar (ändrad)."),
        Item(name: "Spotify iOS SDK", licence: "Spotify Developer Terms", use: "Styr Spotify när du säger \"nästa låt\" (bara när du kopplat Spotify)."),
        Item(name: "Familjen Grotesk", licence: "SIL OFL 1.1", use: "Appens typsnitt."),
        Item(name: "Kalam", licence: "SIL OFL 1.1", use: "Handstilen för dina frågor."),
    ]

    var body: some View {
        List {
            Section("Delar från andra") {
                ForEach(items) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(item.name).font(.subheadline.weight(.semibold))
                            Spacer()
                            Text(item.licence).font(.caption).foregroundStyle(.secondary)
                        }
                        Text(item.use).font(.footnote).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .lumenForm()
        .navigationTitle("Licenser")
        .navigationBarTitleDisplayMode(.inline)
    }
}
