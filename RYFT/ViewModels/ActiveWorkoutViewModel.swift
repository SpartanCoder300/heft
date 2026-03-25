// iOS 26+ only. No #available guards.

import Foundation
import SwiftData
import UIKit
import AudioToolbox

@Observable @MainActor
final class ActiveWorkoutViewModel {

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
    }

    struct PreviousSet {
        var weight: Double
        var reps: Int
        var duration: Double? = nil
    }

    struct DraftExercise: Identifiable {
        var id = UUID()
        var exerciseName: String
        var equipmentType: String = ""
        var weightIncrement: Double = 2.5
        /// True when sets are measured by duration rather than reps (e.g. planks).
        var isTimed: Bool = false
        var sets: [DraftSet]
        var previousSets: [PreviousSet] = []
        var snapshot: ExerciseSnapshot? = nil
        var restSeconds: Int = 90
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
        let estimatedOneRepMax: Double

        var formattedWeight: String {
            weight.truncatingRemainder(dividingBy: 1) == 0
                ? "\(Int(weight))" : String(format: "%.1f", weight)
        }
        var formattedE1RM: String { "\(Int(estimatedOneRepMax.rounded()))" }
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
    /// Set to the record ID of the most recently detected PR. Cleared after the celebration window.
    private(set) var lastPRSetID: UUID? = nil
    /// Rest duration stored when a PR is detected so it starts after the PR overlay is dismissed.
    private var pendingRestDuration: TimeInterval? = nil
    /// Best in-session e1RM per exercise name. Written to ExerciseDefinition only on endWorkout().
    private var pendingPRByExercise: [String: Double] = [:]
    /// True if at least one PR has been logged this session and would be lost on cancel.
    var hasPendingPRs: Bool { !pendingPRByExercise.isEmpty }

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
    }

    // MARK: - Private

    private let modelContext: ModelContext
    private let pendingRoutineID: UUID?
    private let pendingSessionID: UUID?
    private let resumeSessionID: UUID?
    private var zeroTask: Task<Void, Never>? = nil
    private var phaseUpdateTasks: [Task<Void, Never>] = []
    private var hasSetup = false
    private let activityManager: WorkoutActivityManager

    /// Called once when the SwiftData session is first created (on first set logged).
    /// Set by ActiveWorkoutService to persist the session ID to UserDefaults directly —
    /// bypassing SwiftUI observation chains which are unreliable for cross-object chains.
    /// @ObservationIgnored — the callback itself doesn't need to be tracked.
    @ObservationIgnored var onSessionCreated: ((UUID) -> Void)?

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
        activityManager.start(routineName: routineName, state: currentActivityState)
    }

    /// Creates the WorkoutSession and an ExerciseSnapshot for every exercise immediately
    /// at workout start — before any set is logged. This ensures the full exercise list
    /// survives a force-quit or crash and can be restored on next launch.
    private func eagerlyPersistWorkout() {
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
                return DraftExercise(exerciseName: def.name, equipmentType: def.equipmentType, weightIncrement: def.resolvedWeightIncrement, isTimed: isTimed, sets: sets, restSeconds: entry.restSeconds)
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
                let defDescriptor = FetchDescriptor<ExerciseDefinition>(
                    predicate: #Predicate { $0.name == name }
                )
                let isTimed = (try? modelContext.fetch(defDescriptor))?.first?.isTimed ?? false
                // Start with one blank set; applyPreviousPerformance will expand and fill it.
                return DraftExercise(exerciseName: name, isTimed: isTimed, sets: [DraftSet()], restSeconds: 90)
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
            let defDescriptor = FetchDescriptor<ExerciseDefinition>(
                predicate: #Predicate { $0.name == name }
            )
            let def = (try? modelContext.fetch(defDescriptor))?.first
            let isTimed         = def?.isTimed ?? false
            let weightIncrement = def?.resolvedWeightIncrement ?? 2.5
            let equipmentType   = def?.equipmentType ?? ""

            // Reconstruct each persisted set as a logged DraftSet.
            let sortedRecords = snapshot.sets.sorted { $0.loggedAt < $1.loggedAt }
            var draftSets: [DraftSet] = sortedRecords.map { record in
                var draft = DraftSet()
                draft.weightText = formatWeight(record.weight)
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
                    exerciseName:    name,
                    equipmentType:   equipmentType,
                    weightIncrement: weightIncrement,
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
                blankNext.weightText = formatWeight(last.weight)
                if isTimed {
                    blankNext.durationText = last.duration.map { "\(Int($0))" } ?? "30"
                } else {
                    blankNext.repsText = "\(last.reps)"
                }
                // Warmup sets don't propagate forward.
                blankNext.setType = last.setType == .warmup ? .normal : last.setType
            }

            // Append enough blank sets to fill the routine's target count.
            // If the user already logged all (or more) planned sets, still leave 1 blank.
            let routineEntry = routineEntriesByName[name]
            let targetSets   = routineEntry?.targetSets ?? 0
            let blanksNeeded = targetSets > sortedRecords.count
                ? targetSets - sortedRecords.count
                : 1
            for _ in 0 ..< blanksNeeded {
                var s = blankNext
                s.id = UUID()
                draftSets.append(s)
            }

            let routineRestSecs = routineEntriesByName[name]?.restSeconds ?? 90
            return DraftExercise(
                exerciseName:    name,
                equipmentType:   equipmentType,
                weightIncrement: weightIncrement,
                isTimed:         isTimed,
                sets:            draftSets,
                snapshot:        snapshot,
                restSeconds:     routineRestSecs
            )
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
        let name = exercise.exerciseName
        let snapshotDescriptor = FetchDescriptor<ExerciseSnapshot>(
            predicate: #Predicate { $0.exerciseName == name }
        )
        guard let all = try? modelContext.fetch(snapshotDescriptor) else { return }

        let completed = all
            .filter { $0.workoutSession?.completedAt != nil }
            .sorted {
                ($0.workoutSession?.completedAt ?? .distantPast) >
                ($1.workoutSession?.completedAt ?? .distantPast)
            }

        guard let latest = completed.first else { return }

        let sortedSets = latest.sets.sorted { $0.loggedAt < $1.loggedAt }
        guard !sortedSets.isEmpty else { return }

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
            let source = i < sortedSets.count ? sortedSets[i] : sortedSets[sortedSets.count - 1]
            exercise.sets[i].weightText = formatWeight(source.weight)
            if exercise.isTimed {
                exercise.sets[i].durationText = source.duration.map { "\(Int($0))" } ?? "30"
            } else {
                exercise.sets[i].repsText = "\(source.reps)"
            }
            exercise.sets[i].setType = source.setType
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

        let descriptor = FetchDescriptor<ExerciseDefinition>(predicate: #Predicate { $0.name == name })
        let def = (try? modelContext.fetch(descriptor))?.first
        let equipmentType = def?.equipmentType ?? ""
        let weightIncrement = def?.weightIncrement ?? ExerciseDefinition.defaultIncrement(for: equipmentType)
        let isTimed = def?.isTimed ?? false
        // Preserve set count; clear logged state — new exercise starts fresh
        let setCount = max(1, draftExercises[index].sets.count)
        let sets = (0..<setCount).map { _ in DraftSet() }
        var replacement = DraftExercise(
            exerciseName: name,
            equipmentType: equipmentType,
            weightIncrement: weightIncrement,
            isTimed: isTimed,
            sets: sets
        )
        applyPreviousPerformance(to: &replacement)
        draftExercises[index] = replacement
        activityManager.update(currentActivityState)
    }

    func syncDefinition(at index: Int) {
        guard draftExercises.indices.contains(index) else { return }
        let name = draftExercises[index].exerciseName
        let descriptor = FetchDescriptor<ExerciseDefinition>(predicate: #Predicate { $0.name == name })
        guard let def = (try? modelContext.fetch(descriptor))?.first else { return }
        draftExercises[index].weightIncrement = def.weightIncrement ?? ExerciseDefinition.defaultIncrement(for: def.equipmentType)
        draftExercises[index].equipmentType = def.equipmentType
        draftExercises[index].isTimed = def.isTimed
    }

    func addExercise(named name: String) {
        let descriptor = FetchDescriptor<ExerciseDefinition>(predicate: #Predicate { $0.name == name })
        let def = (try? modelContext.fetch(descriptor))?.first
        let equipmentType = def?.equipmentType ?? ""
        let weightIncrement = def?.weightIncrement ?? ExerciseDefinition.defaultIncrement(for: equipmentType)
        let isTimed = def?.isTimed ?? false
        var draft = DraftExercise(exerciseName: name, equipmentType: equipmentType, weightIncrement: weightIncrement, isTimed: isTimed, sets: [DraftSet(), DraftSet(), DraftSet()])
        applyPreviousPerformance(to: &draft)
        draftExercises.append(draft)
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
        UISelectionFeedbackGenerator().selectionChanged()
    }

    func removeSet(exerciseIndex eIdx: Int, setIndex sIdx: Int) {
        guard draftExercises.indices.contains(eIdx),
              draftExercises[eIdx].sets.indices.contains(sIdx),
              !draftExercises[eIdx].sets[sIdx].isLogged else { return }
        draftExercises[eIdx].sets.remove(at: sIdx)
        // If that was the last set, remove the exercise entirely to avoid a
        // zombie card with zero rows that isAllSetsLogged treats as complete.
        if draftExercises[eIdx].sets.isEmpty {
            removeExercise(at: eIdx)
        }
    }

    func unlogSet(exerciseIndex eIdx: Int, setIndex sIdx: Int) {
        guard draftExercises.indices.contains(eIdx),
              draftExercises[eIdx].sets.indices.contains(sIdx),
              draftExercises[eIdx].sets[sIdx].isLogged else { return }

        // Remove the persisted SetRecord
        if let record = draftExercises[eIdx].sets[sIdx].loggedRecord {
            draftExercises[eIdx].snapshot?.sets.removeAll { $0.id == record.id }
            modelContext.delete(record)
        }

        draftExercises[eIdx].sets[sIdx].isLogged = false
        draftExercises[eIdx].sets[sIdx].loggedRecord = nil
        try? modelContext.save()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
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
    }

    func removeExercise(at index: Int) {
        guard draftExercises.indices.contains(index) else { return }

        // Delete the eagerly-created snapshot if it has no logged sets — it's a placeholder
        // with no real data. Snapshots with logged sets are left intact (preserve history).
        if let snapshot = draftExercises[index].snapshot, snapshot.sets.isEmpty {
            modelContext.delete(snapshot)
            try? modelContext.save()
        }

        draftExercises.remove(at: index)
        // Invalidate focus state that pointed into the removed (or now-shifted) exercise.
        if let lf = lastLoggedFocus {
            if lf.exerciseIndex == index { lastLoggedFocus = nil }
            else if lf.exerciseIndex > index { lastLoggedFocus = SetFocus(exerciseIndex: lf.exerciseIndex - 1, setIndex: lf.setIndex) }
        }
        if let mf = manualFocus {
            if mf.exerciseIndex == index { manualFocus = nil }
            else if mf.exerciseIndex > index { manualFocus = SetFocus(exerciseIndex: mf.exerciseIndex - 1, setIndex: mf.setIndex) }
        }
        activityManager.update(currentActivityState)
    }

    func moveExercise(at index: Int, direction: MoveDirection) {
        let target = direction == .up ? index - 1 : index + 1
        guard draftExercises.indices.contains(index),
              draftExercises.indices.contains(target) else { return }
        draftExercises.swapAt(index, target)
        activityManager.update(currentActivityState)
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
    }

    func logSet(exerciseIndex eIdx: Int, setIndex sIdx: Int) {
        guard draftExercises.indices.contains(eIdx),
              draftExercises[eIdx].sets.indices.contains(sIdx),
              !draftExercises[eIdx].sets[sIdx].isLogged else { return }

        let draft = draftExercises[eIdx].sets[sIdx]
        let isTimed = draftExercises[eIdx].isTimed
        let weight = Double(draft.weightText) ?? 0
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
        let isNewPR: Bool
        if draft.setType != .warmup && !isTimed {
            isNewPR = checkPR(exerciseName: draftExercises[eIdx].exerciseName, weight: weight, reps: reps, record: record)
        } else {
            isNewPR = false
        }

        draftExercises[eIdx].sets[sIdx].isLogged = true
        draftExercises[eIdx].sets[sIdx].loggedRecord = record
        lastLoggedFocus = SetFocus(exerciseIndex: eIdx, setIndex: sIdx)
        lastLoggedExerciseIndex = eIdx

        // After loggedRecord is assigned, surface the PR so the view can animate
        if isNewPR {
            draftExercises[eIdx].sets[sIdx].isPR = true
            lastPRSetID = record.id
            let e1rm = ExerciseDefinition.estimatedOneRepMax(weight: weight, reps: reps)
            showingPRMoment = PRMoment(
                exerciseName: draftExercises[eIdx].exerciseName,
                weight: weight,
                reps: reps,
                estimatedOneRepMax: e1rm
            )
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
                let isBlank = draftExercises[eIdx].sets[i].weightText.isEmpty ||
                              draftExercises[eIdx].sets[i].weightText == "0"
                guard isBlank else { continue }
                draftExercises[eIdx].sets[i].weightText = draft.weightText
                draftExercises[eIdx].sets[i].repsText = draft.repsText
            }
        }

        // Clear manual focus — auto-advance takes over
        manualFocus = nil

        try? modelContext.save()
        activityManager.update(currentActivityState)

        if !isAllSetsLogged {
            if !isNewPR {
                // Haptic is handled in AppView (onChange loggedSetCount) so it can
                // distinguish exercise-complete from single-set. Don't fire here.
                startRestTimer(duration: TimeInterval(draftExercises[eIdx].restSeconds))
            } else {
                // Rest timer deferred — starts when the PR overlay is dismissed
                pendingRestDuration = TimeInterval(draftExercises[eIdx].restSeconds)
            }
        }
    }

    /// Logs the currently focused set. Returns true if a set was logged.
    @discardableResult
    func logFocusedSet() -> Bool {
        guard let focus = currentFocus else { return false }
        logSet(exerciseIndex: focus.exerciseIndex, setIndex: focus.setIndex)
        return true
    }

    func startRestTimer(duration: TimeInterval) {
        zeroTask?.cancel()
        phaseUpdateTasks.forEach { $0.cancel() }
        phaseUpdateTasks.removeAll()

        restTimer.start(duration: duration)
        activityManager.update(currentActivityState)
        guard let deadline = restTimer.targetEndDate else { return }

        // Fire the zero task to clear the timer when it expires.
        zeroTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let delay = deadline.timeIntervalSinceNow
            if delay > 0 { try? await Task.sleep(for: .seconds(delay)) }
            guard !Task.isCancelled else { return }
            self.restTimer.tick(at: .now)
            self.activityManager.update(self.currentActivityState)
        }

        // Schedule Live Activity updates at the 50% and 20% thresholds so the
        // phase colour (green → amber → red) transitions in the widget without
        // requiring any user interaction.
        for threshold in [0.5, 0.2] {
            let delay = duration * (1.0 - threshold)
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

    func skipRest() {
        zeroTask?.cancel()
        phaseUpdateTasks.forEach { $0.cancel() }
        phaseUpdateTasks.removeAll()
        restTimer.skip()
        activityManager.update(currentActivityState)
    }

    func adjustRest(by seconds: TimeInterval) {
        restTimer.adjust(seconds: seconds)
        activityManager.update(currentActivityState)
    }

    func cycleSetType(exerciseIndex eIdx: Int, setIndex sIdx: Int) {
        guard draftExercises.indices.contains(eIdx),
              draftExercises[eIdx].sets.indices.contains(sIdx) else { return }
        let all = SetType.allCases
        let current = draftExercises[eIdx].sets[sIdx].setType
        let next = all[((all.firstIndex(of: current) ?? 0) + 1) % all.count]
        draftExercises[eIdx].sets[sIdx].setType = next
    }

    func adjustWeight(exerciseIndex eIdx: Int, setIndex sIdx: Int, increment: Bool) {
        guard draftExercises.indices.contains(eIdx),
              draftExercises[eIdx].sets.indices.contains(sIdx) else { return }
        let step = draftExercises[eIdx].weightIncrement
        let current = Double(draftExercises[eIdx].sets[sIdx].weightText) ?? 0
        if increment && current == 0 {
            let start = firstTapDefault(for: draftExercises[eIdx].equipmentType)
            draftExercises[eIdx].sets[sIdx].weightText = formatWeight(start)
            return
        }
        let next = increment ? current + step : max(0, current - step)
        draftExercises[eIdx].sets[sIdx].weightText = formatWeight(next)
    }

    /// Starting weight for the stepper when a set has no value yet.
    private func firstTapDefault(for equipmentType: String) -> Double {
        switch equipmentType {
        case "Barbell":    return 45   // empty bar
        case "Dumbbell":   return 10
        case "Cable":      return 20
        case "Machine":    return 45
        case "Kettlebell": return 35
        case "Bodyweight": return 0    // added weight, stay at 0
        default:           return 45
        }
    }

    func adjustReps(exerciseIndex eIdx: Int, setIndex sIdx: Int, increment: Bool) {
        guard draftExercises.indices.contains(eIdx),
              draftExercises[eIdx].sets.indices.contains(sIdx) else { return }
        let current = Int(draftExercises[eIdx].sets[sIdx].repsText) ?? 0
        let next = increment ? current + 1 : max(0, current - 1)
        draftExercises[eIdx].sets[sIdx].repsText = "\(next)"
    }

    var loggedSetCount: Int {
        draftExercises.flatMap { $0.sets }.filter { $0.isLogged }.count
    }

    /// The next unlogged set for the rest timer card — same position as `autoFocus`
    /// so the command bar and rest timer always agree on what's coming next.
    var nextUnloggedFocus: (exerciseIndex: Int, setIndex: Int, weightText: String, repsText: String, durationText: String, isTimed: Bool, exerciseName: String, totalSets: Int)? {
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
        s.completedAt = .now
        applyPendingPRs()
        try? modelContext.save()
        activityManager.end(currentActivityState)
        return s
    }

    private func applyPendingPRs() {
        for (exerciseName, newE1RM) in pendingPRByExercise {
            let d = FetchDescriptor<ExerciseDefinition>(
                predicate: #Predicate { $0.name == exerciseName }
            )
            guard let def = (try? modelContext.fetch(d))?.first else { continue }
            def.previousPR = def.currentPR
            def.currentPR = newE1RM
            def.prDate = .now
        }
        pendingPRByExercise.removeAll()
    }

    /// Discards the in-progress session and all logged sets without saving.
    func cancelWorkout() {
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
        v.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(v))" : String(format: "%.1f", v)
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
        if let focus = currentFocus, draftExercises.indices.contains(focus.exerciseIndex) {
            let draftExercise = draftExercises[focus.exerciseIndex]
            let draftSet = draftExercise.sets[focus.setIndex]
            exercise = draftExercise.exerciseName
            focusedSetLabel = "Set \(focus.setIndex + 1) of \(draftExercise.sets.count)"
            if draftExercise.isTimed, !draftSet.durationText.isEmpty {
                focusedSetDetail = "\(draftSet.durationText)s"
            } else {
                let weight = draftSet.weightText
                let reps = draftSet.repsText
                if !weight.isEmpty && !reps.isEmpty {
                    focusedSetDetail = "\(weight) × \(reps)"
                } else if !reps.isEmpty {
                    focusedSetDetail = "\(reps) reps"
                } else if !weight.isEmpty {
                    focusedSetDetail = "\(weight)"
                } else {
                    focusedSetDetail = nil
                }
            }
        } else {
            exercise = draftExercises.first?.exerciseName ?? routineName
            focusedSetLabel = nil
            focusedSetDetail = nil
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
            order: eIdx,
            workoutSession: session
        )
        modelContext.insert(snap)
        session.exercises.append(snap)
        draftExercises[eIdx].snapshot = snap
        return snap
    }

    @discardableResult
    private func checkPR(exerciseName: String, weight: Double, reps: Int, record: SetRecord) -> Bool {
        let d = FetchDescriptor<ExerciseDefinition>(
            predicate: #Predicate { $0.name == exerciseName }
        )
        guard let def = (try? modelContext.fetch(d))?.first else { return false }
        let e1rm = ExerciseDefinition.estimatedOneRepMax(weight: weight, reps: reps)
        // Compare against both the persisted best and any better set already logged this session
        let sessionBest = pendingPRByExercise[exerciseName] ?? 0
        guard e1rm > max(def.currentPR, sessionBest) else { return false }
        pendingPRByExercise[exerciseName] = e1rm
        record.isPersonalRecord = true
        return true
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
