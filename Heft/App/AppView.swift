// iOS 26+ only. No #available guards.

import SwiftUI
import SwiftData
import UIKit

struct AppView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @State private var meshEngine = MeshEngine()
    @State private var setLoggedTask: Task<Void, Never>?
    @State private var workoutStartTask: Task<Void, Never>?

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
                HistoryRootView()
            }
            .tabItem { Label("History", systemImage: "chart.bar") }
            .tag(AppTab.history)

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
        .tint(appState.accentTheme.accentColor)
        .preferredColorScheme(.dark)
        .environment(\.heftTheme, appState.accentTheme)
        .environment(\.heftCardMaterial, appState.accentTheme == .mesh ? .ultraThinMaterial : .regularMaterial)
        .environment(meshEngine)
        // ── Mesh: persistent state ────────────────────────────────────────────
        .onChange(of: derivedMeshState) { _, newState in
            meshEngine.state = newState
        }
        // ── Set logged: pulse + haptic + intensity ────────────────────────────
        .onChange(of: appState.workout.viewModel?.loggedSetCount) { oldCount, newCount in
            guard let oldCount, let newCount, newCount > oldCount else { return }
            guard appState.workout.viewModel?.showingPRMoment == nil else { return }

            // Haptic — always, every theme
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()

            // Mesh: intensity + pulse — Pro only
            if appState.accentTheme == .mesh {
                meshEngine.updateIntensity(min(Double(newCount) / 20.0, 1.0), pulse: true)
                meshEngine.lastLoggedExerciseIndex = appState.workout.viewModel?.lastLoggedExerciseIndex
                setLoggedTask?.cancel()
                meshEngine.state = .setLogged
                setLoggedTask = Task {
                    try? await Task.sleep(for: .milliseconds(500))
                    guard !Task.isCancelled else { return }
                    meshEngine.state = derivedMeshState
                }
            }
        }
        // ── Workout start/end: pulse + haptic ────────────────────────────────
        .onChange(of: appState.workout.hasActiveWorkout) { _, isActive in
            if isActive {
                guard appState.accentTheme == .mesh else { return }
                playWorkoutStartHaptic()
                workoutStartTask?.cancel()
                meshEngine.state = .workoutStarted
                workoutStartTask = Task {
                    try? await Task.sleep(for: .milliseconds(1000))
                    guard !Task.isCancelled else { return }
                    meshEngine.state = derivedMeshState
                }
            } else {
                workoutStartTask?.cancel()
                meshEngine.updateIntensity(0, pulse: false)
            }
        }
        // ── PR & complete haptics ─────────────────────────────────────────────
        .onChange(of: meshEngine.state) { _, newState in
            switch newState {
            case .prBloom:
                playPRHaptics()
            case .workoutComplete:
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            default:
                break
            }
        }
        .task {
            ExerciseSeeder.seedIfNeeded(in: modelContext)
        }
    }

    private var derivedMeshState: MeshState {
        guard let vm = appState.workout.viewModel else { return .base }
        if vm.showingPRMoment != nil { return .prBloom }
        if vm.isAllSetsLogged { return .workoutComplete }
        return .base
    }

    /// Two beats — medium then heavy — like a starting signal.
    private func playWorkoutStartHaptic() {
        Task {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            try? await Task.sleep(for: .milliseconds(90))
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }
    }

    /// Three ascending impacts timed to the amber flood-in.
    private func playPRHaptics() {
        Task {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            try? await Task.sleep(for: .milliseconds(120))
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            try? await Task.sleep(for: .milliseconds(140))
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }
    }
}

#Preview {
    AppView()
        .environment(AppState())
        .modelContainer(PersistenceController.previewContainer)
}
