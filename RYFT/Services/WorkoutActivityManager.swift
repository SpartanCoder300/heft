// iOS 26+ only. No #available guards.

import ActivityKit
import Foundation

/// Owns the Live Activity lifecycle for an active workout session.
/// Started when the workout screen appears, updated on every meaningful state change, ended on finish or cancel.
@MainActor
final class WorkoutActivityManager {

    private var activity: Activity<WorkoutActivityAttributes>?
    private var updateTask: Task<Void, Never>?

    /// Maximum realistic workout duration used as the stale date on every update.
    /// If the app crashes and never ends the activity, the system marks it stale after 8 hours.
    private let maxWorkoutDuration: TimeInterval = 8 * 3600

    /// Call once at app launch before any workout starts.
    /// Ends any Live Activity left over from a previous session (crash, force-quit, etc.)
    /// so the Dynamic Island never shows stale workout data when no workout is active.
    func endOrphanedActivities() {
        Task {
            for orphan in Activity<WorkoutActivityAttributes>.activities {
                await orphan.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    func start(routineName: String, state: WorkoutActivityAttributes.ContentState) {
        start(sessionID: UUID(), routineName: routineName, state: state)
    }

    func start(sessionID: UUID, routineName: String, state: WorkoutActivityAttributes.ContentState) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        guard activity == nil else { return }
        let sessionIDString = sessionID.uuidString
        let activeActivities = Activity<WorkoutActivityAttributes>.activities.filter {
            $0.activityState == .active
        }

        // Adopt any activity left over from a previous app session (e.g. after a crash/relaunch).
        // Syncs state immediately so the Live Activity reflects current reality.
        if let existing = activeActivities.first(where: { $0.attributes.sessionID == sessionIDString }) {
            activity = existing
            observeActivityState(existing)
            endExtraActivities(except: existing.id)
            update(state)
            return
        }

        if !activeActivities.isEmpty {
            endActivities(activeActivities)
        }

        let attributes = WorkoutActivityAttributes(routineName: routineName, sessionID: sessionIDString)
        let content = ActivityContent(state: state, staleDate: .now + maxWorkoutDuration,
                                      relevanceScore: 100)
        do {
            let requested = try Activity.request(attributes: attributes,
                                                 content: content,
                                                 pushType: nil)
            activity = requested
            observeActivityState(requested)
        } catch {
            print("[WorkoutActivityManager] Failed to start Live Activity: \(error)")
        }
    }

    private func endExtraActivities(except retainedID: String) {
        let extras = Activity<WorkoutActivityAttributes>.activities.filter {
            $0.activityState == .active && $0.id != retainedID
        }
        guard !extras.isEmpty else { return }
        endActivities(extras)
    }

    private func endActivities(_ activities: [Activity<WorkoutActivityAttributes>]) {
        Task {
            for activity in activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    /// Observes system-driven state changes on the activity.
    /// Clears our reference if the system ends or dismisses the activity externally
    /// (e.g. user disables Live Activities in Settings mid-workout).
    private func observeActivityState(_ observed: Activity<WorkoutActivityAttributes>) {
        Task { [weak self] in
            for await state in observed.activityStateUpdates {
                guard let self else { return }
                if state == .ended || state == .dismissed {
                    if self.activity?.id == observed.id {
                        self.updateTask?.cancel()
                        self.updateTask = nil
                        self.activity = nil
                    }
                    return
                }
            }
        }
    }

    func update(_ state: WorkoutActivityAttributes.ContentState) {
        guard let activity else { return }
        // Cancel any in-flight update so only the latest state wins.
        updateTask?.cancel()
        updateTask = Task {
            guard !Task.isCancelled else { return }
            // During rest, extend the stale window well past the timer end so the system
            // doesn't show a stale spinner if the app is suspended when the timer fires.
            // The app will push a "rest cleared" update via handleForeground() when it
            // resumes — the extended window just prevents the spinner in the gap.
            // Otherwise cap at max workout duration.
            let staleDate = state.restEndsAt.map { $0.addingTimeInterval(30) }
                         ?? (.now + maxWorkoutDuration)
            let content = ActivityContent(
                state: state,
                staleDate: staleDate,
                relevanceScore: 100
            )
            await activity.update(content)
        }
    }

    func end(_ state: WorkoutActivityAttributes.ContentState) {
        guard let activity else { return }
        updateTask?.cancel()
        updateTask = nil
        let captured = activity
        self.activity = nil
        Task {
            // staleDate matches the dismissal window so no stale indicator flashes.
            let content = ActivityContent(
                state: state,
                staleDate: .now + 4,
                relevanceScore: 0
            )
            await captured.end(content, dismissalPolicy: .after(.now + 4))
        }
    }
}
