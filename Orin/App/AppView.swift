// iOS 26+ only. No #available guards.

import SwiftUI
import SwiftData
import UIKit

struct AppView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @Environment(\.scenePhase) private var scenePhase

    private var isRunningInPreview: Bool {
        let environment = ProcessInfo.processInfo.environment
        return environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
            || environment["XCODE_RUNNING_FOR_PLAYGROUNDS"] == "1"
    }


    var body: some View {
        @Bindable var appState = appState
        @Bindable var workout = appState.workout

        TabView(selection: $appState.selectedTab) {
            NavigationStack {
                HomeRootView()
            }
            .tabItem { Label("Home", systemImage: "house") }
            .tag(AppTab.home)

            NavigationStack {
                ProgressRootView()
            }
            .tabItem { Label("Progress", systemImage: "chart.line.uptrend.xyaxis") }
            .tag(AppTab.progress)

            NavigationStack {
                LibraryRootView()
            }
            .tabItem { Label("Library", systemImage: "books.vertical") }
            .tag(AppTab.library)

            NavigationStack {
                SettingsRootView()
            }
            .tabItem { Label("Settings", systemImage: "gearshape") }
            .tag(AppTab.settings)
        }
        .tabViewBottomAccessory(isEnabled: appState.workout.hasActiveWorkout) {
            MiniWorkoutBar(service: appState.workout)
        }
        .sheet(isPresented: $workout.isShowingFullWorkout) {
            if let vm = appState.workout.viewModel {
                ActiveWorkoutView(vm: vm, onDismiss: {
                    appState.workout.handleWorkoutEnded()
                })
            }
        }
        .sensoryFeedback(.selection, trigger: appState.selectedTab)
        .tint(appState.accentTheme.accentColor)
        .preferredColorScheme(.dark)
        .environment(\.OrinTheme, appState.accentTheme)
        // ── Set logged: haptic ────────────────────────────────────────────────
        .onChange(of: appState.workout.viewModel?.loggedSetCount) { oldCount, newCount in
            guard let oldCount, let newCount, newCount > oldCount else { return }
            let vm = appState.workout.viewModel
            guard vm?.showingPRMoment == nil else { return }

            let isWorkoutComplete = vm?.isAllSetsLogged == true
            let isExerciseComplete: Bool = {
                guard !isWorkoutComplete,
                      let vm,
                      let idx = vm.lastLoggedExerciseIndex,
                      vm.draftExercises.indices.contains(idx) else { return false }
                return vm.draftExercises[idx].sets.allSatisfy { $0.isLogged }
            }()

            if isExerciseComplete {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } else if !isWorkoutComplete {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
        }
        // ── Workout complete haptic ───────────────────────────────────────────
        .onChange(of: appState.workout.viewModel?.isAllSetsLogged) { _, isComplete in
            guard isComplete == true else { return }
            Task {
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                try? await Task.sleep(for: .milliseconds(150))
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
        // ── Theme change: refresh Live Activity ───────────────────────────────
        .onChange(of: appState.accentTheme) { _, _ in
            appState.workout.viewModel?.refreshActivityState()
        }
        .onOpenURL { url in
            guard url.scheme == "Orin", url.host == "workout" else { return }
            guard appState.workout.hasActiveWorkout else { return }
            appState.workout.isShowingFullWorkout = true
        }
        .task {
            guard !isRunningInPreview else { return }
            ExerciseSeeder.seedIfNeeded(in: modelContext)
            RoutineSeeder.seedStarterRoutinesIfNeeded(in: modelContext)
            appState.workout.onLaunch(modelContext: modelContext)
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard !isRunningInPreview else { return }
            switch newPhase {
            case .active:
                if appState.workout.hasActiveWorkout {
                    appState.workout.isShowingFullWorkout = true
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(200))
                        appState.workout.viewModel?.requestRevealCurrentFocus()
                    }
                }
                appState.workout.viewModel?.handleForeground()
            case .inactive, .background:
                appState.workout.viewModel?.persistDraftState()
            @unknown default:
                break
            }
        }
    }


}

#Preview {
    AppView()
        .environment(AppState())
        .modelContainer(PersistenceController.previewContainer)
}
