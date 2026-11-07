import SwiftUI

/// Consent gate + the always-visible listening indicator above every screen (ARCHITECTURE §12).
struct RootView: View {
    let container: AppContainer

    private var asksAboutSharing: Binding<Bool> {
        let asking = !container.share.hasAsked // read here, in `body`, so the view follows it
        return Binding(get: { asking }, set: { _ in })
    }

    var body: some View {
        Group {
            if container.consent.isGranted {
                // D74: the indicator sits above the navigation bar, not on top of the title.
                VStack(spacing: 0) {
                    ListeningIndicatorBar(state: container.sessionController.state,
                                          onStop: { Task { await container.listening.stopListening() } },
                                          onResume: { Task { await container.listening.resume() } })
                    NavigationStack {
                        ListeningView(model: container.listening, diagnostics: container.diagnostics)
                    }
                }
                .sheet(isPresented: asksAboutSharing) {
                    ShareHistoryPromptView { container.listening.setSharing($0) }
                }
            } else {
                ConsentView(mode: .onboarding { container.consent.grant() })
            }
        }
        .animation(.default, value: container.consent.isGranted)
    }
}
