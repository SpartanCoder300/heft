// iOS 26+ only. No #available guards.

import BackgroundTasks
import Foundation
import SwiftData
import UIKit
import AudioToolbox
import UserNotifications

@Observable @MainActor
final class ActiveWorkoutViewModel {

    private struct PersistedDraftSet: Codable {
        var weightText: String
        var repsText: String
        var durationText: String
        var setType: SetType
        var isLogged: Bool
        var loggedRecordID: UUID?
        var isPR: Bool
        var isTouched: Bool

        init(weightText: String, repsText: String, durationText: String, setType: SetType, isLogged: Bool, loggedRecordID: UUID?, isPR: Bool, isTouched: Bool) {
            self.weightText = weightText; self.repsText = repsText; self.durationText = durationText
            self.setType = setType; self.isLogged = isLogged; self.loggedRecordID = loggedRecordID
            self.isPR = isPR; self.isTouched = isTouched
        }

        private enum CodingKeys: String, CodingKey {
            case weightText, repsText, durationText, setType, isLogged, loggedRecordID, isPR, isTouched
        }

        init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            weightText     = try c.decode(String.self,   forKey: .weightText)
            repsText       = try c.decode(String.self,   forKey: .repsText)
            durationText   = try c.decode(String.self,   forKey: .durationText)
            setType        = try c.decode(SetType.self,  forKey: .setType)
            isLogged       = try c.decode(Bool.self,     forKey: .isLogged)
            loggedRecordID = try c.decodeIfPresent(UUID.self, forKey: .loggedRecordID)
            isPR           = try c.decode(Bool.self,     forKey: .isPR)
            isTouched      = (try? c.decodeIfPresent(Bool.self, forKey: .isTouched)) ?? false
        }
    }

    // MARK: - Types

    struct DraftSet: Identifiable {
        var id = UUID()
        var weightText: String = ""
        var repsText: String = ""
        /// Seconds as a string, e.g. "30". Non-empty only when the parent exercise `isTimed`.
        var durationText: String = ""
        var setType: SetType = .normal
        var isLogged: Bool = false
        var loggedRecord: SetRecord? = nil
        var isPR: Bool = false
        /// True once the user has manually edited this set's values.
        /// Prefilled/default values start as false; propagation only writes to false sets.
        var isTouched: Bool = false
    }

    struct PreviousSet {
        var weight: Double
        var reps: Int
        var duration: Double? = nil
    }

    struct DraftExercise: Identifiable {
        var id = UUID()
        var exerciseDefinitionID: UUID? = nil
        var exerciseLineageID: UUID? = nil
        var exerciseName: String
        var equipmentType: String = ""
        var weightIncrement: Double = 2.5
        var startingWeight: Double = 45
        var loadTrackingMode: LoadTrackingMode = .externalWeight
        /// True when sets are measured by duration rather than reps (e.g. planks).
        var isTimed: Bool = false
        var sets: [DraftSet]
        var previousSets: [PreviousSet] = []
        var snapshot: ExerciseSnapshot? = nil
        var restSeconds: Int = 90

        var tracksWeight: Bool { loadTrackingMode != .none }
    }

    struct SetFocus: Equatable {
        let exerciseIndex: Int
        let setIndex: Int
    }

    /// Data surfaced to the PR moment overlay.
    struct PRMoment {
        let exerciseName: String
        let weight: Double
        let reps: Int
        let previousWeight: Double
        let previousReps: Int

        var formattedWeight: String {
            weight.truncatingRemainder(dividingBy: 1) == 0
                ? "\(Int(weight))" : String(format: "%.1f", weight)
        }

        /// e.g. "+10 lbs" or "+2 reps"
        var deltaText: String {
            if weight > previousWeight {
                let diff = weight - previousWeight
                let s = diff.truncatingRemainder(dividingBy: 1) == 0
                    ? "\(Int(diff))" : String(format: "%.1f", diff)
                return "+\(s) lbs"
            } else {
                let diff = reps - previousReps
                return "+\(diff) rep\(diff == 1 ? "" : "s")"
            }
        }
    }

    // MARK: - State

    var draftExercises: [DraftExercise] = []
    var openedAt: Date = .now
    private(set) var routineName: String = "Workout"
    var isShowingEndConfirm: Bool = false
    var isShowingExercisePicker: Bool = false
    var isShowingRestTimer: Bool = false
    /// Non-nil while the PR moment overlay is visible. Cleared by dismissPRMoment().
    private(set) var showingPRMoment: PRMoment? = nil

    private(set) var session: WorkoutSession? = nil
    /// Non-nil while the exercise picker is open in swap mode. Cleared on dismiss.
    private(set) var swappingExerciseIndex: Int? = nil
    let restTimer = RestTimerState()
    private(set) var lastLoggedFocus: SetFocus? = nil
    private(set) var lastLoggedExerciseIndex: Int? = nil
    private(set) var focusRevealRequestID = UUID()
    /// Set to the record ID of the most recently detected PR. Cleared after the celebration window.
    private(set) var lastPRSetID: UUID? = nil
    /// Rest duration stored when a PR is detected so it starts after the PR overlay is dismissed.
    private var pendingRestDuration: TimeInterval? = nil
    /// Best in-session max weight per exercise lineage. Written to ExerciseDefinition only on endWorkout().
    private var pendingMaxWeightByExercise: [UUID: Double] = [:]
    /// Best in-session reps at max weight per exercise lineage.
    private var pendingMaxRepsAtMaxWeightByExercise: [UUID: Int] = [:]
    /// True if at least one PR has been logged this session and would be lost on cancel.
    var hasPendingPRs: Bool { !pendingMaxWeightByExercise.isEmpty }

    var isSessionStarted: Bool { session != nil }

    /// Manual focus override — set when user taps a specific set row.
    /// Cleared automatically when that set gets logged.
    private var manualFocus: SetFocus? = nil

    // MARK: - Focus

    /// The currently focused set — manual override if valid, otherwise auto-advanced
    /// to the next unlogged set after the last one logged.
    var currentFocus: SetFocus? {
        if let mf = manualFocus,
           draftExercises.indices.contains(mf.exerciseIndex),
           draftExercises[mf.exerciseIndex].sets.indices.contains(mf.setIndex),
           !draftExercises[mf.exerciseIndex].sets[mf.setIndex].isLogged {
            return mf
        }
        return autoFocus
    }

    /// Next unlogged set after `lastLoggedFocus`, preserving the order the user
    /// is working through. Falls back to the first globally unlogged set only when
    /// no set has been logged yet.
    private var autoFocus: SetFocus? {
        let startEIdx = lastLoggedFocus?.exerciseIndex ?? 0
        let startSIdx = (lastLoggedFocus?.setIndex ?? -1) + 1

        for eIdx in startEIdx ..< draftExercises.count {
            let sets = draftExercises[eIdx].sets
            let firstS = eIdx == startEIdx ? min(startSIdx, sets.count) : 0
            if let sIdx = sets[firstS...].firstIndex(where: { !$0.isLogged }) {
                return SetFocus(exerciseIndex: eIdx, setIndex: sIdx)
            }
        }
        // Fall back: first globally unlogged set (covers initial state and wrap-around).
        for eIdx in draftExercises.indices {
            if let sIdx = draftExercises[eIdx].sets.firstIndex(where: { !$0.isLogged }) {
                return SetFocus(exerciseIndex: eIdx, setIndex: sIdx)
            }
        }
        return nil
    }

    func setManualFocus(exerciseIndex: Int, setIndex: Int) {
        guard draftExercises.indices.contains(exerciseIndex),
              draftExercises[exerciseIndex].sets.indices.contains(setIndex),
              !draftExercises[exerciseIndex].sets[setIndex].isLogged else { return }
        manualFocus = SetFocus(exerciseIndex: exerciseIndex, setIndex: setIndex)
        UISelectionFeedbackGenerator().selectionChanged()
        activityManager.update(currentActivityState)
    }

    func requestRevealCurrentFocus() {
        guard currentFocus != nil else { return }
        focusRevealRequestID = UUID()
    }

    /// Marks a set as user-touched and, when conditions allow, propagates set 0's
    /// values to all untouched future sets (no-history, no-logged-sets scenario only).
    func markSetTouched(exerciseIndex eIdx: Int, setIndex sIdx: Int) {
        guard draftExercises.indices.contains(eIdx),
              draftExercises[eIdx].sets.indices.contains(sIdx) else { return }
        draftExercises[eIdx].sets[sIdx].isTouched = true

        // Propagate every time set 0 is edited, while:
        // • the exercise has no prior session history (previousSets is empty)
        // • no sets in this exercise have been logged yet (first-time entry)
        guard sIdx == 0,
              draftExercises[eIdx].previousSets.isEmpty,
              !draftExercises[eIdx].sets.contains(where: { $0.isLogged }) else { return }
        propagateFromFirstSet(exerciseIndex: eIdx)
    }

    func queueDraftPersistence() {
        scheduleDraftPersistence()
    }

    private func propagateFromFirstSet(exerciseIndex eIdx: Int) {
        guard draftExercises.indices.contains(eIdx),
              !draftExercises[eIdx].sets.isEmpty else { return }
        let source = draftExercises[eIdx].sets[0]
        var propagated: [UUID] = []
        for sIdx in 1 ..< draftExercises[eIdx].sets.count {
            guard !draftExercises[eIdx].sets[sIdx].isTouched,
                  !draftExercises[eIdx].sets[sIdx].isLogged else { continue }
            draftExercises[eIdx].sets[sIdx].weightText   = source.weightText
            draftExercises[eIdx].sets[sIdx].repsText     = source.repsText
            draftExercises[eIdx].sets[sIdx].durationText = source.durationText
            propagated.append(draftExercises[eIdx].sets[sIdx].id)
        }
        _ = propagated
    }

    // MARK: - Private

    private let modelContext: ModelContext
    private let pendingRoutineID: UUID?
    private let pendingSessionID: UUID?
    private let resumeSessionID: UUID?
    private var zeroTask: Task<Void, Never>? = nil
    private var phaseUpdateTasks: [Task<Void, Never>] = []
    private var notificationTask: Task<Void, Never>? = nil
    private var deferredPersistTask: Task<Void, Never>? = nil
    private var hasSetup = false
    private let activityManager: WorkoutActivityManager

    private static var isRunningInPreview: Bool {
        let environment = ProcessInfo.processInfo.environment
        return environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
            || environment["XCODE_RUNNING_FOR_PLAYGROUNDS"] == "1"
    }

    /// Called once when the SwiftData session is first created (on first set logged).
    /// Set by ActiveWorkoutService to persist the session ID to UserDefaults directly —
    /// bypassing SwiftUI observation chains which are unreliable for cross-object chains.
    /// @ObservationIgnored — the callback itself doesn't need to be tracked.
    @ObservationIgnored var onSessionCreated: ((UUID) -> Void)?

    private func definition(id: UUID?) -> ExerciseDefinition? {
        guard let id else { return nil }
        let descriptor = FetchDescriptor<ExerciseDefinition>(predicate: #Predicate { $0.id == id })
        return (try? modelContext.fetch(descriptor))?.first
    }

    private func definition(lineageID: UUID?) -> ExerciseDefinition? {
        guard let lineageID else { return nil }
        let descriptor = FetchDescriptor<ExerciseDefinition>(predicate: #Predicate { $0.id == lineageID })
        return (try? modelContext.fetch(descriptor))?.first
    }

    private func definition(named name: String) -> ExerciseDefinition? {
        let descriptor = FetchDescriptor<ExerciseDefinition>(predicate: #Predicate { $0.name == name })
        return (try? modelContext.fetch(descriptor))?.first
    }

    // MARK: - Init

    init(
        modelContext: ModelContext,
        pendingRoutineID: UUID?,
        pendingSessionID: UUID? = nil,
        resumeSessionID: UUID? = nil,
        activityManager: WorkoutActivityManager = WorkoutActivityManager()
    ) {
        self.modelContext = modelContext
        self.pendingRoutineID = pendingRoutineID
        self.pendingSessionID = pendingSessionID
        self.resumeSessionID = resumeSessionID
        self.activityManager = activityManager
    }

    // MARK: - Setup

    func setup() {
        guard !hasSetup else { return }
        hasSetup = true
        if let sessionID = resumeSessionID {
            resumeSession(id: sessionID)
        } else if let routineID = pendingRoutineID {
            loadRoutine(id: routineID)
            for i in draftExercises.indices {
                applyPreviousPerformance(to: &draftExercises[i])
            }
            eagerlyPersistWorkout()
        } else if let sessionID = pendingSessionID {
            loadSession(id: sessionID)
            for i in draftExercises.indices {
                applyPreviousPerformance(to: &draftExercises[i])
            }
            eagerlyPersistWorkout()
        }
        persistDraftState()
        activityManager.start(sessionID: ensureSession().id, routineName: routineName, state: currentActivityState)
        requestNotificationPermissionIfNeeded()
    }

    /// Creates the WorkoutSession and an ExerciseSnapshot for every exercise immediately
    /// at workout start — before any set is logged. This ensures the full exercise list
    /// survives a force-quit or crash and can be restored on next launch.
    private func eagerlyPersistWorkout() {
        cancelDeferredPersistence()
        let s = ensureSession()
        for eIdx in draftExercises.indices {
            _ = ensureSnapshot(exerciseIndex: eIdx, session: s)
        }
        try? modelContext.save()
    }

    private func loadRoutine(id: UUID) {
        let descriptor = FetchDescriptor<RoutineTemplate>(
            predicate: #Predicate { $0.id == id }
        )
        guard let routine = (try? modelContext.fetch(descriptor))?.first else { return }

        routineName = routine.name
        routine.lastUsedAt = .now

        draftExercises = routine.entries
            .sorted { $0.order < $1.order }
            .compactMap { entry in
                guard let def = entry.exerciseDefinition else { return nil }
                let isTimed = def.isTimed
                let sets = (0 ..< entry.targetSets).map { _ -> DraftSet in
                    var s = DraftSet()
                    if isTimed {
                        s.durationText = "30"
                    } else {
                        s.repsText = "\(entry.targetRepsMin)"
                    }
                    return s
                }
                return DraftExercise(
                    exerciseDefinitionID: def.id,
                    exerciseLineageID: def.id,
                    exerciseName: def.name,
                    equipmentType: def.equipmentType,
                    weightIncrement: def.resolvedWeightIncrement,
                    startingWeight: def.resolvedStartingWeight,
                    loadTrackingMode: def.loadTrackingMode,
                    isTimed: isTimed,
                    sets: sets,
                    restSeconds: entry.restSeconds
                )
            }
    }

    /// Loads exercises from a past WorkoutSession so the user can repeat it exactly,
    /// even if it deviated from the original routine. applyPreviousPerformance then
    /// fills in the most recent weight/reps for each exercise.
    private func loadSession(id: UUID) {
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.id == id }
        )
        guard let session = (try? modelContext.fetch(descriptor))?.first else { return }
        draftExercises = session.exercises
            .sorted { $0.order < $1.order }
            .map { snap in
                let name = snap.exerciseName
                let def = definition(lineageID: snap.exerciseLineageID)
                    ?? definition(named: name)
                    ?? ExerciseSeeder.defaultDefinition(named: name)
                let isTimed = def?.isTimed ?? snap.isTimed
                let equipmentType = def?.equipmentType ?? snap.equipmentType ?? ""
                let loadTrackingMode = def?.loadTrackingMode ?? snap.loadTrackingMode
                // Start with one blank set; applyPreviousPerformance will expand and fill it.
                return DraftExercise(
                    exerciseDefinitionID: def?.id,
                    exerciseLineageID: snap.exerciseLineageID ?? def?.id,
                    exerciseName: name,
                    equipmentType: equipmentType,
                    weightIncrement: def?.resolvedWeightIncrement ?? snap.weightIncrement ?? ExerciseDefinition.defaultIncrement(for: equipmentType),
                    startingWeight: def?.resolvedStartingWeight ?? snap.startingWeight ?? ExerciseDefinition.defaultStartingWeight(for: equipmentType),
                    loadTrackingMode: loadTrackingMode,
                    isTimed: isTimed,
                    sets: [DraftSet()],
                    restSeconds: 90
                )
            }
    }

    /// Reconstructs in-memory workout state from a persisted incomplete WorkoutSession.
    /// Already-logged sets are marked isLogged, existing snapshots are attached,
    /// and a blank next set is appended to each exercise so logging can continue immediately.
    /// Exercises with no logged sets are restored using the routine template's target set
    /// count (if available), falling back to previous performance, then 1 blank set.
    private func resumeSession(id: UUID) {
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.id == id }
        )
        guard let s = (try? modelContext.fetch(descriptor))?.first else { return }

        // Attach the existing session so ensureSession() returns it without creating a new one.
        session = s
        openedAt = s.startedAt ?? .now

        // Pre-fetch the source routine (if any) so we can restore target set counts
        // for exercises that have no logged sets yet.
        var routineEntriesByName: [String: RoutineEntry] = [:]
        if let routineID = s.routineTemplateId {
            let rd = FetchDescriptor<RoutineTemplate>(predicate: #Predicate { $0.id == routineID })
            if let routine = (try? modelContext.fetch(rd))?.first {
                routineName = routine.name
                for entry in routine.entries {
                    if let name = entry.exerciseDefinition?.name {
                        routineEntriesByName[name] = entry
                    }
                }
            }
        }

        let sortedSnapshots = s.exercises.sorted { $0.order < $1.order }

        draftExercises = sortedSnapshots.map { snapshot in
            let name = snapshot.exerciseName
            let def = definition(lineageID: snapshot.exerciseLineageID)
                ?? definition(named: name)
                ?? ExerciseSeeder.defaultDefinition(named: name)
            let isTimed         = def?.isTimed ?? snapshot.isTimed
            let equipmentType   = def?.equipmentType ?? snapshot.equipmentType ?? ""
            let weightIncrement = def?.resolvedWeightIncrement ?? snapshot.weightIncrement ?? ExerciseDefinition.defaultIncrement(for: equipmentType)
            let startingWeight  = def?.resolvedStartingWeight ?? snapshot.startingWeight ?? ExerciseDefinition.defaultStartingWeight(for: equipmentType)
            let loadTrackingMode = def?.loadTrackingMode ?? snapshot.loadTrackingMode
            let restSeconds = snapshot.restSeconds ?? routineEntriesByName[name]?.restSeconds ?? 90

            // Reconstruct each persisted set as a logged DraftSet.
            let sortedRecords = snapshot.sets.sorted { $0.loggedAt < $1.loggedAt }
            if var restored = restorePersistedDraft(
                from: snapshot,
                sortedRecords: sortedRecords,
                exerciseName: name,
                exerciseDefinitionID: def?.id,
                exerciseLineageID: snapshot.exerciseLineageID ?? def?.id,
                equipmentType: equipmentType,
                weightIncrement: weightIncrement,
                startingWeight: startingWeight,
                loadTrackingMode: loadTrackingMode,
                isTimed: isTimed,
                restSeconds: restSeconds
            ) {
                applyPreviousPerformance(to: &restored)
                return restored
            }
            var draftSets: [DraftSet] = sortedRecords.map { record in
                var draft = DraftSet()
                if loadTrackingMode != .none {
                    draft.weightText = formatWeight(record.weight)
                }
                if isTimed {
                    draft.durationText = record.duration.map { "\(Int($0))" } ?? "0"
                } else {
                    draft.repsText = "\(record.reps)"
                }
                draft.setType     = record.setType
                draft.isLogged    = true
                draft.loggedRecord = record
                draft.isPR        = record.isPersonalRecord
                return draft
            }

            if sortedRecords.isEmpty {
                // No sets logged for this exercise — restore from the routine template
                // so the user sees the correct number of blank sets, not just one.
                let routineEntry = routineEntriesByName[name]
                let targetSets = routineEntry?.targetSets ?? 1
                let targetReps = routineEntry?.targetRepsMin ?? 0
                let restSecs   = routineEntry?.restSeconds ?? 90
                let sets = (0 ..< targetSets).map { _ -> DraftSet in
                    var set = DraftSet()
                    if !isTimed { set.repsText = targetReps > 0 ? "\(targetReps)" : "" }
                    return set
                }
                var exercise = DraftExercise(
                    exerciseDefinitionID: def?.id,
                    exerciseLineageID: snapshot.exerciseLineageID ?? def?.id,
                    exerciseName:    name,
                    equipmentType:   equipmentType,
                    weightIncrement: weightIncrement,
                    startingWeight:  startingWeight,
                    loadTrackingMode: loadTrackingMode,
                    isTimed:         isTimed,
                    sets:            sets,
                    snapshot:        snapshot,
                    restSeconds:     restSecs
                )
                applyPreviousPerformance(to: &exercise)
                return exercise
            }

            // Build a blank set seeded from the last logged set (weight/reps carry forward).
            var blankNext = DraftSet()
            if let last = sortedRecords.last {
                if loadTrackingMode != .none {
                    blankNext.weightText = formatWeight(last.weight)
                }
                if isTimed {
                    blankNext.durationText = last.duration.map { "\(Int($0))" } ?? "30"
                } else {
                    blankNext.repsText = "\(last.reps)"
                }
                // Warmup sets don't propagate forward.
                blankNext.setType = last.setType == .warmup ? .normal : last.setType
            }

            // Append enough blank sets to fill the routine's target count.
            // For ad-hoc exercises (no routine entry), keep 1 blank for optional logging.
            // For routine exercises, never exceed the target — a completed exercise should
            // resume with its logged sets only, not an extra phantom blank.
            let routineEntry = routineEntriesByName[name]
            let targetSets   = routineEntry?.targetSets ?? 0
            let blanksNeeded = targetSets > 0
                ? max(0, targetSets - sortedRecords.count)
                : 0
            for _ in 0 ..< blanksNeeded {
                var s = blankNext
                s.id = UUID()
                draftSets.append(s)
            }

            let routineRestSecs = routineEntriesByName[name]?.restSeconds ?? 90
            var exercise = DraftExercise(
                exerciseDefinitionID: def?.id,
                exerciseLineageID: snapshot.exerciseLineageID ?? def?.id,
                exerciseName:    name,
                equipmentType:   equipmentType,
                weightIncrement: weightIncrement,
                startingWeight:  startingWeight,
                loadTrackingMode: loadTrackingMode,
                isTimed:         isTimed,
                sets:            draftSets,
                snapshot:        snapshot,
                restSeconds:     routineRestSecs
            )
            applyPreviousPerformance(to: &exercise)
            return exercise
        }

        // Restore focus to the last logged set so autoFocus advances to the correct next set.
        outer: for eIdx in stride(from: draftExercises.count - 1, through: 0, by: -1) {
            let sets = draftExercises[eIdx].sets
            for sIdx in stride(from: sets.count - 1, through: 0, by: -1) {
                if sets[sIdx].isLogged {
                    lastLoggedFocus = SetFocus(exerciseIndex: eIdx, setIndex: sIdx)
                    lastLoggedExerciseIndex = eIdx
                    break outer
                }
            }
        }
    }

    private func applyPreviousPerformance(to exercise: inout DraftExercise) {
        let snapshotDescriptor: FetchDescriptor<ExerciseSnapshot>
        if let lineageID = exercise.exerciseLineageID {
            let name = exercise.exerciseName
            snapshotDescriptor = FetchDescriptor<ExerciseSnapshot>(
                predicate: #Predicate { $0.exerciseLineageID == lineageID || ($0.exerciseLineageID == nil && $0.exerciseName == name) }
            )
        } else {
            let name = exercise.exerciseName
            snapshotDescriptor = FetchDescriptor<ExerciseSnapshot>(
                predicate: #Predicate { $0.exerciseName == name }
            )
        }
        guard let all = try? modelContext.fetch(snapshotDescriptor) else { return }

        let completed = all
            .filter { $0.workoutSession?.completedAt != nil }
            .sorted {
                ($0.workoutSession?.completedAt ?? .distantPast) >
                ($1.workoutSession?.completedAt ?? .distantPast)
            }

        guard let latest = completed.first else {
            // No history — fill with sensible defaults so fields are never blank.
            applyDefaultValues(to: &exercise)
            return
        }

        let sortedSets = latest.sets.sorted { $0.loggedAt < $1.loggedAt }
        guard !sortedSets.isEmpty else {
            applyDefaultValues(to: &exercise)
            return
        }

        exercise.previousSets = sortedSets.map { PreviousSet(weight: $0.weight, reps: $0.reps, duration: $0.duration) }

        // If this exercise was added ad-hoc (starts with 1 blank set), expand to match
        // last session's set count so the user doesn't have to tap "Add Set" repeatedly.
        let isAdHoc = exercise.sets.allSatisfy { $0.weightText.isEmpty && !$0.isLogged }
        if isAdHoc && sortedSets.count > 1 {
            exercise.sets = sortedSets.map { _ in DraftSet() }
        }

        // Auto-fill: seed each draft set from the matching position, else last set.
        // Last session's actual reps/duration always win — more accurate than the routine target.
        for i in exercise.sets.indices {
            guard !exercise.sets[i].isLogged else { continue }
            let source = i < sortedSets.count ? sortedSets[i] : sortedSets[sortedSets.count - 1]
            if exercise.tracksWeight {
                exercise.sets[i].weightText = formatWeight(source.weight)
            }
            if exercise.isTimed {
                exercise.sets[i].durationText = source.duration.map { "\(Int($0))" } ?? "30"
            } else {
                exercise.sets[i].repsText = "\(source.reps)"
            }
            exercise.sets[i].setType = source.setType
        }
    }

    /// Fills empty fields with sensible defaults when no prior history exists.
    /// Uses the exercise's own startingWeight and generic rep/duration targets.
    private func applyDefaultValues(to exercise: inout DraftExercise) {
        for i in exercise.sets.indices {
            guard !exercise.sets[i].isLogged else { continue }
            if exercise.tracksWeight && exercise.sets[i].weightText.isEmpty {
                exercise.sets[i].weightText = formatWeight(exercise.startingWeight)
            }
            if exercise.isTimed {
                if exercise.sets[i].durationText.isEmpty {
                    exercise.sets[i].durationText = "30"
                }
            } else {
                let r = Int(exercise.sets[i].repsText) ?? 0
                if r == 0 { exercise.sets[i].repsText = "8" }
            }
            // isTouched stays false — these are app-provided defaults, not user input
        }
    }

    // MARK: - Mutations

    /// Clears swap mode without performing a swap (e.g. user cancelled the picker).
    func cancelSwap() {
        swappingExerciseIndex = nil
    }

    func beginSwap(exerciseIndex: Int) {
        guard draftExercises.indices.contains(exerciseIndex) else { return }
        swappingExerciseIndex = exerciseIndex
        isShowingExercisePicker = true
    }

    func swapExercise(at index: Int, named name: String) {
        swappingExerciseIndex = nil
        guard draftExercises.indices.contains(index) else { return }

        // If the outgoing exercise has an eagerly-created snapshot with no logged sets,
        // delete it — it's a placeholder that no longer represents any real data.
        if let oldSnapshot = draftExercises[index].snapshot, oldSnapshot.sets.isEmpty {
            modelContext.delete(oldSnapshot)
            try? modelContext.save()
        }

        let def = definition(named: name) ?? ExerciseSeeder.defaultDefinition(named: name)
        let equipmentType = def?.equipmentType ?? ""
        let weightIncrement = def?.resolvedWeightIncrement ?? ExerciseDefinition.defaultIncrement(for: equipmentType)
        let startingWeight = def?.resolvedStartingWeight ?? ExerciseDefinition.defaultStartingWeight(for: equipmentType)
        let loadTrackingMode = def?.loadTrackingMode ?? .externalWeight
        let isTimed = def?.isTimed ?? false
        // Preserve set count; clear logged state — new exercise starts fresh
        let setCount = max(1, draftExercises[index].sets.count)
        let sets = (0..<setCount).map { _ in DraftSet() }
        var replacement = DraftExercise(
            exerciseDefinitionID: def?.id,
            exerciseLineageID: def?.id,
            exerciseName: name,
            equipmentType: equipmentType,
            weightIncrement: weightIncrement,
            startingWeight: startingWeight,
            loadTrackingMode: loadTrackingMode,
            isTimed: isTimed,
            sets: sets
        )
        applyPreviousPerformance(to: &replacement)
        draftExercises[index] = replacement
        scheduleDraftPersistence()
        activityManager.update(currentActivityState)
        requestRevealCurrentFocus()
    }

    func syncDefinition(at index: Int) {
        guard draftExercises.indices.contains(index) else { return }
        let draft = draftExercises[index]
        guard let def = definition(id: draft.exerciseDefinitionID)
            ?? definition(lineageID: draft.exerciseLineageID)
            ?? definition(named: draft.exerciseName)
            ?? ExerciseSeeder.defaultDefinition(named: draft.exerciseName) else { return }
        draftExercises[index].exerciseDefinitionID = def.id
        draftExercises[index].exerciseLineageID = def.id
        draftExercises[index].exerciseName = def.name
        draftExercises[index].weightIncrement = def.resolvedWeightIncrement
        draftExercises[index].startingWeight = def.resolvedStartingWeight
        draftExercises[index].loadTrackingMode = def.loadTrackingMode
        draftExercises[index].equipmentType = def.equipmentType
        draftExercises[index].isTimed = def.isTimed
        scheduleDraftPersistence()
    }

    func addExercise(named name: String) {
        let def = definition(named: name) ?? ExerciseSeeder.defaultDefinition(named: name)
        let equipmentType = def?.equipmentType ?? ""
        let weightIncrement = def?.resolvedWeightIncrement ?? ExerciseDefinition.defaultIncrement(for: equipmentType)
        let startingWeight = def?.resolvedStartingWeight ?? ExerciseDefinition.defaultStartingWeight(for: equipmentType)
        let loadTrackingMode = def?.loadTrackingMode ?? .externalWeight
        let isTimed = def?.isTimed ?? false
        var draft = DraftExercise(
            exerciseDefinitionID: def?.id,
            exerciseLineageID: def?.id,
            exerciseName: name,
            equipmentType: equipmentType,
            weightIncrement: weightIncrement,
            startingWeight: startingWeight,
            loadTrackingMode: loadTrackingMode,
            isTimed: isTimed,
            sets: [DraftSet(), DraftSet(), DraftSet()]
        )
        applyPreviousPerformance(to: &draft)
        draftExercises.append(draft)
        scheduleDraftPersistence()
        UISelectionFeedbackGenerator().selectionChanged()
        activityManager.update(currentActivityState)
        requestRevealCurrentFocus()
    }

    /// Copies values from set 0 into the target set and focuses it.
    /// Called when the user taps a set that is showing a first-set placeholder.
    func adoptPlaceholderValues(exerciseIndex eIdx: Int, setIndex sIdx: Int) {
        guard draftExercises.indices.contains(eIdx),
              sIdx > 0,
              draftExercises[eIdx].sets.indices.contains(sIdx),
              !draftExercises[eIdx].sets[sIdx].isLogged else { return }
        let source = draftExercises[eIdx].sets[0]
        draftExercises[eIdx].sets[sIdx].weightText = source.weightText
        draftExercises[eIdx].sets[sIdx].repsText = source.repsText
        draftExercises[eIdx].sets[sIdx].durationText = source.durationText
        draftExercises[eIdx].sets[sIdx].isTouched = true
        scheduleDraftPersistence()
        setManualFocus(exerciseIndex: eIdx, setIndex: sIdx)
    }

    func copySetFromAbove(exerciseIndex eIdx: Int, setIndex sIdx: Int) {
        guard draftExercises.indices.contains(eIdx),
              sIdx > 0,
              draftExercises[eIdx].sets.indices.contains(sIdx),
              draftExercises[eIdx].sets.indices.contains(sIdx - 1),
              !draftExercises[eIdx].sets[sIdx].isLogged else { return }
        let above = draftExercises[eIdx].sets[sIdx - 1]
        draftExercises[eIdx].sets[sIdx].weightText = above.weightText
        draftExercises[eIdx].sets[sIdx].repsText = above.repsText
        draftExercises[eIdx].sets[sIdx].durationText = above.durationText
        draftExercises[eIdx].sets[sIdx].isTouched = true
        scheduleDraftPersistence()
        UISelectionFeedbackGenerator().selectionChanged()
        activityManager.update(currentActivityState)
        requestRevealCurrentFocus()
    }

    func removeSet(exerciseIndex eIdx: Int, setIndex sIdx: Int) {
        guard draftExercises.indices.contains(eIdx),
              draftExercises[eIdx].sets.indices.contains(sIdx),
              !draftExercises[eIdx].sets[sIdx].isLogged else { return }
        draftExercises[eIdx].sets.remove(at: sIdx)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        // If that was the last set, remove the exercise entirely to avoid a
        // zombie card with zero rows that isAllSetsLogged treats as complete.
        if draftExercises[eIdx].sets.isEmpty {
            removeExercise(at: eIdx)
            return
        }
        scheduleDraftPersistence()
        activityManager.update(currentActivityState)
    }

    func unlogSet(exerciseIndex eIdx: Int, setIndex sIdx: Int) {
        guard draftExercises.indices.contains(eIdx),
              draftExercises[eIdx].sets.indices.contains(sIdx),
              draftExercises[eIdx].sets[sIdx].isLogged else { return }

        let record = draftExercises[eIdx].sets[sIdx].loggedRecord
        let wasAPR = record?.isPersonalRecord ?? false

        // Remove the persisted SetRecord
        if let record {
            draftExercises[eIdx].snapshot?.sets.removeAll { $0.id == record.id }
            modelContext.delete(record)
        }

        draftExercises[eIdx].sets[sIdx].isLogged = false
        draftExercises[eIdx].sets[sIdx].loggedRecord = nil
        draftExercises[eIdx].sets[sIdx].isPR = false

        // If a PR was removed, recompute session max from remaining logged sets
        if wasAPR, let lineageID = draftExercises[eIdx].exerciseLineageID {
            recomputeSessionMax(exerciseIndex: eIdx, lineageID: lineageID)
        }

        cancelDeferredPersistence()
        persistDraftState()
        try? modelContext.save()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        activityManager.update(currentActivityState)
        requestRevealCurrentFocus()
    }

    func addSet(toExerciseAt index: Int) {
        guard draftExercises.indices.contains(index) else { return }
        var new = DraftSet()
        if let last = draftExercises[index].sets.last {
            new.weightText = last.weightText
            new.repsText = last.repsText
            new.durationText = last.durationText
            new.setType = last.setType
        }
        draftExercises[index].sets.append(new)
        scheduleDraftPersistence()
        UISelectionFeedbackGenerator().selectionChanged()
        activityManager.update(currentActivityState)
    }

    func removeExercise(at index: Int) {
        guard draftExercises.indices.contains(index) else { return }

        // Removing an exercise from an in-progress workout should remove its persisted draft
        // and any logged sets from this unfinished session so it cannot resurrect on resume.
        if let snapshot = draftExercises[index].snapshot {
            modelContext.delete(snapshot)
            try? modelContext.save()
        }

        // Clear any pending PR state so applyPendingPRs doesn't update the definition
        if let lineageID = draftExercises[index].exerciseLineageID {
            pendingMaxWeightByExercise.removeValue(forKey: lineageID)
            pendingMaxRepsAtMaxWeightByExercise.removeValue(forKey: lineageID)
        }

        draftExercises.remove(at: index)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        // Invalidate focus state that pointed into the removed (or now-shifted) exercise.
        if let lf = lastLoggedFocus {
            if lf.exerciseIndex == index { lastLoggedFocus = nil }
            else if lf.exerciseIndex > index { lastLoggedFocus = SetFocus(exerciseIndex: lf.exerciseIndex - 1, setIndex: lf.setIndex) }
        }
        if let mf = manualFocus {
            if mf.exerciseIndex == index { manualFocus = nil }
            else if mf.exerciseIndex > index { manualFocus = SetFocus(exerciseIndex: mf.exerciseIndex - 1, setIndex: mf.setIndex) }
        }
        cancelDeferredPersistence()
        persistDraftState()
        activityManager.update(currentActivityState)
    }

    /// Undo path for picker multi-add. Removes the most recent matching exercise that
    /// hasn't had any sets logged yet, so a picker correction can't silently delete
    /// work the user has already started.
    @discardableResult
    func removeMostRecentUnloggedExercise(named name: String) -> Bool {
        guard let index = draftExercises.indices.reversed().first(where: { idx in
            let exercise = draftExercises[idx]
            return exercise.exerciseName == name && exercise.sets.allSatisfy { !$0.isLogged }
        }) else { return false }

        removeExercise(at: index)
        return true
    }

    func moveExercise(at index: Int, direction: MoveDirection) {
        let target = direction == .up ? index - 1 : index + 1
        guard draftExercises.indices.contains(index),
              draftExercises.indices.contains(target) else { return }
        draftExercises.swapAt(index, target)
        scheduleDraftPersistence()
        activityManager.update(currentActivityState)
        requestRevealCurrentFocus()
    }

    enum MoveDirection { case up, down }

    func addDropset(toExerciseAt index: Int) {
        guard draftExercises.indices.contains(index) else { return }
        var dropset = DraftSet()
        dropset.setType = .dropset
        if let last = draftExercises[index].sets.last {
            dropset.weightText = last.weightText
            dropset.repsText = last.repsText
            dropset.durationText = last.durationText
        }
        draftExercises[index].sets.append(dropset)
        scheduleDraftPersistence()
        activityManager.update(currentActivityState)
        requestRevealCurrentFocus()
    }

    func logSet(exerciseIndex eIdx: Int, setIndex sIdx: Int) {
        guard draftExercises.indices.contains(eIdx),
              draftExercises[eIdx].sets.indices.contains(sIdx),
              !draftExercises[eIdx].sets[sIdx].isLogged else { return }

        let draft = draftExercises[eIdx].sets[sIdx]
        let exercise = draftExercises[eIdx]
        let isTimed = exercise.isTimed
        let tracksWeight = exercise.tracksWeight
        let weight = tracksWeight ? (Double(draft.weightText) ?? 0) : 0
        let reps = isTimed ? 0 : (Int(draft.repsText) ?? 0)
        let duration: Double? = isTimed ? Double(draft.durationText) : nil

        let currentSession = ensureSession()
        let snapshot = ensureSnapshot(exerciseIndex: eIdx, session: currentSession)

        let record = SetRecord(
            weight: weight,
            reps: reps,
            setType: draft.setType,
            duration: duration,
            exerciseSnapshot: snapshot
        )
        modelContext.insert(record)
        snapshot.sets.append(record)

        // PR check skipped for timed exercises — duration-based PRs aren't tracked here
        let prMoment: PRMoment?
        if draft.setType != .warmup && !isTimed {
            prMoment = checkPR(
                exerciseLineageID: draftExercises[eIdx].exerciseLineageID,
                exerciseName: draftExercises[eIdx].exerciseName,
                weight: weight,
                reps: reps,
                record: record
            )
        } else {
            prMoment = nil
        }

        draftExercises[eIdx].sets[sIdx].isLogged = true
        draftExercises[eIdx].sets[sIdx].loggedRecord = record
        lastLoggedFocus = SetFocus(exerciseIndex: eIdx, setIndex: sIdx)
        lastLoggedExerciseIndex = eIdx

        // After loggedRecord is assigned, surface the PR so the view can animate
        if let moment = prMoment {
            draftExercises[eIdx].sets[sIdx].isPR = true
            lastPRSetID = record.id
            showingPRMoment = moment
            firePRCelebration()
        }

        // Propagate weight + reps/duration forward to subsequent blank sets in the same exercise
        for i in draftExercises[eIdx].sets.indices where i > sIdx {
            guard !draftExercises[eIdx].sets[i].isLogged else { continue }
            if isTimed {
                let isBlank = draftExercises[eIdx].sets[i].durationText.isEmpty ||
                              draftExercises[eIdx].sets[i].durationText == "0"
                guard isBlank else { continue }
                draftExercises[eIdx].sets[i].durationText = draft.durationText
            } else {
                if tracksWeight {
                    let isBlank = draftExercises[eIdx].sets[i].weightText.isEmpty ||
                                  draftExercises[eIdx].sets[i].weightText == "0"
                    guard isBlank else { continue }
                    draftExercises[eIdx].sets[i].weightText = draft.weightText
                } else {
                    let isBlank = draftExercises[eIdx].sets[i].repsText.isEmpty ||
                                  draftExercises[eIdx].sets[i].repsText == "0"
                    guard isBlank else { continue }
                }
                draftExercises[eIdx].sets[i].repsText = draft.repsText
            }
        }

        // Clear manual focus — auto-advance takes over
        manualFocus = nil

        cancelDeferredPersistence()
        persistDraftState()
        try? modelContext.save()
        activityManager.update(currentActivityState)

        if !isAllSetsLogged {
            if prMoment == nil {
                // Haptic is handled in AppView (onChange loggedSetCount) so it can
                // distinguish exercise-complete from single-set. Don't fire here.
                startRestTimer(duration: TimeInterval(draftExercises[eIdx].restSeconds))
            } else {
                // Rest timer deferred — starts when the PR overlay is dismissed
                pendingRestDuration = TimeInterval(draftExercises[eIdx].restSeconds)
            }
        }
        requestRevealCurrentFocus()
    }

    /// Logs the currently focused set. Returns true if a set was logged.
    @discardableResult
    func logFocusedSet() -> Bool {
        guard let focus = currentFocus else { return false }
        logSet(exerciseIndex: focus.exerciseIndex, setIndex: focus.setIndex)
        return true
    }

    // MARK: - Rest notification (local fallback for when app is fully suspended)
    // AlertConfiguration handles the banner when the app can deliver it (backgrounded but not
    // suspended). The local notification is the reliable fallback for when the phone is fully
    // asleep — it is delivered by the system daemon independently of the app.
    // Coordination: zeroTask cancels the notification before calling updateRestComplete,
    // so only one alert fires when the app is not fully suspended.

    private let restNotificationID = "restTimerComplete"

    func requestNotificationPermissionIfNeeded() {
        Task {
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()
            guard settings.authorizationStatus == .notDetermined else { return }
            _ = try? await center.requestAuthorization(options: [.alert, .sound])
        }
    }

    func scheduleRestNotification(endsAt: Date, exerciseName: String) {
        notificationTask?.cancel()
        notificationTask = Task {
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()
            guard case .authorized = settings.authorizationStatus else { return }
            guard !Task.isCancelled else { return }
            let interval = endsAt.timeIntervalSinceNow
            guard interval > 0 else { return }
            let content = UNMutableNotificationContent()
            content.title = "Rest Complete"
            content.body = exerciseName
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            let request = UNNotificationRequest(identifier: restNotificationID, content: content, trigger: trigger)
            center.removePendingNotificationRequests(withIdentifiers: [restNotificationID])
            try? await center.add(request)
        }
    }

    func cancelRestNotification() {
        notificationTask?.cancel()
        notificationTask = nil
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [restNotificationID])
        center.removeDeliveredNotifications(withIdentifiers: [restNotificationID])
    }

    private static let restBGTaskID = "MysticByte.Orin.rest-timer-end"

    /// Schedules a BGAppRefreshTask to fire at the rest timer's end date.
    /// If the app is suspended when the timer fires, the system wakes it briefly
    /// so the task handler can push a "rest cleared" Live Activity update.
    /// Submitting with the same identifier replaces any previously scheduled request.
    private func scheduleRestBackgroundRefresh(endsAt: Date) {
        guard !Self.isRunningInPreview else { return }
        let request = BGAppRefreshTaskRequest(identifier: Self.restBGTaskID)
        request.earliestBeginDate = endsAt
        try? BGTaskScheduler.shared.submit(request)
    }

    private func cancelRestBackgroundRefresh() {
        guard !Self.isRunningInPreview else { return }
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.restBGTaskID)
    }

    /// Cancels the zero-task and all phase-update tasks without rescheduling.
    /// Use when stopping the rest timer (skip, clamp-to-zero, workout end).
    private func cancelTimerTasks() {
        zeroTask?.cancel()
        zeroTask = nil
        phaseUpdateTasks.forEach { $0.cancel() }
        phaseUpdateTasks.removeAll()
    }

    /// Cancels then reschedules the zero-task and phase-update tasks for the given deadline.
    /// Called from both startRestTimer and adjustRest so adjust never leaves stale tasks running.
    private func scheduleTimerTasks(deadline: Date, duration: TimeInterval) {
        cancelTimerTasks()

        // Clear the timer when it expires.
        zeroTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let delay = deadline.timeIntervalSinceNow
            if delay > 0 { try? await Task.sleep(for: .seconds(delay)) }
            guard !Task.isCancelled else { return }
            self.cancelRestNotification()
            self.restTimer.tick(at: .now)
            self.activityManager.updateRestComplete(self.currentActivityState)
        }

        // Push Live Activity updates at the 50% and 20% remaining-time thresholds so the
        // phase colour (green → amber → red) transitions without requiring user interaction.
        // Delays are computed from now so they remain correct after adjustRest is called.
        let currentRemaining = max(0, deadline.timeIntervalSinceNow)
        for threshold in [0.5, 0.2] {
            let delay = currentRemaining - threshold * duration
            guard delay > 0 else { continue }
            let t = Task { @MainActor [weak self] in
                guard let self else { return }
                try? await Task.sleep(for: .seconds(delay))
                guard !Task.isCancelled, self.restTimer.isActive else { return }
                self.activityManager.update(self.currentActivityState)
            }
            phaseUpdateTasks.append(t)
        }
    }

    func startRestTimer(duration: TimeInterval) {
        restTimer.start(duration: duration)
        activityManager.update(currentActivityState)
        guard let deadline = restTimer.targetEndDate else { return }
        scheduleTimerTasks(deadline: deadline, duration: duration)
        scheduleRestBackgroundRefresh(endsAt: deadline)
        let exerciseName = currentFocus.flatMap { draftExercises.indices.contains($0.exerciseIndex) ? draftExercises[$0.exerciseIndex].exerciseName : nil } ?? routineName
        scheduleRestNotification(endsAt: deadline, exerciseName: exerciseName)
    }

    func skipRest() {
        cancelTimerTasks()
        restTimer.skip()
        scheduleDraftPersistence()
        cancelRestBackgroundRefresh()
        cancelRestNotification()
        activityManager.update(currentActivityState)
    }

    func adjustRest(by seconds: TimeInterval) {
        restTimer.adjust(seconds: seconds)
        guard restTimer.isActive, let deadline = restTimer.targetEndDate else {
            // Adjustment clamped the timer to zero — treat as a skip.
            cancelTimerTasks()
            scheduleDraftPersistence()
            cancelRestBackgroundRefresh()
            cancelRestNotification()
            activityManager.update(currentActivityState)
            return
        }
        scheduleTimerTasks(deadline: deadline, duration: restTimer.totalDuration)
        scheduleRestBackgroundRefresh(endsAt: deadline)
        let exerciseName = currentFocus.flatMap { draftExercises.indices.contains($0.exerciseIndex) ? draftExercises[$0.exerciseIndex].exerciseName : nil } ?? routineName
        scheduleRestNotification(endsAt: deadline, exerciseName: exerciseName)
        scheduleDraftPersistence()
        activityManager.update(currentActivityState)
    }

    func cycleSetType(exerciseIndex eIdx: Int, setIndex sIdx: Int) {
        guard draftExercises.indices.contains(eIdx),
              draftExercises[eIdx].sets.indices.contains(sIdx) else { return }
        // Set type cycling not yet implemented — all sets stay normal
        scheduleDraftPersistence()
    }

    func adjustWeight(exerciseIndex eIdx: Int, setIndex sIdx: Int, increment: Bool) {
        guard draftExercises.indices.contains(eIdx),
              draftExercises[eIdx].sets.indices.contains(sIdx) else { return }
        guard draftExercises[eIdx].tracksWeight else { return }
        let step = draftExercises[eIdx].weightIncrement
        let current = Double(draftExercises[eIdx].sets[sIdx].weightText) ?? 0
        if increment && current == 0 {
            let start = draftExercises[eIdx].startingWeight
            draftExercises[eIdx].sets[sIdx].weightText = formatWeight(start)
            scheduleDraftPersistence()
            activityManager.update(currentActivityState)
            return
        }
        let next = increment ? current + step : max(0, current - step)
        draftExercises[eIdx].sets[sIdx].weightText = formatWeight(next)
        scheduleDraftPersistence()
        activityManager.update(currentActivityState)
    }

    func adjustReps(exerciseIndex eIdx: Int, setIndex sIdx: Int, increment: Bool) {
        guard draftExercises.indices.contains(eIdx),
              draftExercises[eIdx].sets.indices.contains(sIdx) else { return }
        let current = Int(draftExercises[eIdx].sets[sIdx].repsText) ?? 0
        let next = increment ? current + 1 : max(0, current - 1)
        draftExercises[eIdx].sets[sIdx].repsText = "\(next)"
        scheduleDraftPersistence()
        activityManager.update(currentActivityState)
    }

    var loggedSetCount: Int {
        draftExercises.flatMap { $0.sets }.filter { $0.isLogged }.count
    }

    /// The next unlogged set for the rest timer card — same position as `autoFocus`
    /// so the command bar and rest timer always agree on what's coming next.
    var nextUnloggedFocus: (exerciseIndex: Int, setIndex: Int, weightText: String, repsText: String, durationText: String, isTimed: Bool, tracksWeight: Bool, exerciseName: String, totalSets: Int)? {
        guard let f = autoFocus,
              draftExercises.indices.contains(f.exerciseIndex),
              draftExercises[f.exerciseIndex].sets.indices.contains(f.setIndex)
        else { return nil }
        let set = draftExercises[f.exerciseIndex].sets[f.setIndex]
        let exercise = draftExercises[f.exerciseIndex]
        return (
            exerciseIndex: f.exerciseIndex,
            setIndex: f.setIndex,
            weightText: set.weightText,
            repsText: set.repsText,
            durationText: set.durationText,
            isTimed: exercise.isTimed,
            tracksWeight: exercise.tracksWeight,
            exerciseName: exercise.exerciseName,
            totalSets: exercise.sets.count
        )
    }

    /// True when every set across all exercises is logged. Drives auto-complete.
    /// Requires each exercise to have at least one set — empty exercises are never "done".
    var isAllSetsLogged: Bool {
        !draftExercises.isEmpty &&
        draftExercises.allSatisfy { !$0.sets.isEmpty && $0.sets.allSatisfy { $0.isLogged } }
    }

    @discardableResult
    func endWorkout() -> WorkoutSession? {
        guard let s = session else { return nil }
        cancelDeferredPersistence()
        s.completedAt = .now
        applyPendingPRs()
        // Drop any exercises the user added but never logged a set for.
        for snapshot in s.exercises where snapshot.sets.isEmpty {
            modelContext.delete(snapshot)
        }
        try? modelContext.save()
        cancelRestBackgroundRefresh()
        cancelRestNotification()
        activityManager.end(currentActivityState)

        let sessionID = s.persistentModelID
        let container = modelContext.container
        Task.detached {
            await SessionService(modelContainer: container).upsertWeeklySnapshot(for: sessionID)
        }

        return s
    }

    private func applyPendingPRs() {
        for (lineageID, newMaxWeight) in pendingMaxWeightByExercise {
            guard let def = definition(lineageID: lineageID) else { continue }
            let newMaxReps = pendingMaxRepsAtMaxWeightByExercise[lineageID] ?? 0
            if newMaxWeight > def.maxWeight {
                def.maxWeight = newMaxWeight
                def.maxRepsAtMaxWeight = newMaxReps
            } else if newMaxWeight == def.maxWeight {
                def.maxRepsAtMaxWeight = max(def.maxRepsAtMaxWeight, newMaxReps)
            }
            def.prDate = .now
        }
        pendingMaxWeightByExercise.removeAll()
        pendingMaxRepsAtMaxWeightByExercise.removeAll()
    }

    /// Discards the in-progress session and all logged sets without saving.
    func cancelWorkout() {
        cancelDeferredPersistence()
        cancelRestBackgroundRefresh()
        cancelRestNotification()
        activityManager.end(currentActivityState)
        if let s = session {
            modelContext.delete(s)
            try? modelContext.save()
        }
    }

    // MARK: - Helpers

    func elapsedLabel(at date: Date) -> String {
        let e = max(0, Int(date.timeIntervalSince(openedAt)))
        return String(format: "%d:%02d", e / 60, e % 60)
    }

    func formatWeight(_ v: Double) -> String {
        String(format: "%.1f", (v * 10).rounded() / 10)
    }

    /// Dismisses the PR moment overlay and starts the deferred rest timer.
    func dismissPRMoment() {
        showingPRMoment = nil
        if let duration = pendingRestDuration {
            startRestTimer(duration: duration)
            pendingRestDuration = nil
        }
    }

    // MARK: - Private helpers

    private var currentActivityState: WorkoutActivityAttributes.ContentState {
        let exercise: String
        let focusedSetLabel: String?
        let focusedSetDetail: String?
        let focusedSetNumber: Int?
        let exerciseSetCount: Int?
        if let focus = currentFocus, draftExercises.indices.contains(focus.exerciseIndex) {
            let draftExercise = draftExercises[focus.exerciseIndex]
            let draftSet = draftExercise.sets[focus.setIndex]
            exercise = draftExercise.exerciseName
            focusedSetNumber = focus.setIndex + 1
            exerciseSetCount = draftExercise.sets.count
            focusedSetLabel = "Set \(focusedSetNumber!) of \(exerciseSetCount!)"
            if draftExercise.isTimed, !draftSet.durationText.isEmpty {
                if draftExercise.tracksWeight, !draftSet.weightText.isEmpty {
                    focusedSetDetail = "\(draftSet.weightText) lb · \(draftSet.durationText)s"
                } else {
                    focusedSetDetail = "\(draftSet.durationText)s"
                }
            } else {
                let weight = draftSet.weightText
                let reps = draftSet.repsText
                if draftExercise.tracksWeight && !weight.isEmpty && !reps.isEmpty {
                    focusedSetDetail = "\(weight) × \(reps)"
                } else if !reps.isEmpty {
                    focusedSetDetail = "\(reps) reps"
                } else if draftExercise.tracksWeight && !weight.isEmpty {
                    focusedSetDetail = "\(weight)"
                } else {
                    focusedSetDetail = nil
                }
            }
        } else {
            exercise = draftExercises.first?.exerciseName ?? routineName
            focusedSetLabel = nil
            focusedSetDetail = nil
            focusedSetNumber = nil
            exerciseSetCount = nil
        }
        let accent = AccentTheme.currentAccentRGB
        let totalSetCount = draftExercises.reduce(0) { $0 + $1.sets.count }
        return WorkoutActivityAttributes.ContentState(
            startedAt: session?.startedAt ?? openedAt,
            currentExercise: exercise,
            setsLogged: loggedSetCount,
            totalSetCount: totalSetCount,
            focusedSetLabel: focusedSetLabel,
            focusedSetDetail: focusedSetDetail,
            focusedSetNumber: focusedSetNumber,
            exerciseSetCount: exerciseSetCount,
            restEndsAt: restTimer.targetEndDate,
            totalRestDuration: restTimer.isActive ? restTimer.totalDuration : nil,
            accentR: accent.r,
            accentG: accent.g,
            accentB: accent.b
        )
    }

    /// Pushes a fresh activity state update — call when the user switches themes
    /// so the Live Activity reflects the new accent colour immediately.
    func refreshActivityState() {
        activityManager.update(currentActivityState)
    }

    /// Call when the app returns to the foreground. Clears any rest timer that expired
    /// while the app was suspended — the zeroTask can't fire during suspension, so this
    /// ensures the Live Activity and in-app state are both updated immediately on resume.
    func handleForeground() {
        cancelDeferredPersistence()
        persistDraftState()
        guard restTimer.isActive, let end = restTimer.targetEndDate, end <= .now else { return }
        cancelTimerTasks()
        cancelRestNotification()
        restTimer.tick(at: .now)
        persistDraftState()
        activityManager.update(currentActivityState)
    }

    private func scheduleDraftPersistence(delay: Duration = .milliseconds(300)) {
        guard hasSetup else { return }
        deferredPersistTask?.cancel()
        deferredPersistTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: delay)
            } catch {
                return
            }
            guard let self, !Task.isCancelled else { return }
            self.persistDraftState()
            self.deferredPersistTask = nil
        }
    }

    private func cancelDeferredPersistence() {
        deferredPersistTask?.cancel()
        deferredPersistTask = nil
    }

    func persistDraftState() {
        guard hasSetup else { return }
        deferredPersistTask = nil
        if draftExercises.isEmpty {
            try? modelContext.save()
            return
        }

        let currentSession = ensureSession()
        var retainedSnapshotIDs = Set<UUID>()

        for eIdx in draftExercises.indices {
            let snapshot = ensureSnapshot(exerciseIndex: eIdx, session: currentSession)
            retainedSnapshotIDs.insert(snapshot.id)
            syncSnapshot(snapshot, from: draftExercises[eIdx], order: eIdx)
        }

        for snapshot in currentSession.exercises where !retainedSnapshotIDs.contains(snapshot.id) {
            modelContext.delete(snapshot)
        }

        try? modelContext.save()
    }

    private func ensureSession() -> WorkoutSession {
        if let s = session { return s }
        let s = WorkoutSession(startedAt: openedAt, routineTemplateId: pendingRoutineID)
        modelContext.insert(s)
        session = s
        onSessionCreated?(s.id)
        return s
    }

    private func ensureSnapshot(exerciseIndex eIdx: Int, session: WorkoutSession) -> ExerciseSnapshot {
        if let existing = draftExercises[eIdx].snapshot { return existing }
        let snap = ExerciseSnapshot(
            exerciseName: draftExercises[eIdx].exerciseName,
            exerciseLineageID: draftExercises[eIdx].exerciseLineageID,
            equipmentType: draftExercises[eIdx].equipmentType,
            weightIncrement: draftExercises[eIdx].weightIncrement,
            startingWeight: draftExercises[eIdx].startingWeight,
            loadTrackingModeRaw: draftExercises[eIdx].loadTrackingMode.rawValue,
            isTimed: draftExercises[eIdx].isTimed,
            restSeconds: draftExercises[eIdx].restSeconds,
            order: eIdx,
            workoutSession: session
        )
        modelContext.insert(snap)
        session.exercises.append(snap)
        draftExercises[eIdx].snapshot = snap
        return snap
    }

    private func syncSnapshot(_ snapshot: ExerciseSnapshot, from exercise: DraftExercise, order: Int) {
        snapshot.exerciseName = exercise.exerciseName
        snapshot.exerciseLineageID = exercise.exerciseLineageID
        snapshot.equipmentType = exercise.equipmentType
        snapshot.weightIncrement = exercise.weightIncrement
        snapshot.startingWeight = exercise.startingWeight
        snapshot.loadTrackingMode = exercise.loadTrackingMode
        snapshot.isTimed = exercise.isTimed
        snapshot.restSeconds = exercise.restSeconds
        snapshot.order = order
        snapshot.draftStateJSON = encodeDraftState(exercise.sets)
    }

    private func encodeDraftState(_ sets: [DraftSet]) -> String? {
        let payload = sets.map {
            PersistedDraftSet(
                weightText: $0.weightText,
                repsText: $0.repsText,
                durationText: $0.durationText,
                setType: $0.setType,
                isLogged: $0.isLogged,
                loggedRecordID: $0.loggedRecord?.id,
                isPR: $0.isPR,
                isTouched: $0.isTouched
            )
        }
        guard let data = try? JSONEncoder().encode(payload) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func decodeDraftState(from snapshot: ExerciseSnapshot) -> [PersistedDraftSet]? {
        guard let json = snapshot.draftStateJSON,
              let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode([PersistedDraftSet].self, from: data)
    }

    private func restorePersistedDraft(
        from snapshot: ExerciseSnapshot,
        sortedRecords: [SetRecord],
        exerciseName: String,
        exerciseDefinitionID: UUID?,
        exerciseLineageID: UUID?,
        equipmentType: String,
        weightIncrement: Double,
        startingWeight: Double,
        loadTrackingMode: LoadTrackingMode,
        isTimed: Bool,
        restSeconds: Int
    ) -> DraftExercise? {
        guard let persistedSets = decodeDraftState(from: snapshot) else { return nil }
        let recordsByID = Dictionary(uniqueKeysWithValues: sortedRecords.map { ($0.id, $0) })

        let sets = persistedSets.map { persisted -> DraftSet in
            var draft = DraftSet()
            draft.weightText = persisted.weightText
            draft.repsText = persisted.repsText
            draft.durationText = persisted.durationText
            draft.setType = persisted.setType
            draft.isLogged = persisted.isLogged
            if let recordID = persisted.loggedRecordID {
                draft.loggedRecord = recordsByID[recordID]
            }
            draft.isPR = persisted.isPR || draft.loggedRecord?.isPersonalRecord == true
            // Restore touched state. For non-logged sets with values, treat as touched
            // to prevent propagation from overwriting established values on resume.
            draft.isTouched = persisted.isTouched || (!persisted.isLogged && (
                !persisted.weightText.isEmpty || !persisted.repsText.isEmpty || !persisted.durationText.isEmpty
            ))
            return draft
        }

        return DraftExercise(
            exerciseDefinitionID: exerciseDefinitionID,
            exerciseLineageID: exerciseLineageID,
            exerciseName: exerciseName,
            equipmentType: equipmentType,
            weightIncrement: weightIncrement,
            startingWeight: startingWeight,
            loadTrackingMode: loadTrackingMode,
            isTimed: isTimed,
            sets: sets.isEmpty ? [DraftSet()] : sets,
            snapshot: snapshot,
            restSeconds: restSeconds
        )
    }

    private func checkPR(exerciseLineageID: UUID?, exerciseName: String, weight: Double, reps: Int, record: SetRecord) -> PRMoment? {
        guard let def = definition(lineageID: exerciseLineageID) ?? definition(named: exerciseName) else { return nil }
        let lineageID = def.id

        // Read prior session best before updating, so comparison excludes the current set
        let sessionMaxWeight = pendingMaxWeightByExercise[lineageID] ?? 0
        let sessionMaxReps = pendingMaxRepsAtMaxWeightByExercise[lineageID] ?? 0

        // Always track session best so applyPendingPRs can seed def.maxWeight on workout end,
        // even when no PR fires (e.g. first workout for this exercise)
        if weight > sessionMaxWeight {
            pendingMaxWeightByExercise[lineageID] = weight
            pendingMaxRepsAtMaxWeightByExercise[lineageID] = reps
        } else if weight == sessionMaxWeight, reps > sessionMaxReps {
            pendingMaxRepsAtMaxWeightByExercise[lineageID] = reps
        }

        // No history → no PR
        guard def.maxWeight > 0 else { return nil }

        // Effective best: persisted + prior session sets (read before update above)
        let allTimeMaxWeight: Double
        let allTimeMaxReps: Int
        if sessionMaxWeight > def.maxWeight {
            allTimeMaxWeight = sessionMaxWeight
            allTimeMaxReps = sessionMaxReps
        } else if sessionMaxWeight == def.maxWeight {
            allTimeMaxWeight = def.maxWeight
            allTimeMaxReps = max(def.maxRepsAtMaxWeight, sessionMaxReps)
        } else {
            allTimeMaxWeight = def.maxWeight
            allTimeMaxReps = def.maxRepsAtMaxWeight
        }

        var isPR = false
        if weight > allTimeMaxWeight {
            isPR = true
        } else if weight == allTimeMaxWeight && reps > allTimeMaxReps {
            isPR = true
        }
        guard isPR else { return nil }

        record.isPersonalRecord = true
        return PRMoment(
            exerciseName: exerciseName,
            weight: weight,
            reps: reps,
            previousWeight: allTimeMaxWeight,
            previousReps: allTimeMaxReps
        )
    }

    /// Recomputes session max weight/reps for an exercise from its currently logged sets.
    /// Called after unlogging a PR set so future PR checks use the correct baseline.
    private func recomputeSessionMax(exerciseIndex eIdx: Int, lineageID: UUID) {
        var newMaxWeight: Double = 0
        var newMaxReps: Int = 0
        for set in draftExercises[eIdx].sets {
            guard set.isLogged, set.setType != .warmup, let record = set.loggedRecord else { continue }
            if record.weight > newMaxWeight {
                newMaxWeight = record.weight
                newMaxReps = record.reps
            } else if record.weight == newMaxWeight, record.reps > newMaxReps {
                newMaxReps = record.reps
            }
        }
        if newMaxWeight > 0 {
            pendingMaxWeightByExercise[lineageID] = newMaxWeight
            pendingMaxRepsAtMaxWeightByExercise[lineageID] = newMaxReps
        } else {
            pendingMaxWeightByExercise.removeValue(forKey: lineageID)
            pendingMaxRepsAtMaxWeightByExercise.removeValue(forKey: lineageID)
        }
    }

    private func firePRCelebration() {
        // 1. Success notification haptic — the primary tactile reward
        let notification = UINotificationFeedbackGenerator()
        notification.prepare()
        notification.notificationOccurred(.success)

        // 2. Apple Pay–style success chime
        AudioServicesPlaySystemSound(SystemSoundID(1322))

        // 3. Secondary heavy impact 120ms later for extra punch
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(120))
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }

        // 4. Clear the PR animation trigger after the celebration window
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            lastPRSetID = nil
        }
    }
}
