// iOS 26+ only. No #available guards.

import Foundation
import SwiftData

@MainActor
enum ExerciseSeeder {
    private static let didSeedExercisesKey = "didSeedExercises"

    static func seedIfNeeded(in context: ModelContext) {
        guard UserDefaults.standard.bool(forKey: didSeedExercisesKey) == false else { return }

        let fetchDescriptor = FetchDescriptor<ExerciseDefinition>()
        let existingCount = (try? context.fetchCount(fetchDescriptor)) ?? .zero
        guard existingCount == .zero else {
            UserDefaults.standard.set(true, forKey: didSeedExercisesKey)
            return
        }

        commonExercises.forEach { definition in
            context.insert(definition)
        }

        do {
            try context.save()
            UserDefaults.standard.set(true, forKey: didSeedExercisesKey)
        } catch {
            assertionFailure("Failed to seed exercises: \(error)")
        }
    }

    private static let commonExercises: [ExerciseDefinition] = [
        ExerciseDefinition(name: "Barbell Bench Press", muscleGroups: ["Chest", "Arms"], equipmentType: "Barbell"),
        ExerciseDefinition(name: "Incline Bench Press", muscleGroups: ["Chest", "Shoulders"], equipmentType: "Barbell"),
        ExerciseDefinition(name: "Dumbbell Bench Press", muscleGroups: ["Chest", "Arms"], equipmentType: "Dumbbell"),
        ExerciseDefinition(name: "Incline Dumbbell Press", muscleGroups: ["Chest", "Shoulders"], equipmentType: "Dumbbell"),
        ExerciseDefinition(name: "Machine Chest Press", muscleGroups: ["Chest"], equipmentType: "Machine"),
        ExerciseDefinition(name: "Cable Fly", muscleGroups: ["Chest"], equipmentType: "Cable"),
        ExerciseDefinition(name: "Push-Up", muscleGroups: ["Chest", "Arms", "Core"], equipmentType: "Bodyweight"),
        ExerciseDefinition(name: "Weighted Dip", muscleGroups: ["Chest", "Arms"], equipmentType: "Bodyweight"),
        ExerciseDefinition(name: "Barbell Back Squat", muscleGroups: ["Legs", "Core"], equipmentType: "Barbell"),
        ExerciseDefinition(name: "Front Squat", muscleGroups: ["Legs", "Core"], equipmentType: "Barbell"),
        ExerciseDefinition(name: "Leg Press", muscleGroups: ["Legs"], equipmentType: "Machine"),
        ExerciseDefinition(name: "Romanian Deadlift", muscleGroups: ["Legs", "Back"], equipmentType: "Barbell"),
        ExerciseDefinition(name: "Walking Lunge", muscleGroups: ["Legs", "Core"], equipmentType: "Dumbbell"),
        ExerciseDefinition(name: "Leg Extension", muscleGroups: ["Legs"], equipmentType: "Machine"),
        ExerciseDefinition(name: "Hamstring Curl", muscleGroups: ["Legs"], equipmentType: "Machine"),
        ExerciseDefinition(name: "Standing Calf Raise", muscleGroups: ["Legs"], equipmentType: "Machine"),
        ExerciseDefinition(name: "Barbell Deadlift", muscleGroups: ["Back", "Legs"], equipmentType: "Barbell"),
        ExerciseDefinition(name: "Trap Bar Deadlift", muscleGroups: ["Back", "Legs"], equipmentType: "Barbell"),
        ExerciseDefinition(name: "Pull-Up", muscleGroups: ["Back", "Arms"], equipmentType: "Bodyweight"),
        ExerciseDefinition(name: "Chin-Up", muscleGroups: ["Back", "Arms"], equipmentType: "Bodyweight"),
        ExerciseDefinition(name: "Lat Pulldown", muscleGroups: ["Back", "Arms"], equipmentType: "Cable"),
        ExerciseDefinition(name: "Barbell Row", muscleGroups: ["Back", "Arms"], equipmentType: "Barbell"),
        ExerciseDefinition(name: "Chest-Supported Row", muscleGroups: ["Back"], equipmentType: "Machine"),
        ExerciseDefinition(name: "Seated Cable Row", muscleGroups: ["Back", "Arms"], equipmentType: "Cable"),
        ExerciseDefinition(name: "Single-Arm Dumbbell Row", muscleGroups: ["Back", "Arms"], equipmentType: "Dumbbell"),
        ExerciseDefinition(name: "Straight-Arm Pulldown", muscleGroups: ["Back"], equipmentType: "Cable"),
        ExerciseDefinition(name: "Barbell Overhead Press", muscleGroups: ["Shoulders", "Arms"], equipmentType: "Barbell"),
        ExerciseDefinition(name: "Seated Dumbbell Shoulder Press", muscleGroups: ["Shoulders", "Arms"], equipmentType: "Dumbbell"),
        ExerciseDefinition(name: "Arnold Press", muscleGroups: ["Shoulders", "Arms"], equipmentType: "Dumbbell"),
        ExerciseDefinition(name: "Lateral Raise", muscleGroups: ["Shoulders"], equipmentType: "Dumbbell"),
        ExerciseDefinition(name: "Cable Lateral Raise", muscleGroups: ["Shoulders"], equipmentType: "Cable"),
        ExerciseDefinition(name: "Rear Delt Fly", muscleGroups: ["Shoulders", "Back"], equipmentType: "Machine"),
        ExerciseDefinition(name: "Face Pull", muscleGroups: ["Shoulders", "Back"], equipmentType: "Cable"),
        ExerciseDefinition(name: "Barbell Curl", muscleGroups: ["Arms"], equipmentType: "Barbell"),
        ExerciseDefinition(name: "Hammer Curl", muscleGroups: ["Arms"], equipmentType: "Dumbbell"),
        ExerciseDefinition(name: "Preacher Curl", muscleGroups: ["Arms"], equipmentType: "Machine"),
        ExerciseDefinition(name: "Cable Curl", muscleGroups: ["Arms"], equipmentType: "Cable"),
        ExerciseDefinition(name: "Close-Grip Bench Press", muscleGroups: ["Arms", "Chest"], equipmentType: "Barbell"),
        ExerciseDefinition(name: "Skull Crusher", muscleGroups: ["Arms"], equipmentType: "Barbell"),
        ExerciseDefinition(name: "Triceps Pushdown", muscleGroups: ["Arms"], equipmentType: "Cable"),
        ExerciseDefinition(name: "Overhead Cable Extension", muscleGroups: ["Arms"], equipmentType: "Cable"),
        ExerciseDefinition(name: "Plank", muscleGroups: ["Core"], equipmentType: "Bodyweight"),
        ExerciseDefinition(name: "Hanging Leg Raise", muscleGroups: ["Core"], equipmentType: "Bodyweight"),
        ExerciseDefinition(name: "Cable Crunch", muscleGroups: ["Core"], equipmentType: "Cable"),
        ExerciseDefinition(name: "Ab Wheel Rollout", muscleGroups: ["Core"], equipmentType: "Bodyweight"),
        ExerciseDefinition(name: "Treadmill Run", muscleGroups: ["Cardio"], equipmentType: "Machine"),
        ExerciseDefinition(name: "Rowing Erg", muscleGroups: ["Cardio", "Back"], equipmentType: "Machine"),
        ExerciseDefinition(name: "Air Bike Sprint", muscleGroups: ["Cardio"], equipmentType: "Machine"),
        ExerciseDefinition(name: "Farmer Carry", muscleGroups: ["Core", "Arms"], equipmentType: "Dumbbell"),
        ExerciseDefinition(name: "Hip Thrust", muscleGroups: ["Legs"], equipmentType: "Barbell"),
    ]
}
