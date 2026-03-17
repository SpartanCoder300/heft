// iOS 26+ only. No #available guards.

import SwiftUI

struct HomeRootView: View {
    var body: some View {
        PlaceholderScreen(
            title: "Home",
            subtitle: "Workout launch, routines, and the fastest path into a session land here next.",
            systemImage: "house.fill"
        )
        .navigationTitle("Heft")
    }
}

#Preview () {
    
}
