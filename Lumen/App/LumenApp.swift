import SwiftUI

@main
struct LumenApp: App {
    @State private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                DiagnosticsView(model: container.diagnostics)
            }
        }
    }
}
