// iOS 26+ only. No #available guards.

import SwiftUI
import SwiftData

struct AppView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        @Bindable var appState = appState

        TabView(selection: $appState.selectedTab) {
            NavigationStack {
                HomeRootView()
            }
            .tabItem {
                Label("Home", systemImage: "house")
            }
            .tag(AppTab.home)

            NavigationStack {
                HistoryRootView()
            }
            .tabItem {
                Label("History", systemImage: "chart.bar")
            }
            .tag(AppTab.history)

            NavigationStack {
                SettingsRootView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
            .tag(AppTab.settings)
        }
        .tint(.heftAccent)
        .background(Color.heftBackground.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .task {
            ExerciseSeeder.seedIfNeeded(in: modelContext)
        }
    }
}

#Preview {
    AppView()
        .environment(AppState())
        .modelContainer(PersistenceController.previewContainer)
}
