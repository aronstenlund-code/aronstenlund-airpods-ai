import SwiftUI

/// Consent gate + the always-visible listening indicator above every screen (ARCHITECTURE §12).
struct RootView: View {
    let container: AppContainer
    /// D86: the first start (intro with the short consent, the first question, an exam) runs once.
    @AppStorage(FirstStartView.doneKey) private var firstStartDone = false

    private var asksAboutSharing: Binding<Bool> {
        // A94: the history question is about listening; it waits until the listening consent is given.
        let asking = !container.share.hasAsked && container.consent.isGranted // read here, in `body`
        return Binding(get: { asking }, set: { _ in })
    }

    var body: some View {
        Group {
            #if DEBUG
            if let shot = ScreenshotStage.requested {
                // A2: one screen with demo data for the Simulator screenshots.
                ScreenshotStage(name: shot, container: container)
            } else {
                main
            }
            #else
            main
            #endif
        }
        .animation(.default, value: container.consent.isGranted)
        .environment(container.appearance)
        .preferredColorScheme(container.appearance.colorScheme) // D86: follows the iPhone unless locked
        .tint(LumenColor.blue)
        .onOpenURL { url in _ = container.listening.music.spotify?.handle(url) } // A6.3: back from Spotify
        .modifier(RepetitionOverlay(model: container.listening.repetition)) // A78–A81 (D142)
    }

    /// A94: the listening consent is asked when a mode that listens is started (never in the first start).
    private var asksForListeningConsent: Binding<Bool> {
        let listening = container.listening
        return Binding(get: { listening.asksForListeningConsent },
                       set: { if !$0, listening.asksForListeningConsent { listening.listeningConsentDeclined() } })
    }

    @ViewBuilder
    private var main: some View {
        if !firstStartDone || !container.consent.isWelcomeGranted {
            // A94 (Kelly Ke55): Välkommen → Nytt prov. Someone who finished the old first start sees Välkommen once.
            FirstStartView(container: container, returning: firstStartDone) { firstStartDone = true }
        } else {
            // D86: the indicator line is part of the main screen (above Start; Lyssnar is the indicator itself).
            NavigationStack {
                ListeningView(model: container.listening, diagnostics: container.diagnostics)
                    .sheet(isPresented: asksForListeningConsent) {
                        NavigationStack {
                            ConsentView(mode: .onboarding { container.listening.listeningConsentGiven() })
                                .toolbar {
                                    ToolbarItem(placement: .cancellationAction) {
                                        Button("Avbryt") { container.listening.listeningConsentDeclined() }
                                    }
                                }
                        }
                    }
            }
            .sheet(isPresented: asksAboutSharing) {
                ShareHistoryPromptView { container.listening.setSharing($0) }
            }
        }
    }
}
