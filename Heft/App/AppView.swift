// iOS 26+ only. No #available guards.

import SwiftUI
import SwiftData

struct AppView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        @Bindable var appState = appState
        @Bindable var workout = appState.workout

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
        // ── Mini workout bar — only shown while a workout is active ──
        // The system automatically wraps content in a Liquid Glass capsule.
        .tabViewBottomAccessory(isEnabled: appState.workout.hasActiveWorkout) {
            MiniWorkoutBar(service: appState.workout)
        }
        // ── Full workout screen ──
        .sheet(isPresented: $workout.isShowingFullWorkout) {
            if let vm = appState.workout.viewModel {
                ActiveWorkoutView(vm: vm, onDismiss: {
                    appState.workout.handleWorkoutEnded()
                })
            }
        }
        .tint(appState.accentTheme.accentColor)
        .preferredColorScheme(.dark)
        .environment(\.heftTheme, appState.accentTheme)
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
