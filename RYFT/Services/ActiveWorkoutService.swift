// iOS 26+ only. No #available guards.

import SwiftUI
import SwiftData

/// Single source of truth for the active workout across the entire app.
/// Owns the ActiveWorkoutViewModel so state persists across tab switches.
/// Owns the Live Activity lifecycle — starts when a workout opens, ends when it closes.
@Observable @MainActor
final class ActiveWorkoutService {

    // MARK: - State

    private(set) var viewModel: ActiveWorkoutViewModel? = nil
    var isShowingFullWorkout: Bool = false
    let activityManager = WorkoutActivityManager()

    // MARK: - Derived

    var hasActiveWorkout: Bool { viewModel != nil }

    /// Name of the exercise currently in focus, for the mini bar.
    var focusedExerciseName: String? {
        guard let vm = viewModel, let focus = vm.currentFocus,
              vm.draftExercises.indices.contains(focus.exerciseIndex) else { return nil }
        return vm.draftExercises[focus.exerciseIndex].exerciseName
    }

    /// "Set X of Y" label for the focused set, for the mini bar.
    var focusedSetLabel: String? {
        guard let vm = viewModel, let focus = vm.currentFocus,
              vm.draftExercises.indices.contains(focus.exerciseIndex) else { return nil }
        let exercise = vm.draftExercises[focus.exerciseIndex]
        return "Set \(focus.setIndex + 1) of \(exercise.sets.count)"
    }

    // MARK: - Actions

    func startWorkout(routineID: UUID? = nil, sessionID: UUID? = nil, modelContext: ModelContext) {
        guard viewModel == nil else {
            // Already active — just surface it
            isShowingFullWorkout = true
            return
        }
        let vm = ActiveWorkoutViewModel(
            modelContext: modelContext,
            pendingRoutineID: routineID,
            pendingSessionID: sessionID,
            activityManager: activityManager
        )
        viewModel = vm
        isShowingFullWorkout = true
    }

    /// Called when the workout is finished or cancelled. Tears down the VM.
    func handleWorkoutEnded() {
        viewModel = nil
        isShowingFullWorkout = false
    }
}
