// iOS 26+ only. No #available guards.

import SwiftUI

struct HistoryRootView: View {
    var body: some View {
        PlaceholderScreen(
            title: "History",
            subtitle: "Completed sessions and exercise detail will plug into this stack in Phase 2 and 3.",
            systemImage: "chart.bar.fill"
        )
        .navigationTitle("History")
    }
}
