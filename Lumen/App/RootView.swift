import SwiftUI

/// Consent gate + the always-visible listening indicator above every screen (ARCHITECTURE §12).
struct RootView: View {
    let container: AppContainer
    /// D86: the first start (intro with the short consent, the first question, an exam) runs once.
    @AppStorage(FirstStartView.doneKey) private var firstStartDone = false

    private var asksAboutSharing: Binding<Bool> {
        let asking = !container.share.hasAsked // read here, in `body`, so the view follows it
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
    }

    @ViewBuilder
    private var main: some View {
        if !firstStartDone {
            FirstStartView(container: container) { firstStartDone = true }
        } else if container.consent.isGranted {
            // D86: the indicator line is part of the main screen (above Start; Lyssnar is the indicator itself).
            NavigationStack {
                ListeningView(model: container.listening, diagnostics: container.diagnostics)
            }
            .sheet(isPresented: asksAboutSharing) {
                ShareHistoryPromptView { container.listening.setSharing($0) }
            }
        } else {
            ConsentView(mode: .onboarding { container.consent.grant() })
        }
    }
}
