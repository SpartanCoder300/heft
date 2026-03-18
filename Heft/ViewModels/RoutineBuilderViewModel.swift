// iOS 26+ only. No #available guards.

import Foundation
import SwiftData
import SwiftUI

@Observable @MainActor
final class RoutineBuilderViewModel {

    struct DraftEntry: Identifiable, Equatable {
        var id: UUID
        var exercise: ExerciseDefinition
        var targetSets: Int
        var targetRepsMin: Int
        var targetRepsMax: Int
        var restSeconds: Int

        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.id == rhs.id
                && lhs.exercise.id == rhs.exercise.id
                && lhs.targetSets == rhs.targetSets
                && lhs.targetRepsMin == rhs.targetRepsMin
                && lhs.targetRepsMax == rhs.targetRepsMax
                && lhs.restSeconds == rhs.restSeconds
        }

        init(exercise: ExerciseDefinition) {
            self.id = UUID()
            self.exercise = exercise
            self.targetSets = 3
            self.targetRepsMin = 8
            self.targetRepsMax = 12
            self.restSeconds = 90
        }

        init?(from entry: RoutineEntry) {
            guard let def = entry.exerciseDefinition else { return nil }
            self.id = entry.id
            self.exercise = def
            self.targetSets = entry.targetSets
            self.targetRepsMin = entry.targetRepsMin
            self.targetRepsMax = entry.targetRepsMax
            self.restSeconds = entry.restSeconds
        }
    }

    var routineName: String = ""
    var entries: [DraftEntry] = []

    let existingRoutine: RoutineTemplate?

    // Change detection
    private let initialName: String
    private let initialEntries: [DraftEntry]

    init(existingRoutine: RoutineTemplate? = nil) {
        let name: String
        let drafts: [DraftEntry]
        if let routine = existingRoutine {
            name = routine.name
            drafts = routine.entries
                .sorted { $0.order < $1.order }
                .compactMap { DraftEntry(from: $0) }
        } else {
            name = ""
            drafts = []
        }
        self.existingRoutine = existingRoutine
        self.routineName = name
        self.entries = drafts
        self.initialName = name
        self.initialEntries = drafts
    }

    var isEditingExisting: Bool { existingRoutine != nil }

    var canSave: Bool {
        !routineName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !entries.isEmpty
    }

    var hasUnsavedChanges: Bool {
        routineName != initialName || entries != initialEntries
    }

    func addExercise(_ exercise: ExerciseDefinition) {
        entries.append(DraftEntry(exercise: exercise))
    }

    func removeEntry(withID id: UUID) {
        entries.removeAll { $0.id == id }
    }

    func removeEntries(at offsets: IndexSet) {
        entries.remove(atOffsets: offsets)
    }

    func move(from source: IndexSet, to destination: Int) {
        entries.move(fromOffsets: source, toOffset: destination)
    }

    func save(in context: ModelContext) {
        let name = routineName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !entries.isEmpty else { return }

        if let existing = existingRoutine {
            existing.name = name
            for old in existing.entries { context.delete(old) }
            let fresh = entries.enumerated().map { idx, draft in
                let e = RoutineEntry(
                    exerciseDefinition: draft.exercise,
                    order: idx,
                    targetSets: draft.targetSets,
                    targetRepsMin: draft.targetRepsMin,
                    targetRepsMax: draft.targetRepsMax,
                    restSeconds: draft.restSeconds,
                    routineTemplate: existing
                )
                context.insert(e)
                return e
            }
            existing.entries = fresh
        } else {
            let routine = RoutineTemplate(name: name)
            context.insert(routine)
            let fresh = entries.enumerated().map { idx, draft in
                let e = RoutineEntry(
                    exerciseDefinition: draft.exercise,
                    order: idx,
                    targetSets: draft.targetSets,
                    targetRepsMin: draft.targetRepsMin,
                    targetRepsMax: draft.targetRepsMax,
                    restSeconds: draft.restSeconds,
                    routineTemplate: routine
                )
                context.insert(e)
                return e
            }
            routine.entries = fresh
        }

        try? context.save()
    }

    func deleteRoutine(from context: ModelContext) {
        guard let existing = existingRoutine else { return }
        context.delete(existing)
        try? context.save()
    }
}
