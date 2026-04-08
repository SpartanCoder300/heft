// iOS 26+ only. No #available guards.

import ActivityKit
import BackgroundTasks
import SwiftData
import SwiftUI
import UserNotifications

/// Suppresses rest-timer notifications when the app is in the foreground.
/// zeroTask cancels the pending notification before it can fire, but this
/// delegate is a safety net for any race between suspension and the notification.
private final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([])
    }
}

@main
struct OrinApp: App {
    @State private var appState = AppState()
    private let sharedModelContainer = PersistenceController.sharedModelContainer
    private let notificationDelegate = NotificationDelegate()

    private static var isRunningInPreview: Bool {
        let environment = ProcessInfo.processInfo.environment
        return environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
            || environment["XCODE_RUNNING_FOR_PLAYGROUNDS"] == "1"
    }

    init() {
        guard !Self.isRunningInPreview else { return }
        UNUserNotificationCenter.current().delegate = notificationDelegate
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "MysticByte.Orin.rest-timer-end",
            using: nil
        ) { task in
            Self.handleRestTimerEndTask(task as! BGAppRefreshTask)
        }
    }

    /// Pushes a "rest cleared" Live Activity update when the app is woken in the background.
    /// Finds the active workout activity and zeroes the rest fields if the timer has expired.
    private static func handleRestTimerEndTask(_ task: BGAppRefreshTask) {
        task.expirationHandler = { task.setTaskCompleted(success: false) }
        Task { @MainActor in
            for activity in Activity<WorkoutActivityAttributes>.activities {
                let state = activity.content.state
                guard state.isResting,
                      let endsAt = state.restEndsAt,
                      endsAt <= .now else { continue }
                let cleared = WorkoutActivityAttributes.ContentState(
                    startedAt: state.startedAt,
                    currentExercise: state.currentExercise,
                    setsLogged: state.setsLogged,
                    totalSetCount: state.totalSetCount,
                    focusedSetLabel: state.focusedSetLabel,
                    focusedSetDetail: state.focusedSetDetail,
                    focusedSetNumber: state.focusedSetNumber,
                    exerciseSetCount: state.exerciseSetCount,
                    restEndsAt: nil,
                    totalRestDuration: nil,
                    accentR: state.accentR,
                    accentG: state.accentG,
                    accentB: state.accentB
                )
                // Local notification already fired for phone-asleep case — update silently.
                let content = ActivityContent(
                    state: cleared,
                    staleDate: .now + 8 * 3600,
                    relevanceScore: 100
                )
                await activity.update(content)
            }
            task.setTaskCompleted(success: true)
        }
    }

    var body: some Scene {
        WindowGroup {
            AppView()
                .environment(appState)
        }
        .modelContainer(sharedModelContainer)
    }
}
