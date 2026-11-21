import StoreKit
import SwiftUI
import UserNotifications

@main
struct LumenApp: App {
    @State private var holder = AppHolder()

    init() {
        // A19: a tap on a link's notification opens it in Safari; plan reminders show in the foreground too.
        UNUserNotificationCenter.current().delegate = LumenNotifications.shared
    }

    var body: some Scene {
        WindowGroup {
            AppRoot(holder: holder)
        }
    }
}

/// A145 (K101): the app's container, replaced by a new one when the account has been deleted, so the app starts as new
/// (first start, a new anonymous account) without being closed.
@MainActor
@Observable
final class AppHolder {
    private(set) var container: AppContainer
    /// A new value makes SwiftUI build every screen again from the new container.
    private(set) var generation = 0
    /// After a deletion: "Kontot är raderat", with K101's notice about the weekly pass when there is one.
    var showsDeleted = false
    private(set) var deletedNotice: String?
    /// D253: English until Svenska is chosen in Inställningar. Kept when the account is deleted (it is the phone's
    /// owner's choice of language, not the account's data).
    let language = AppLanguageSettings()

    init() {
        container = AppContainer()
        hook()
    }

    private func hook() {
        container.onRestart = { [weak self] notice in self?.restart(notice: notice) }
    }

    func restart(notice: String?) {
        container.retire()
        container = AppContainer()
        generation += 1
        hook()
        deletedNotice = notice
        showsDeleted = true
    }
}

private struct AppRoot: View {
    @Bindable var holder: AppHolder
    @State private var managesSubscriptions = false

    var body: some View {
        RootView(container: holder.container)
            // D253: a new language builds every screen again, so every text is the new language's at once.
            .id("\(holder.generation)-\(holder.language.language.rawValue)")
            .environment(holder.language)
            .environment(\.locale, holder.language.language.locale)
            .alert(AccountDeletionModel.doneTitle, isPresented: $holder.showsDeleted) {
                if holder.deletedNotice != nil {
                    Button("Hantera prenumerationer") { managesSubscriptions = true }
                }
                Button("Okej", role: .cancel) {}
            } message: {
                Text(verbatim: [AccountDeletionModel.doneLine, holder.deletedNotice].compactMap { $0 }.joined(separator: " "))
            }
            .manageSubscriptionsSheet(isPresented: $managesSubscriptions)
    }
}
