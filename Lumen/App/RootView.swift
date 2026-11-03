import SwiftUI

/// Consent gate + the always-visible listening indicator above every screen (ARCHITECTURE §12).
struct RootView: View {
    let container: AppContainer

    var body: some View {
        Group {
            if container.consent.isGranted {
                NavigationStack {
                    ListeningView(model: container.listening, diagnostics: container.diagnostics)
                }
                .safeAreaInset(edge: .top, spacing: 0) {
                    ListeningIndicatorBar(state: container.sessionController.state,
                                          onStop: { Task { await container.listening.stopListening() } },
                                          onResume: { Task { await container.listening.resume() } })
                }
            } else {
                ConsentView(mode: .onboarding { container.consent.grant() })
            }
        }
        .animation(.default, value: container.consent.isGranted)
    }
}
