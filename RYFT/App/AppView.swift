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
    @State private var meshIntroTask: Task<Void, Never>?
    @Environment(\.scenePhase) private var scenePhase


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
        .environment(\.ryftTheme, appState.accentTheme)
        .environment(\.ryftCardMaterial, appState.accentTheme == .mesh ? .ultraThinMaterial : .regularMaterial)
        .environment(meshEngine)
        // ── Mesh: persistent state ────────────────────────────────────────────
        .onChange(of: derivedMeshState) { _, newState in
            meshEngine.state = newState
        }
        // ── Set logged: pulse + haptic + intensity ────────────────────────────
        .onChange(of: appState.workout.viewModel?.loggedSetCount) { oldCount, newCount in
            guard let oldCount, let newCount, newCount > oldCount else { return }
            let vm = appState.workout.viewModel
            guard vm?.showingPRMoment == nil else { return }

            // Haptic — always, every theme.
            // Exercise complete → success notification (distinctive double-pulse).
            // Last set of the whole workout → skip; workoutComplete haptic takes over.
            // Everything else → medium impact (single thud).
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

            // Mesh: intensity + pulse — Pro only
            if appState.accentTheme == .mesh {
                meshEngine.updateIntensity(min(Double(newCount) / 20.0, 1.0), pulse: true)
                meshEngine.lastLoggedExerciseIndex = vm?.lastLoggedExerciseIndex
                setLoggedTask?.cancel()
                meshEngine.state = isExerciseComplete ? .exerciseComplete : .setLogged
                setLoggedTask = Task {
                    // Hold exercise-complete green slightly longer so it reads clearly
                    try? await Task.sleep(for: .milliseconds(isExerciseComplete ? 700 : 500))
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
        // ── Mesh theme intro ──────────────────────────────────────────────────
        .onChange(of: appState.accentTheme) { _, newTheme in
            // Push new accent colour to the Live Activity so the island updates immediately.
            appState.workout.viewModel?.refreshActivityState()
            guard newTheme == .mesh else { return }
            // Slow warm white bloom — welcome to Lux. Deliberate, not reactive.
            // Holds for 2.5s so the 1.5s fade-in has room to breathe, then returns to base.
            playWorkoutStartHaptic()
            meshIntroTask?.cancel()
            meshEngine.state = .themeIntro
            meshIntroTask = Task {
                try? await Task.sleep(for: .milliseconds(2500))
                guard !Task.isCancelled else { return }
                meshEngine.state = derivedMeshState
            }
        }
        // ── PR & complete haptics ─────────────────────────────────────────────
        .onChange(of: meshEngine.state) { _, newState in
            switch newState {
            case .prBloom:
                // Ascending flourish is mesh-only — firePRCelebration() in the VM
                // already handles the primary haptic for all themes.
                guard appState.accentTheme == .mesh else { break }
                playPRHaptics()
            case .workoutComplete:
                Task {
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                    try? await Task.sleep(for: .milliseconds(150))
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            default:
                break
            }
        }
        .onOpenURL { url in
            guard url.scheme == "ryft", url.host == "workout" else { return }
            guard appState.workout.hasActiveWorkout else { return }
            appState.workout.isShowingFullWorkout = true
        }
        .task {
            ExerciseSeeder.seedIfNeeded(in: modelContext)
            appState.workout.onLaunch(modelContext: modelContext)
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                appState.workout.viewModel?.handleForeground()
            case .inactive, .background:
                appState.workout.viewModel?.persistDraftState()
            @unknown default:
                break
            }
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
