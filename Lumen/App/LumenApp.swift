import SwiftUI
import UserNotifications

@main
struct LumenApp: App {
    @State private var container = AppContainer()

    init() {
        // A19: a tap on a link's notification opens it in Safari; plan reminders show in the foreground too.
        UNUserNotificationCenter.current().delegate = LumenNotifications.shared
    }

    var body: some Scene {
        WindowGroup {
            RootView(container: container)
        }
    }
}
