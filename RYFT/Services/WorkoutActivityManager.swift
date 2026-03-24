// iOS 26+ only. No #available guards.

import ActivityKit
import Foundation

/// Owns the Live Activity lifecycle for an active workout session.
/// Start once when the first set is logged, update on meaningful state changes, end on finish.
@MainActor
final class WorkoutActivityManager {

    private var activity: Activity<WorkoutActivityAttributes>?

    func start(routineName: String, state: WorkoutActivityAttributes.ContentState) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        guard activity == nil else { return }
        let attributes = WorkoutActivityAttributes(routineName: routineName)
        let content = ActivityContent(state: state, staleDate: nil)
        do {
            activity = try Activity.request(attributes: attributes,
                                            content: content,
                                            pushType: nil)
        } catch {
            print("[WorkoutActivityManager] Failed to start Live Activity: \(error)")
        }
    }

    func update(_ state: WorkoutActivityAttributes.ContentState) {
        guard let activity else { return }
        Task {
            let content = ActivityContent(state: state, staleDate: nil)
            await activity.update(content)
        }
    }

    func end(_ state: WorkoutActivityAttributes.ContentState) {
        guard let activity else { return }
        let captured = activity
        self.activity = nil
        Task {
            // Show final state briefly before dismissing.
            let content = ActivityContent(state: state, staleDate: .now)
            await captured.end(content, dismissalPolicy: .after(.now + 4))
        }
    }
}
