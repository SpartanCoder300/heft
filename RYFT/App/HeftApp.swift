// iOS 26+ only. No #available guards.

import SwiftData
import SwiftUI
import UserNotifications

/// Suppresses rest-timer notifications when the app is in the foreground.
/// The in-app timer UI and haptics already handle the "rest complete" event —
/// showing a banner on top would be redundant and disruptive.
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
struct RYFTApp: App {
    @State private var appState = AppState()
    private let sharedModelContainer = PersistenceController.sharedModelContainer
    private let notificationDelegate = NotificationDelegate()

    init() {
        UNUserNotificationCenter.current().delegate = notificationDelegate
    }

    var body: some Scene {
        WindowGroup {
            AppView()
                .environment(appState)
        }
        .modelContainer(sharedModelContainer)
    }
}
