// iOS 26+ only. No #available guards.

import Foundation
import SwiftData

@MainActor
enum ExerciseSeeder {
    static func seedIfNeeded(in context: ModelContext) {
        let fetchDescriptor = FetchDescriptor<ExerciseDefinition>()
        let existing = (try? context.fetch(fetchDescriptor)) ?? []

        var changed = deduplicateExercises(existing, in: context) || false

        // Re-fetch after dedup so indexes are stable.
        let current = changed ? ((try? context.fetch(fetchDescriptor)) ?? []) : existing

        for seed in commonExercises {
            if let match = current.first(where: { $0.name == seed.name }) {
                changed = syncSeed(seed, into: match) || changed
                continue
            }

            if let legacyMatch = current.first(where: { seed.legacyNames.contains($0.name) }) {
                changed = syncSeed(seed, into: legacyMatch) || changed
                continue
            }

            context.insert(seed.makeDefinition())
            changed = true
        }

        guard changed else { return }
        do {
            try context.save()
        } catch {
            assertionFailure("Failed to seed exercises: \(error)")
        }
    }

    /// Removes duplicate ExerciseDefinition records that share the same name.
    /// Keeps the record with the highest PR (most user data), falling back to oldest createdAt.
    /// Returns true if any records were deleted.
    @discardableResult
    static func deduplicateExercises(_ exercises: [ExerciseDefinition], in context: ModelContext) -> Bool {
        var byName: [String: [ExerciseDefinition]] = [:]
        for ex in exercises { byName[ex.name, default: []].append(ex) }

        var changed = false
        for (_, group) in byName where group.count > 1 {
            // Keep the record with the best PR data; tie-break on oldest createdAt.
            let sorted = group.sorted {
                if $0.currentPR != $1.currentPR { return $0.currentPR > $1.currentPR }
                if $0.isCustom != $1.isCustom { return $0.isCustom }
                return $0.createdAt < $1.createdAt
            }
            for duplicate in sorted.dropFirst() {
                context.delete(duplicate)
                changed = true
            }
        }
        return changed
    }

    static func resetBuiltInExercises(in context: ModelContext) {
        let fetchDescriptor = FetchDescriptor<ExerciseDefinition>()
        let existing = (try? context.fetch(fetchDescriptor)) ?? []

        var changed = false

        for exercise in existing where !exercise.isCustom {
            guard let seed = commonExercises.first(where: {
                $0.name == exercise.name || $0.legacyNames.contains(exercise.name)
            }) else { continue }

            changed = syncSeed(seed, into: exercise) || changed
            if exercise.isEdited {
                exercise.isEdited = false
                changed = true
            }
        }

        let existingNames = Set(existing.map(\.name))
        for seed in commonExercises where !existingNames.contains(seed.name) {
            let hasLegacy = existing.contains { seed.legacyNames.contains($0.name) }
            guard !hasLegacy else { continue }
            context.insert(seed.makeDefinition())
            changed = true
        }

        guard changed else { return }
        do {
            try context.save()
        } catch {
            assertionFailure("Failed to reset built-in exercises: \(error)")
        }
    }

    /// Returns a fresh copy of the seeded defaults for the given exercise name, or nil if not seeded.
    static func defaultDefinition(named name: String) -> ExerciseDefinition? {
        commonExercises.first { $0.name == name || $0.legacyNames.contains(name) }?.makeDefinition()
    }

    private static func syncSeed(_ seed: SeedExercise, into exercise: ExerciseDefinition) -> Bool {
        var changed = false

        if exercise.isTimed != seed.isTimed {
            exercise.isTimed = seed.isTimed
            changed = true
        }
        if exercise.loadTrackingMode != seed.loadTrackingMode {
            exercise.loadTrackingMode = seed.loadTrackingMode
            changed = true
        }

        guard !exercise.isCustom, !exercise.isEdited else { return changed }

        if exercise.name != seed.name {
            exercise.name = seed.name
            changed = true
        }
        if exercise.muscleGroups != seed.muscleGroups {
            exercise.muscleGroups = seed.muscleGroups
            changed = true
        }
        if exercise.equipmentType != seed.equipmentType {
            exercise.equipmentType = seed.equipmentType
            changed = true
        }
        if exercise.weightIncrement != seed.weightIncrement {
            exercise.weightIncrement = seed.weightIncrement
            changed = true
        }
        if exercise.startingWeight != seed.startingWeight {
            exercise.startingWeight = seed.startingWeight
            changed = true
        }

        return changed
    }

    private struct SeedExercise {
        let name: String
        let muscleGroups: [String]
        let equipmentType: String
        let weightIncrement: Double?
        let startingWeight: Double?
        let loadTrackingMode: LoadTrackingMode
        let isTimed: Bool
        let legacyNames: [String]

        func makeDefinition() -> ExerciseDefinition {
            ExerciseDefinition(
                name: name,
                muscleGroups: muscleGroups,
                equipmentType: equipmentType,
                weightIncrement: weightIncrement,
                startingWeight: startingWeight,
                loadTrackingMode: loadTrackingMode,
                isTimed: isTimed
            )
        }
    }

    private static func exercise(
        _ name: String,
        _ muscleGroups: [String],
        equipmentType: String,
        increment: Double? = nil,
        start: Double? = nil,
        loadTrackingMode: LoadTrackingMode = .externalWeight,
        isTimed: Bool = false,
        legacy legacyNames: [String] = []
    ) -> SeedExercise {
        SeedExercise(
            name: name,
            muscleGroups: muscleGroups,
            equipmentType: equipmentType,
            weightIncrement: increment,
            startingWeight: start,
            loadTrackingMode: loadTrackingMode,
            isTimed: isTimed,
            legacyNames: legacyNames
        )
    }

    // swiftlint:disable function_body_length
    private static let commonExercises: [SeedExercise] = [

        // MARK: Chest
        exercise("Barbell Bench Press", ["Chest", "Triceps"], equipmentType: "Barbell", start: 45),
        exercise("Incline Barbell Bench Press", ["Chest", "Shoulders"], equipmentType: "Barbell", start: 45, legacy: ["Incline Bench Press"]),
        exercise("Decline Barbell Bench Press", ["Chest", "Triceps"], equipmentType: "Barbell", start: 45, legacy: ["Decline Bench Press"]),
        exercise("Dumbbell Bench Press", ["Chest", "Triceps"], equipmentType: "Dumbbell", start: 10),
        exercise("Incline Dumbbell Press", ["Chest", "Shoulders"], equipmentType: "Dumbbell", start: 10),
        exercise("Decline Dumbbell Press", ["Chest", "Triceps"], equipmentType: "Dumbbell", start: 10),
        exercise("Dumbbell Fly", ["Chest"], equipmentType: "Dumbbell", start: 10),
        exercise("Incline Dumbbell Fly", ["Chest"], equipmentType: "Dumbbell", start: 10),
        exercise("Cable Fly", ["Chest"], equipmentType: "Cable", increment: 2.5, start: 10),
        exercise("Low Cable Fly", ["Chest"], equipmentType: "Cable", increment: 5, start: 10),
        exercise("High Cable Fly", ["Chest"], equipmentType: "Cable", increment: 5, start: 10),
        exercise("Machine Chest Press", ["Chest", "Triceps"], equipmentType: "Machine", increment: 5, start: 10),
        exercise("Pec Deck", ["Chest"], equipmentType: "Machine", increment: 5, start: 10),
        exercise("Push-Up", ["Chest", "Triceps", "Core"], equipmentType: "Bodyweight", loadTrackingMode: .none),
        exercise("Weighted Dip", ["Chest", "Triceps"], equipmentType: "Bodyweight", increment: 2.5, start: 0, loadTrackingMode: .bodyweightPlusLoad),
        exercise("Landmine Press", ["Chest", "Shoulders"], equipmentType: "Barbell", increment: 5, start: 25),
        exercise("Dumbbell Pullover", ["Chest", "Back"], equipmentType: "Dumbbell", start: 10),

        // MARK: Back
        exercise("Barbell Deadlift", ["Back", "Legs"], equipmentType: "Barbell", start: 45),
        exercise("Sumo Deadlift", ["Back", "Legs"], equipmentType: "Barbell", start: 45),
        exercise("Trap Bar Deadlift", ["Back", "Legs"], equipmentType: "Barbell", start: 60),
        exercise("Rack Pull", ["Back"], equipmentType: "Barbell", start: 45),
        exercise("Bent-Over Barbell Row", ["Back", "Biceps"], equipmentType: "Barbell", start: 45, legacy: ["Barbell Row"]),
        exercise("Pendlay Row", ["Back", "Biceps"], equipmentType: "Barbell", start: 45),
        exercise("T-Bar Row", ["Back", "Biceps"], equipmentType: "Barbell", increment: 5, start: 25),
        exercise("Single-Arm Dumbbell Row", ["Back", "Biceps"], equipmentType: "Dumbbell", start: 10),
        exercise("Chest-Supported Machine Row", ["Back"], equipmentType: "Machine", increment: 5, start: 10, legacy: ["Chest-Supported Row"]),
        exercise("Seated Cable Row", ["Back", "Biceps"], equipmentType: "Cable", increment: 5, start: 10),
        exercise("Straight-Arm Pulldown", ["Back"], equipmentType: "Cable", increment: 5, start: 10),
        exercise("Pull-Up", ["Back", "Biceps"], equipmentType: "Bodyweight", start: 0, loadTrackingMode: .bodyweightPlusLoad),
        exercise("Chin-Up", ["Back", "Biceps"], equipmentType: "Bodyweight", start: 0, loadTrackingMode: .bodyweightPlusLoad),
        exercise("Lat Pulldown", ["Back", "Biceps"], equipmentType: "Cable", increment: 5, start: 10),
        exercise("Close-Grip Lat Pulldown", ["Back", "Biceps"], equipmentType: "Cable", increment: 5, start: 10),
        exercise("Good Morning", ["Back", "Legs"], equipmentType: "Barbell", start: 45),
        exercise("Back Extension", ["Back"], equipmentType: "Bodyweight", start: 0, loadTrackingMode: .bodyweightPlusLoad, legacy: ["Hyperextension"]),
        exercise("Inverted Row", ["Back", "Biceps"], equipmentType: "Bodyweight", loadTrackingMode: .none),
        exercise("Chest-Supported Dumbbell Row", ["Back", "Biceps"], equipmentType: "Dumbbell", start: 10),
        exercise("Seal Row", ["Back", "Biceps"], equipmentType: "Barbell", start: 45),
        exercise("Meadows Row", ["Back", "Biceps"], equipmentType: "Barbell", increment: 5, start: 25),

        // MARK: Shoulders
        exercise("Barbell Overhead Press", ["Shoulders", "Triceps"], equipmentType: "Barbell", start: 45),
        exercise("Seated Dumbbell Shoulder Press", ["Shoulders", "Triceps"], equipmentType: "Dumbbell", start: 10),
        exercise("Arnold Press", ["Shoulders", "Triceps"], equipmentType: "Dumbbell", start: 10),
        exercise("Machine Shoulder Press", ["Shoulders", "Triceps"], equipmentType: "Machine", increment: 5, start: 10),
        exercise("Lateral Raise", ["Shoulders"], equipmentType: "Dumbbell", start: 5),
        exercise("Cable Lateral Raise", ["Shoulders"], equipmentType: "Cable", increment: 5, start: 5),
        exercise("Dumbbell Front Raise", ["Shoulders"], equipmentType: "Dumbbell", start: 5),
        exercise("Cable Front Raise", ["Shoulders"], equipmentType: "Cable", increment: 5, start: 5),
        exercise("Reverse Pec Deck", ["Shoulders", "Back"], equipmentType: "Machine", increment: 5, start: 10, legacy: ["Rear Delt Fly"]),
        exercise("Face Pull", ["Shoulders", "Back"], equipmentType: "Cable", increment: 5, start: 10),
        exercise("Upright Row", ["Shoulders", "Biceps"], equipmentType: "Barbell", start: 45),
        exercise("Barbell Shrug", ["Shoulders"], equipmentType: "Barbell", start: 45, legacy: ["Shrug"]),
        exercise("Dumbbell Shrug", ["Shoulders"], equipmentType: "Dumbbell", start: 20),
        exercise("Push Press", ["Shoulders", "Triceps", "Legs"], equipmentType: "Barbell", start: 45),
        exercise("Band Pull-Apart", ["Shoulders", "Back"], equipmentType: "Band", loadTrackingMode: .none),

        // MARK: Biceps
        exercise("Barbell Curl", ["Biceps"], equipmentType: "Barbell", start: 45),
        exercise("EZ Bar Curl", ["Biceps"], equipmentType: "Barbell", start: 30),
        exercise("Dumbbell Curl", ["Biceps"], equipmentType: "Dumbbell", start: 10),
        exercise("Hammer Curl", ["Biceps", "Forearms"], equipmentType: "Dumbbell", start: 10),
        exercise("Incline Dumbbell Curl", ["Biceps"], equipmentType: "Dumbbell", start: 10),
        exercise("Concentration Curl", ["Biceps"], equipmentType: "Dumbbell", start: 10),
        exercise("Spider Curl", ["Biceps"], equipmentType: "Dumbbell", start: 10),
        exercise("Machine Preacher Curl", ["Biceps"], equipmentType: "Machine", increment: 5, start: 10, legacy: ["Preacher Curl"]),
        exercise("Cable Curl", ["Biceps"], equipmentType: "Cable", increment: 5, start: 10),
        exercise("Cable Hammer Curl", ["Biceps", "Forearms"], equipmentType: "Cable", increment: 5, start: 10),
        exercise("Zottman Curl", ["Biceps", "Forearms"], equipmentType: "Dumbbell", start: 10),
        exercise("Bayesian Curl", ["Biceps"], equipmentType: "Cable", increment: 5, start: 5),
        exercise("Cross-Body Hammer Curl", ["Biceps", "Forearms"], equipmentType: "Dumbbell", start: 10),

        // MARK: Triceps
        exercise("Close-Grip Bench Press", ["Triceps", "Chest"], equipmentType: "Barbell", start: 45),
        exercise("Skull Crusher", ["Triceps"], equipmentType: "Barbell", start: 30),
        exercise("JM Press", ["Triceps"], equipmentType: "Barbell", start: 45),
        exercise("Triceps Pushdown", ["Triceps"], equipmentType: "Cable", increment: 5, start: 10),
        exercise("Rope Pushdown", ["Triceps"], equipmentType: "Cable", increment: 5, start: 10),
        exercise("Overhead Cable Extension", ["Triceps"], equipmentType: "Cable", increment: 5, start: 10),
        exercise("Triceps Dip", ["Triceps", "Chest"], equipmentType: "Bodyweight", loadTrackingMode: .none),
        exercise("Diamond Push-Up", ["Triceps", "Chest"], equipmentType: "Bodyweight", loadTrackingMode: .none),
        exercise("Dumbbell Kickback", ["Triceps"], equipmentType: "Dumbbell", start: 5),
        exercise("Overhead Dumbbell Extension", ["Triceps"], equipmentType: "Dumbbell", start: 10),
        exercise("Machine Triceps Extension", ["Triceps"], equipmentType: "Machine", increment: 5, start: 10),
        exercise("Tate Press", ["Triceps"], equipmentType: "Dumbbell", start: 10),

        // MARK: Forearms
        exercise("Wrist Curl", ["Forearms"], equipmentType: "Barbell", start: 20),
        exercise("Reverse Wrist Curl", ["Forearms"], equipmentType: "Barbell", start: 20),
        exercise("Reverse Curl", ["Forearms", "Biceps"], equipmentType: "Barbell", start: 30),
        exercise("Farmer Carry", ["Forearms", "Core"], equipmentType: "Dumbbell", start: 20),
        exercise("Dead Hang", ["Forearms", "Back"], equipmentType: "Bodyweight", loadTrackingMode: .none, isTimed: true),

        // MARK: Legs
        exercise("Barbell Back Squat", ["Legs", "Core"], equipmentType: "Barbell", start: 45),
        exercise("Front Squat", ["Legs", "Core"], equipmentType: "Barbell", start: 45),
        exercise("Box Squat", ["Legs"], equipmentType: "Barbell", start: 45),
        exercise("Pause Squat", ["Legs"], equipmentType: "Barbell", start: 45),
        exercise("Goblet Squat", ["Legs", "Core"], equipmentType: "Dumbbell", start: 10),
        exercise("Bulgarian Split Squat", ["Legs"], equipmentType: "Dumbbell", start: 10),
        exercise("Barbell Bulgarian Split Squat", ["Legs"], equipmentType: "Barbell", start: 45),
        exercise("Barbell Lunge", ["Legs"], equipmentType: "Barbell", start: 45),
        exercise("Walking Lunge", ["Legs", "Core"], equipmentType: "Dumbbell", start: 10),
        exercise("Reverse Lunge", ["Legs"], equipmentType: "Dumbbell", start: 10),
        exercise("Lateral Lunge", ["Legs"], equipmentType: "Dumbbell", start: 10),
        exercise("Curtsy Lunge", ["Glutes", "Legs"], equipmentType: "Dumbbell", start: 10),
        exercise("Pistol Squat", ["Legs", "Core"], equipmentType: "Bodyweight", start: 0, loadTrackingMode: .bodyweightPlusLoad),
        exercise("Romanian Deadlift", ["Legs", "Back"], equipmentType: "Barbell", start: 45),
        exercise("Dumbbell Romanian Deadlift", ["Legs", "Back"], equipmentType: "Dumbbell", start: 10),
        exercise("Single-Leg Romanian Deadlift", ["Legs", "Back"], equipmentType: "Dumbbell", start: 10),
        exercise("Stiff-Leg Deadlift", ["Legs", "Back"], equipmentType: "Barbell", start: 45),
        exercise("Hip Thrust", ["Glutes", "Legs"], equipmentType: "Barbell", start: 45),
        exercise("Leg Press", ["Legs"], equipmentType: "Machine", increment: 5, start: 45),
        exercise("Single-Leg Press", ["Legs"], equipmentType: "Machine", increment: 5, start: 25),
        exercise("Hack Squat", ["Legs"], equipmentType: "Machine", increment: 5, start: 45),
        exercise("Belt Squat", ["Legs"], equipmentType: "Machine", increment: 5, start: 45),
        exercise("Leg Extension", ["Legs"], equipmentType: "Machine", increment: 5, start: 10),
        exercise("Single-Leg Extension", ["Legs"], equipmentType: "Machine", increment: 5, start: 10),
        exercise("Lying Leg Curl", ["Legs"], equipmentType: "Machine", increment: 5, start: 10, legacy: ["Hamstring Curl"]),
        exercise("Seated Leg Curl", ["Legs"], equipmentType: "Machine", increment: 5, start: 10),
        exercise("Single-Leg Curl", ["Legs"], equipmentType: "Machine", increment: 5, start: 10),
        exercise("Hip Abduction Machine", ["Legs"], equipmentType: "Machine", increment: 5, start: 10),
        exercise("Hip Adduction Machine", ["Legs"], equipmentType: "Machine", increment: 5, start: 10),
        exercise("Nordic Hamstring Curl", ["Legs"], equipmentType: "Bodyweight", loadTrackingMode: .none),
        exercise("Standing Calf Raise", ["Legs"], equipmentType: "Machine", increment: 5, start: 25),
        exercise("Seated Calf Raise", ["Legs"], equipmentType: "Machine", increment: 5, start: 25),
        exercise("Single-Leg Calf Raise", ["Legs"], equipmentType: "Bodyweight", start: 0, loadTrackingMode: .bodyweightPlusLoad),
        exercise("Step-Up", ["Legs"], equipmentType: "Dumbbell", start: 10),

        // MARK: Glutes
        exercise("Glute Bridge", ["Glutes", "Legs"], equipmentType: "Bodyweight", loadTrackingMode: .none),
        exercise("Single-Leg Glute Bridge", ["Glutes", "Legs"], equipmentType: "Bodyweight", loadTrackingMode: .none),
        exercise("Barbell Glute Bridge", ["Glutes", "Legs"], equipmentType: "Barbell", start: 45),
        exercise("Dumbbell Hip Thrust", ["Glutes", "Legs"], equipmentType: "Dumbbell", start: 10),
        exercise("Single-Leg Hip Thrust", ["Glutes", "Legs"], equipmentType: "Bodyweight", start: 0, loadTrackingMode: .bodyweightPlusLoad),
        exercise("Smith Machine Hip Thrust", ["Glutes", "Legs"], equipmentType: "Machine", increment: 5, start: 45),
        exercise("Cable Glute Kickback", ["Glutes", "Legs"], equipmentType: "Cable", increment: 5, start: 5),
        exercise("Cable Pull-Through", ["Glutes", "Legs"], equipmentType: "Cable", increment: 5, start: 20),
        exercise("Kettlebell Swing", ["Glutes", "Legs"], equipmentType: "Kettlebell", increment: 5, start: 15),

        // MARK: Core
        exercise("Crunch", ["Core"], equipmentType: "Bodyweight", loadTrackingMode: .none),
        exercise("Sit-Up", ["Core"], equipmentType: "Bodyweight", loadTrackingMode: .none),
        exercise("Bicycle Crunch", ["Core"], equipmentType: "Bodyweight", loadTrackingMode: .none),
        exercise("Lying Leg Raise", ["Core"], equipmentType: "Bodyweight", loadTrackingMode: .none),
        exercise("V-Up", ["Core"], equipmentType: "Bodyweight", loadTrackingMode: .none),
        exercise("Plank", ["Core"], equipmentType: "Bodyweight", loadTrackingMode: .none, isTimed: true),
        exercise("Side Plank", ["Core"], equipmentType: "Bodyweight", loadTrackingMode: .none, isTimed: true),
        exercise("Hanging Leg Raise", ["Core"], equipmentType: "Bodyweight", loadTrackingMode: .none),
        exercise("Hanging Knee Raise", ["Core"], equipmentType: "Bodyweight", loadTrackingMode: .none),
        exercise("Ab Wheel Rollout", ["Core"], equipmentType: "Bodyweight", loadTrackingMode: .none),
        exercise("Dead Bug", ["Core"], equipmentType: "Bodyweight", loadTrackingMode: .none, isTimed: true),
        exercise("Hollow Hold", ["Core"], equipmentType: "Bodyweight", loadTrackingMode: .none, isTimed: true),
        exercise("Dragon Flag", ["Core"], equipmentType: "Bodyweight", loadTrackingMode: .none),
        exercise("Decline Crunch", ["Core"], equipmentType: "Bodyweight", loadTrackingMode: .none),
        exercise("GHD Sit-Up", ["Core"], equipmentType: "Machine", loadTrackingMode: .none),
        exercise("Russian Twist", ["Core"], equipmentType: "Bodyweight", loadTrackingMode: .none),
        exercise("Cable Crunch", ["Core"], equipmentType: "Cable", increment: 5, start: 10),
        exercise("Pallof Press", ["Core"], equipmentType: "Cable", increment: 5, start: 10),
        exercise("Landmine Twist", ["Core"], equipmentType: "Barbell", increment: 5, start: 25),
        exercise("Turkish Get-Up", ["Core", "Shoulders"], equipmentType: "Kettlebell", start: 10),

        // MARK: Power
        exercise("Power Clean", ["Back", "Legs", "Shoulders"], equipmentType: "Barbell", start: 45),
        exercise("Hang Clean", ["Back", "Legs", "Shoulders"], equipmentType: "Barbell", start: 45),
        exercise("Push Jerk", ["Shoulders", "Legs"], equipmentType: "Barbell", start: 45),
    ]
    // swiftlint:enable function_body_length
}
