// iOS 26+ only. No #available guards.

import Foundation
import SwiftData

@MainActor
enum RoutineSeeder {
    private static let seededKey = "Orin.hasSeededStarterRoutines"

    static func seedStarterRoutinesIfNeeded(in context: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: seededKey) else { return }

        let existing = (try? context.fetch(FetchDescriptor<RoutineTemplate>())) ?? []
        guard existing.isEmpty else {
            UserDefaults.standard.set(true, forKey: seededKey)
            return
        }

        let allDefs = (try? context.fetch(FetchDescriptor<ExerciseDefinition>())) ?? []
        func def(named name: String) -> ExerciseDefinition? {
            allDefs.first { $0.name == name }
        }

        struct StarterExercise {
            let name: String
            let sets: Int
            let repsMin: Int
            let repsMax: Int
            let rest: Int
        }

        let starters: [(name: String, exercises: [StarterExercise])] = [
            ("Push Day • Starter", [
                StarterExercise(name: "Barbell Bench Press",   sets: 4, repsMin: 5,  repsMax: 8,  rest: 180),
                StarterExercise(name: "Barbell Overhead Press",sets: 3, repsMin: 8,  repsMax: 10, rest: 120),
                StarterExercise(name: "Triceps Pushdown",      sets: 3, repsMin: 10, repsMax: 12, rest: 90),
            ]),
            ("Pull Day • Starter", [
                StarterExercise(name: "Pull-Up",               sets: 3, repsMin: 5,  repsMax: 8,  rest: 120),
                StarterExercise(name: "Bent-Over Barbell Row", sets: 4, repsMin: 6,  repsMax: 8,  rest: 120),
                StarterExercise(name: "Barbell Curl",          sets: 3, repsMin: 10, repsMax: 12, rest: 90),
            ]),
            ("Leg Day • Starter", [
                StarterExercise(name: "Barbell Back Squat",    sets: 4, repsMin: 5,  repsMax: 5,  rest: 180),
                StarterExercise(name: "Romanian Deadlift",     sets: 3, repsMin: 8,  repsMax: 10, rest: 120),
                StarterExercise(name: "Leg Press",             sets: 3, repsMin: 10, repsMax: 12, rest: 90),
            ]),
        ]

        var changed = false
        for starter in starters {
            let routine = RoutineTemplate(name: starter.name)
            context.insert(routine)
            for (order, ex) in starter.exercises.enumerated() {
                guard let definition = def(named: ex.name) else { continue }
                let entry = RoutineEntry(
                    exerciseDefinition: definition,
                    order: order,
                    targetSets: ex.sets,
                    targetRepsMin: ex.repsMin,
                    targetRepsMax: ex.repsMax,
                    restSeconds: ex.rest,
                    routineTemplate: routine
                )
                context.insert(entry)
            }
            changed = true
        }

        if changed { try? context.save() }
        UserDefaults.standard.set(true, forKey: seededKey)
    }

    /// Removes duplicate routine templates that share the same name, keeping the oldest
    /// (earliest createdAt) or the one that has been used. Safe to call on every launch.
    static func deduplicateIfNeeded(in context: ModelContext) {
        let all = (try? context.fetch(FetchDescriptor<RoutineTemplate>())) ?? []
        guard all.count > 1 else { return }

        // Group by name; if any name has more than one entry, keep the best and delete the rest.
        var byName: [String: [RoutineTemplate]] = [:]
        for r in all { byName[r.name, default: []].append(r) }

        var changed = false
        for (_, group) in byName where group.count > 1 {
            // Prefer the one that has been used, then the oldest.
            let sorted = group.sorted {
                if ($0.lastUsedAt != nil) != ($1.lastUsedAt != nil) {
                    return $0.lastUsedAt != nil
                }
                return $0.createdAt < $1.createdAt
            }
            for duplicate in sorted.dropFirst() {
                context.delete(duplicate)
                changed = true
            }
        }

        if changed { try? context.save() }
    }
}
