import ActivityKit
import Foundation

@MainActor
protocol ListeningActivityPresenting: AnyObject {
    func show(isPaused: Bool)
    func end()
}

/// Keeps one Live Activity alive for the length of a session: state on the Lock Screen plus the Pause/Resume button.
/// `Activity` is not Sendable, so only its id is kept here and it is looked up off the main actor.
@MainActor
final class ListeningActivityPresenter: ListeningActivityPresenting {
    private typealias Content = ActivityContent<ListeningActivityAttributes.ContentState>

    private var activityID: String?

    init() {
        // A killed app leaves its Live Activity behind, with a button nothing answers.
        Task { await Self.endActivities(id: nil) }
    }

    func show(isPaused: Bool) {
        let content = Content(state: ListeningActivityAttributes.ContentState(isPaused: isPaused), staleDate: nil)
        if let activityID {
            Task { await Self.update(id: activityID, content: content) }
            return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            Log.session.info("Live Activities are off: only the in-app indicator shows")
            return
        }
        do {
            activityID = try Activity.request(attributes: ListeningActivityAttributes(), content: content, pushType: nil).id
        } catch {
            Log.session.error("Live Activity failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func end() {
        guard let activityID else { return }
        self.activityID = nil
        Task { await Self.endActivities(id: activityID) }
    }

    private nonisolated static func update(id: String, content: Content) async {
        await Activity<ListeningActivityAttributes>.activities.first { $0.id == id }?.update(content)
    }

    /// `id` nil ends all of them.
    private nonisolated static func endActivities(id: String?) async {
        for activity in Activity<ListeningActivityAttributes>.activities where id == nil || activity.id == id {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
