// iOS 26+ only. No #available guards.

import Foundation
import SwiftData
import UIKit

@Observable @MainActor
final class ActiveWorkoutViewModel {

    // MARK: - Types

    struct DraftSet: Identifiable {
        var id = UUID()
        var weightText: String = ""
        var repsText: String = ""
        var setType: SetType = .normal
        var isLogged: Bool = false
    }

    struct PreviousSet {
        var weight: Double
        var reps: Int
    }

    struct DraftExercise: Identifiable {
        var id = UUID()
        var exerciseName: String
        var sets: [DraftSet]
        var previousSets: [PreviousSet] = []
        var snapshot: ExerciseSnapshot? = nil
        var restSeconds: Int = 90
    }

    struct SetFocus: Equatable {
        let exerciseIndex: Int
        let setIndex: Int
    }

    // MARK: - State

    var draftExercises: [DraftExercise] = []
    var openedAt: Date = .now
    var isShowingEndConfirm: Bool = false
    var isShowingExercisePicker: Bool = false
    var isShowingRestTimer: Bool = false

    private(set) var session: WorkoutSession? = nil
    let restTimer = RestTimerState()

    var isSessionStarted: Bool { session != nil }

    /// Manual focus override — set when user taps a specific set row.
    /// Cleared automatically when that set gets logged.
    private var manualFocus: SetFocus? = nil

    // MARK: - Focus

    /// The currently focused set — either manual override or first unlogged set.
    var currentFocus: SetFocus? {
        // If manual override is still valid (exists and not yet logged), use it
        if let mf = manualFocus,
           draftExercises.indices.contains(mf.exerciseIndex),
           draftExercises[mf.exerciseIndex].sets.indices.contains(mf.setIndex),
           !draftExercises[mf.exerciseIndex].sets[mf.setIndex].isLogged {
            return mf
        }
        // Auto: first unlogged set across all exercises
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
    private let weightStep: Double = 2.5
    private var zeroTask: Task<Void, Never>? = nil

    // MARK: - Init

    init(modelContext: ModelContext, pendingRoutineID: UUID?, pendingSessionID: UUID? = nil) {
        self.modelContext = modelContext
        self.pendingRoutineID = pendingRoutineID
        self.pendingSessionID = pendingSessionID
    }

    // MARK: - Setup

    func setup() {
        if let routineID = pendingRoutineID {
            loadRoutine(id: routineID)
        } else if let sessionID = pendingSessionID {
            loadSession(id: sessionID)
        }
        for i in draftExercises.indices {
            applyPreviousPerformance(to: &draftExercises[i])
        }
    }

    private func loadRoutine(id: UUID) {
        let descriptor = FetchDescriptor<RoutineTemplate>(
            predicate: #Predicate { $0.id == id }
        )
        guard let routine = (try? modelContext.fetch(descriptor))?.first else { return }

        routine.lastUsedAt = .now

        draftExercises = routine.entries
            .sorted { $0.order < $1.order }
            .compactMap { entry in
                guard let def = entry.exerciseDefinition else { return nil }
                let sets = (0 ..< entry.targetSets).map { _ in
                    DraftSet(repsText: "\(entry.targetRepsMin)")
                }
                return DraftExercise(exerciseName: def.name, sets: sets, restSeconds: entry.restSeconds)
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
                // Start with one blank set; applyPreviousPerformance will expand and fill it.
                DraftExercise(exerciseName: snap.exerciseName, sets: [DraftSet()], restSeconds: 90)
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

        exercise.previousSets = sortedSets.map { PreviousSet(weight: $0.weight, reps: $0.reps) }

        // If this exercise was added ad-hoc (starts with 1 blank set), expand to match
        // last session's set count so the user doesn't have to tap "Add Set" repeatedly.
        let isAdHoc = exercise.sets.count == 1 && exercise.sets[0].weightText.isEmpty
        if isAdHoc && sortedSets.count > 1 {
            exercise.sets = sortedSets.map { _ in DraftSet() }
        }

        // Auto-fill: seed each draft set from the matching position, else last set.
        // Last session's actual reps always win — they're more accurate than the routine target.
        for i in exercise.sets.indices {
            let source = i < sortedSets.count ? sortedSets[i] : sortedSets[sortedSets.count - 1]
            exercise.sets[i].weightText = formatWeight(source.weight)
            exercise.sets[i].repsText = "\(source.reps)"
            exercise.sets[i].setType = source.setType
        }
    }

    // MARK: - Mutations

    func addExercise(named name: String) {
        var draft = DraftExercise(exerciseName: name, sets: [DraftSet()])
        applyPreviousPerformance(to: &draft)
        draftExercises.append(draft)
    }

    func removeSet(exerciseIndex eIdx: Int, setIndex sIdx: Int) {
        guard draftExercises.indices.contains(eIdx),
              draftExercises[eIdx].sets.indices.contains(sIdx),
              !draftExercises[eIdx].sets[sIdx].isLogged else { return }
        draftExercises[eIdx].sets.remove(at: sIdx)
    }

    func addSet(toExerciseAt index: Int) {
        guard draftExercises.indices.contains(index) else { return }
        var new = DraftSet()
        if let last = draftExercises[index].sets.last {
            new.weightText = last.weightText
            new.repsText = last.repsText
            new.setType = last.setType
        }
        draftExercises[index].sets.append(new)
    }

    func removeExercise(at index: Int) {
        guard draftExercises.indices.contains(index) else { return }
        draftExercises.remove(at: index)
    }

    func moveExercise(at index: Int, direction: MoveDirection) {
        let target = direction == .up ? index - 1 : index + 1
        guard draftExercises.indices.contains(index),
              draftExercises.indices.contains(target) else { return }
        draftExercises.swapAt(index, target)
    }

    enum MoveDirection { case up, down }

    func addDropset(toExerciseAt index: Int) {
        guard draftExercises.indices.contains(index) else { return }
        var dropset = DraftSet()
        dropset.setType = .dropset
        if let last = draftExercises[index].sets.last {
            dropset.weightText = last.weightText
            dropset.repsText = last.repsText
        }
        draftExercises[index].sets.append(dropset)
    }

    func logSet(exerciseIndex eIdx: Int, setIndex sIdx: Int) {
        guard draftExercises.indices.contains(eIdx),
              draftExercises[eIdx].sets.indices.contains(sIdx),
              !draftExercises[eIdx].sets[sIdx].isLogged else { return }

        let draft = draftExercises[eIdx].sets[sIdx]
        let weight = Double(draft.weightText) ?? 0
        let reps = Int(draft.repsText) ?? 0

        let currentSession = ensureSession()
        let snapshot = ensureSnapshot(exerciseIndex: eIdx, session: currentSession)

        let record = SetRecord(
            weight: weight,
            reps: reps,
            setType: draft.setType,
            exerciseSnapshot: snapshot
        )
        modelContext.insert(record)
        snapshot.sets.append(record)

        if draft.setType != .warmup {
            checkPR(exerciseName: draftExercises[eIdx].exerciseName, weight: weight, record: record)
        }

        draftExercises[eIdx].sets[sIdx].isLogged = true

        // Clear manual focus — auto-advance takes over
        manualFocus = nil

        try? modelContext.save()

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        startRestTimer(duration: TimeInterval(draftExercises[eIdx].restSeconds))
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
        restTimer.start(duration: duration)
        let deadline = restTimer.targetEndDate!
        zeroTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let delay = deadline.timeIntervalSinceNow
            if delay > 0 {
                try? await Task.sleep(for: .seconds(delay))
            }
            guard !Task.isCancelled else { return }
            self.restTimer.tick(at: .now)
        }
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
        let current = Double(draftExercises[eIdx].sets[sIdx].weightText) ?? 0
        let next = increment ? current + weightStep : max(0, current - weightStep)
        draftExercises[eIdx].sets[sIdx].weightText = formatWeight(next)
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

    /// True when every set across all exercises is logged. Drives auto-complete.
    var isAllSetsLogged: Bool {
        !draftExercises.isEmpty &&
        draftExercises.allSatisfy { $0.sets.allSatisfy { $0.isLogged } }
    }

    @discardableResult
    func endWorkout() -> WorkoutSession? {
        guard let s = session else { return nil }
        s.completedAt = .now
        try? modelContext.save()
        return s
    }

    // MARK: - Helpers

    func elapsedLabel(at date: Date) -> String {
        let e = max(0, Int(date.timeIntervalSince(openedAt)))
        return String(format: "%d:%02d", e / 60, e % 60)
    }

    func formatWeight(_ v: Double) -> String {
        v.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(v))" : String(format: "%.1f", v)
    }

    // MARK: - Private helpers

    private func ensureSession() -> WorkoutSession {
        if let s = session { return s }
        let s = WorkoutSession(startedAt: .now, routineTemplateId: pendingRoutineID)
        modelContext.insert(s)
        session = s
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

    private func checkPR(exerciseName: String, weight: Double, record: SetRecord) {
        let d = FetchDescriptor<ExerciseDefinition>(
            predicate: #Predicate { $0.name == exerciseName }
        )
        guard let def = (try? modelContext.fetch(d))?.first else { return }
        guard weight > def.currentPR else { return }
        def.previousPR = def.currentPR
        def.currentPR = weight
        def.prDate = .now
        record.isPersonalRecord = true
    }
}
