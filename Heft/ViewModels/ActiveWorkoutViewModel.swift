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
        var setType: SetType = .normal
        var isLogged: Bool = false
        var loggedRecord: SetRecord? = nil
        var isPR: Bool = false
    }

    struct PreviousSet {
        var weight: Double
        var reps: Int
    }

    struct DraftExercise: Identifiable {
        var id = UUID()
        var exerciseName: String
        var equipmentType: String = ""
        var weightIncrement: Double = 2.5
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
    var isShowingEndConfirm: Bool = false
    var isShowingExercisePicker: Bool = false
    var isShowingRestTimer: Bool = false
    /// Non-nil while the PR moment overlay is visible. Cleared by dismissPRMoment().
    private(set) var showingPRMoment: PRMoment? = nil

    private(set) var session: WorkoutSession? = nil
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
    private var zeroTask: Task<Void, Never>? = nil
    private var hasSetup = false

    // MARK: - Init

    init(modelContext: ModelContext, pendingRoutineID: UUID?, pendingSessionID: UUID? = nil) {
        self.modelContext = modelContext
        self.pendingRoutineID = pendingRoutineID
        self.pendingSessionID = pendingSessionID
    }

    // MARK: - Setup

    func setup() {
        guard !hasSetup else { return }
        hasSetup = true
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
                return DraftExercise(exerciseName: def.name, equipmentType: def.equipmentType, weightIncrement: def.resolvedWeightIncrement, sets: sets, restSeconds: entry.restSeconds)
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
        let descriptor = FetchDescriptor<ExerciseDefinition>(predicate: #Predicate { $0.name == name })
        let def = (try? modelContext.fetch(descriptor))?.first
        let equipmentType = def?.equipmentType ?? ""
        let weightIncrement = def?.weightIncrement ?? ExerciseDefinition.defaultIncrement(for: equipmentType)
        var draft = DraftExercise(exerciseName: name, equipmentType: equipmentType, weightIncrement: weightIncrement, sets: [DraftSet()])
        applyPreviousPerformance(to: &draft)
        draftExercises.append(draft)
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
            new.setType = last.setType
        }
        draftExercises[index].sets.append(new)
    }

    func removeExercise(at index: Int) {
        guard draftExercises.indices.contains(index) else { return }
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

        // PR check must run before set is marked logged (synchronous, main actor)
        let isNewPR: Bool
        if draft.setType != .warmup {
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

        // Propagate weight + reps forward to subsequent blank sets in the same exercise
        for i in draftExercises[eIdx].sets.indices where i > sIdx {
            guard !draftExercises[eIdx].sets[i].isLogged else { continue }
            let isBlank = draftExercises[eIdx].sets[i].weightText.isEmpty ||
                          draftExercises[eIdx].sets[i].weightText == "0"
            guard isBlank else { continue }
            draftExercises[eIdx].sets[i].weightText = draft.weightText
            draftExercises[eIdx].sets[i].repsText = draft.repsText
        }

        // Clear manual focus — auto-advance takes over
        manualFocus = nil

        try? modelContext.save()

        if !isNewPR {
            // PR sets fire their own distinct haptic; normal sets get medium impact
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            startRestTimer(duration: TimeInterval(draftExercises[eIdx].restSeconds))
        } else {
            // Rest timer deferred — starts when the PR overlay is dismissed
            pendingRestDuration = TimeInterval(draftExercises[eIdx].restSeconds)
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
        restTimer.start(duration: duration)
        guard let deadline = restTimer.targetEndDate else { return }
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
    var nextUnloggedFocus: (exerciseIndex: Int, setIndex: Int, weightText: String, repsText: String, exerciseName: String, totalSets: Int)? {
        guard let f = autoFocus,
              draftExercises.indices.contains(f.exerciseIndex),
              draftExercises[f.exerciseIndex].sets.indices.contains(f.setIndex)
        else { return nil }
        let set = draftExercises[f.exerciseIndex].sets[f.setIndex]
        return (
            exerciseIndex: f.exerciseIndex,
            setIndex: f.setIndex,
            weightText: set.weightText,
            repsText: set.repsText,
            exerciseName: draftExercises[f.exerciseIndex].exerciseName,
            totalSets: draftExercises[f.exerciseIndex].sets.count
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
