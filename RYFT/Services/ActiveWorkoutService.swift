// iOS 26+ only. No #available guards.

import SwiftUI
import SwiftData

// MARK: - Service

/// Single source of truth for the active workout across the entire app.
/// Owns the ActiveWorkoutViewModel so state persists across tab switches.
/// Owns the Live Activity lifecycle — starts when a workout opens, ends when it closes.
@Observable @MainActor
final class ActiveWorkoutService {

    // MARK: - State

    private(set) var viewModel: ActiveWorkoutViewModel? = nil
    var isShowingFullWorkout: Bool = false
    let activityManager = WorkoutActivityManager()

    // MARK: - Persistence

    /// UserDefaults key for the active session ID.
    /// Written when a session is created, cleared when the workout ends.
    /// @AppStorage / @SceneStorage are not used here — UserDefaults.standard is written
    /// directly from a VM callback so the write is guaranteed to happen at set-log time,
    /// with no dependency on SwiftUI observation chains or scene restoration timing.
    static let sessionIDKey = "activeWorkoutSessionID"

    private func persistSessionID(_ id: UUID?) {
        if let id {
            UserDefaults.standard.set(id.uuidString, forKey: Self.sessionIDKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.sessionIDKey)
        }
    }

    init() {}

    // MARK: - Derived

    var hasActiveWorkout: Bool { viewModel != nil }

    var focusedExerciseName: String? {
        guard let vm = viewModel, let focus = vm.currentFocus,
              vm.draftExercises.indices.contains(focus.exerciseIndex) else { return nil }
        return vm.draftExercises[focus.exerciseIndex].exerciseName
    }

    var focusedSetLabel: String? {
        guard let vm = viewModel, let focus = vm.currentFocus,
              vm.draftExercises.indices.contains(focus.exerciseIndex) else { return nil }
        let exercise = vm.draftExercises[focus.exerciseIndex]
        return "Set \(focus.setIndex + 1) of \(exercise.sets.count)"
    }

    // MARK: - Launch

    /// Call once at app launch before any workout starts.
    /// Reads UserDefaults directly (not @AppStorage) to avoid scene-restoration timing issues.
    func onLaunch(modelContext: ModelContext) {
        if let idString = UserDefaults.standard.string(forKey: Self.sessionIDKey),
           let id = UUID(uuidString: idString) {
            checkForResumption(sessionID: id, modelContext: modelContext)
        } else {
            // No stored session — safe to end any orphaned Live Activity now.
            activityManager.endOrphanedActivities()
        }
    }

    // MARK: - Resumption (private)

    /// Finds a session by ID and auto-resumes it with no user prompt —
    /// matching Apple's Workout app behavior.
    private func checkForResumption(sessionID: UUID, modelContext: ModelContext) {
        guard viewModel == nil else { return }

        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.id == sessionID }
        )
        guard let session = (try? modelContext.fetch(descriptor))?.first else {
            persistSessionID(nil)
            activityManager.endOrphanedActivities()
            return
        }

        // Already completed — stale stored ID.
        guard session.completedAt == nil else {
            persistSessionID(nil)
            activityManager.endOrphanedActivities()
            return
        }

        // No exercises at all — completely empty session, nothing to show. Clean up.
        guard !session.exercises.isEmpty else {
            persistSessionID(nil)
            modelContext.delete(session)
            try? modelContext.save()
            activityManager.endOrphanedActivities()
            return
        }

        // Keep the session ID in UserDefaults for the duration of the resumed workout.
        persistSessionID(session.id)

        // Auto-resume: reconstruct the VM from persisted SwiftData state.
        // The Live Activity is adopted inside setup() via WorkoutActivityManager.start(),
        // which checks Activity<WorkoutActivityAttributes>.activities.first.
        let vm = ActiveWorkoutViewModel(
            modelContext:     modelContext,
            pendingRoutineID: nil,
            pendingSessionID: nil,
            resumeSessionID:  session.id,
            activityManager:  activityManager
        )
        viewModel = vm
        isShowingFullWorkout = true
    }

    // MARK: - Actions

    func startWorkout(routineID: UUID? = nil, sessionID: UUID? = nil, modelContext: ModelContext) {
        guard viewModel == nil else {
            isShowingFullWorkout = true
            return
        }
        let vm = ActiveWorkoutViewModel(
            modelContext:     modelContext,
            pendingRoutineID: routineID,
            pendingSessionID: sessionID,
            activityManager:  activityManager
        )
        // Write session ID to UserDefaults the moment the SwiftData session is created
        // (i.e. when the first set is logged). Direct callback — no SwiftUI observation chain.
        vm.onSessionCreated = { [weak self] id in
            self?.persistSessionID(id)
        }
        viewModel = vm
        isShowingFullWorkout = true
    }

    /// Called when the workout is finished or cancelled. Tears down the VM.
    func handleWorkoutEnded() {
        viewModel = nil
        isShowingFullWorkout = false
        // Clear the persisted session ID — workout is no longer in progress.
        persistSessionID(nil)
    }
}
