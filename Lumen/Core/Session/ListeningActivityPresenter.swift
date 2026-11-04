import ActivityKit
import Foundation

@MainActor
protocol ListeningActivityPresenting: AnyObject {
    func show(isPaused: Bool)
    func end()
}

/// Keeps one Live Activity alive for the length of a session: state on the Lock Screen plus the Pause/Resume button.
@MainActor
final class ListeningActivityPresenter: ListeningActivityPresenting {
    private var activity: Activity<ListeningActivityAttributes>?

    init() {
        // A killed app leaves its Live Activity behind, with a button nothing answers.
        for stale in Activity<ListeningActivityAttributes>.activities {
            Task { await stale.end(nil, dismissalPolicy: .immediate) }
        }
    }

    func show(isPaused: Bool) {
        let content = ActivityContent(state: ListeningActivityAttributes.ContentState(isPaused: isPaused), staleDate: nil)
        if let activity {
            Task { await activity.update(content) }
            return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            Log.session.info("Live Activities are off: only the in-app indicator shows")
            return
        }
        do {
            activity = try Activity.request(attributes: ListeningActivityAttributes(), content: content, pushType: nil)
        } catch {
            Log.session.error("Live Activity failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func end() {
        guard let activity else { return }
        self.activity = nil
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
    }
}
