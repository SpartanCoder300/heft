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

    // MARK: - State

    var draftExercises: [DraftExercise] = []
    var activeExerciseIndex: Int = 0
    var openedAt: Date = .now
    var isShowingEndConfirm: Bool = false
    var isShowingExercisePicker: Bool = false
    var isShowingRestTimer: Bool = false

    private(set) var session: WorkoutSession? = nil
    let restTimer = RestTimerState()

    var isSessionStarted: Bool { session != nil }

    // MARK: - Private

    private let modelContext: ModelContext
    private let pendingRoutineID: UUID?
    private let weightStep: Double = 2.5
    private var zeroTask: Task<Void, Never>? = nil

    // MARK: - Init

    init(modelContext: ModelContext, pendingRoutineID: UUID?) {
        self.modelContext = modelContext
        self.pendingRoutineID = pendingRoutineID
    }

    // MARK: - Setup

    func setup() {
        if let routineID = pendingRoutineID {
            loadRoutine(id: routineID)
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

        // Auto-fill: seed each draft set from the matching position, else last set
        for i in exercise.sets.indices {
            let source = i < sortedSets.count ? sortedSets[i] : sortedSets[sortedSets.count - 1]
            exercise.sets[i].weightText = formatWeight(source.weight)
            // Only overwrite reps if not already set from routine config
            if exercise.sets[i].repsText.isEmpty {
                exercise.sets[i].repsText = "\(source.reps)"
            }
        }
    }

    // MARK: - Mutations

    func addExercise(named name: String) {
        var draft = DraftExercise(exerciseName: name, sets: [DraftSet()])
        applyPreviousPerformance(to: &draft)
        draftExercises.append(draft)
        activeExerciseIndex = draftExercises.count - 1
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
        activeExerciseIndex = max(0, min(activeExerciseIndex, draftExercises.count - 1))
    }

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

        try? modelContext.save()

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        startRestTimer(duration: TimeInterval(draftExercises[eIdx].restSeconds))
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
            // Let tick() handle the reset and pulse if the timer actually expired
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
