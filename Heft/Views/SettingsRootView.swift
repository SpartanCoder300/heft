// iOS 26+ only. No #available guards.

import SwiftUI

struct SettingsRootView: View {
    var body: some View {
        PlaceholderScreen(
            title: "Settings",
            subtitle: "Preferences, health sync, and the Pro surface live in this shell.",
            systemImage: "gearshape.fill"
        )
        .navigationTitle("Settings")
    }
}
