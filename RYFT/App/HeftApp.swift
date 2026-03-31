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

    private static var isRunningInPreview: Bool {
        let environment = ProcessInfo.processInfo.environment
        return environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
            || environment["XCODE_RUNNING_FOR_PLAYGROUNDS"] == "1"
    }

    init() {
        guard !Self.isRunningInPreview else { return }
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
