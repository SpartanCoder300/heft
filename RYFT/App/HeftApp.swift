// iOS 26+ only. No #available guards.

import SwiftData
import SwiftUI

@main
struct RYFTApp: App {
    @State private var appState = AppState()
    private let sharedModelContainer = PersistenceController.sharedModelContainer

    var body: some Scene {
        WindowGroup {
            AppView()
                .environment(appState)
        }
        .modelContainer(sharedModelContainer)
    }
}
