// iOS 26+ only. No #available guards.

import Foundation
import SwiftData

@MainActor
enum ExerciseSeeder {
    static func seedIfNeeded(in context: ModelContext) {
        let fetchDescriptor = FetchDescriptor<ExerciseDefinition>()
        let existing: [ExerciseDefinition]
        if let all = try? context.fetch(fetchDescriptor) {
            existing = all
        } else {
            existing = []
        }
        let existingNames = Set(existing.map { $0.name })

        var changed = false

        for definition in commonExercises {
            if !existingNames.contains(definition.name) {
                context.insert(definition)
                changed = true
            } else if definition.isTimed,
                      let match = existing.first(where: { $0.name == definition.name }),
                      !match.isTimed {
                // Migrate existing record to timed
                match.isTimed = true
                changed = true
            }
        }

        guard changed else { return }
        do {
            try context.save()
        } catch {
            assertionFailure("Failed to seed exercises: \(error)")
        }
    }

    // swiftlint:disable function_body_length
    private static let commonExercises: [ExerciseDefinition] = [

        // MARK: Chest
        ExerciseDefinition(name: "Barbell Bench Press",         muscleGroups: ["Chest", "Triceps"],            equipmentType: "Barbell"),
        ExerciseDefinition(name: "Incline Bench Press",         muscleGroups: ["Chest", "Shoulders"],          equipmentType: "Barbell"),
        ExerciseDefinition(name: "Decline Bench Press",         muscleGroups: ["Chest", "Triceps"],            equipmentType: "Barbell"),
        ExerciseDefinition(name: "Dumbbell Bench Press",        muscleGroups: ["Chest", "Triceps"],            equipmentType: "Dumbbell"),
        ExerciseDefinition(name: "Incline Dumbbell Press",      muscleGroups: ["Chest", "Shoulders"],          equipmentType: "Dumbbell"),
        ExerciseDefinition(name: "Decline Dumbbell Press",      muscleGroups: ["Chest", "Triceps"],            equipmentType: "Dumbbell"),
        ExerciseDefinition(name: "Dumbbell Fly",                muscleGroups: ["Chest"],                       equipmentType: "Dumbbell"),
        ExerciseDefinition(name: "Incline Dumbbell Fly",        muscleGroups: ["Chest"],                       equipmentType: "Dumbbell"),
        ExerciseDefinition(name: "Cable Fly",                   muscleGroups: ["Chest"],                       equipmentType: "Cable"),
        ExerciseDefinition(name: "Low Cable Fly",               muscleGroups: ["Chest"],                       equipmentType: "Cable"),
        ExerciseDefinition(name: "Machine Chest Press",         muscleGroups: ["Chest", "Triceps"],            equipmentType: "Machine"),
        ExerciseDefinition(name: "Pec Deck",                    muscleGroups: ["Chest"],                       equipmentType: "Machine"),
        ExerciseDefinition(name: "Push-Up",                     muscleGroups: ["Chest", "Triceps", "Core"],    equipmentType: "Bodyweight"),
        ExerciseDefinition(name: "Weighted Dip",                muscleGroups: ["Chest", "Triceps"],            equipmentType: "Bodyweight"),
        ExerciseDefinition(name: "Landmine Press",              muscleGroups: ["Chest", "Shoulders"],          equipmentType: "Barbell"),

        // MARK: Back
        ExerciseDefinition(name: "Barbell Deadlift",            muscleGroups: ["Back", "Legs"],                equipmentType: "Barbell"),
        ExerciseDefinition(name: "Sumo Deadlift",               muscleGroups: ["Back", "Legs"],                equipmentType: "Barbell"),
        ExerciseDefinition(name: "Trap Bar Deadlift",           muscleGroups: ["Back", "Legs"],                equipmentType: "Barbell"),
        ExerciseDefinition(name: "Rack Pull",                   muscleGroups: ["Back"],                        equipmentType: "Barbell"),
        ExerciseDefinition(name: "Barbell Row",                 muscleGroups: ["Back", "Biceps"],              equipmentType: "Barbell"),
        ExerciseDefinition(name: "Pendlay Row",                 muscleGroups: ["Back", "Biceps"],              equipmentType: "Barbell"),
        ExerciseDefinition(name: "T-Bar Row",                   muscleGroups: ["Back", "Biceps"],              equipmentType: "Barbell"),
        ExerciseDefinition(name: "Single-Arm Dumbbell Row",     muscleGroups: ["Back", "Biceps"],              equipmentType: "Dumbbell"),
        ExerciseDefinition(name: "Chest-Supported Row",         muscleGroups: ["Back"],                        equipmentType: "Machine"),
        ExerciseDefinition(name: "Seated Cable Row",            muscleGroups: ["Back", "Biceps"],              equipmentType: "Cable"),
        ExerciseDefinition(name: "Straight-Arm Pulldown",       muscleGroups: ["Back"],                        equipmentType: "Cable"),
        ExerciseDefinition(name: "Pull-Up",                     muscleGroups: ["Back", "Biceps"],              equipmentType: "Bodyweight"),
        ExerciseDefinition(name: "Chin-Up",                     muscleGroups: ["Back", "Biceps"],              equipmentType: "Bodyweight"),
        ExerciseDefinition(name: "Lat Pulldown",                muscleGroups: ["Back", "Biceps"],              equipmentType: "Cable"),
        ExerciseDefinition(name: "Close-Grip Lat Pulldown",     muscleGroups: ["Back", "Biceps"],              equipmentType: "Cable"),
        ExerciseDefinition(name: "Good Morning",                muscleGroups: ["Back", "Legs"],                equipmentType: "Barbell"),
        ExerciseDefinition(name: "Hyperextension",              muscleGroups: ["Back"],                        equipmentType: "Bodyweight"),

        // MARK: Shoulders
        ExerciseDefinition(name: "Barbell Overhead Press",      muscleGroups: ["Shoulders", "Triceps"],        equipmentType: "Barbell"),
        ExerciseDefinition(name: "Seated Dumbbell Shoulder Press", muscleGroups: ["Shoulders", "Triceps"],     equipmentType: "Dumbbell"),
        ExerciseDefinition(name: "Arnold Press",                muscleGroups: ["Shoulders", "Triceps"],        equipmentType: "Dumbbell"),
        ExerciseDefinition(name: "Machine Shoulder Press",      muscleGroups: ["Shoulders", "Triceps"],        equipmentType: "Machine"),
        ExerciseDefinition(name: "Lateral Raise",               muscleGroups: ["Shoulders"],                   equipmentType: "Dumbbell"),
        ExerciseDefinition(name: "Cable Lateral Raise",         muscleGroups: ["Shoulders"],                   equipmentType: "Cable"),
        ExerciseDefinition(name: "Dumbbell Front Raise",        muscleGroups: ["Shoulders"],                   equipmentType: "Dumbbell"),
        ExerciseDefinition(name: "Cable Front Raise",           muscleGroups: ["Shoulders"],                   equipmentType: "Cable"),
        ExerciseDefinition(name: "Rear Delt Fly",               muscleGroups: ["Shoulders", "Back"],           equipmentType: "Machine"),
        ExerciseDefinition(name: "Face Pull",                   muscleGroups: ["Shoulders", "Back"],           equipmentType: "Cable"),
        ExerciseDefinition(name: "Upright Row",                 muscleGroups: ["Shoulders", "Biceps"],         equipmentType: "Barbell"),
        ExerciseDefinition(name: "Shrug",                       muscleGroups: ["Shoulders"],                   equipmentType: "Barbell"),
        ExerciseDefinition(name: "Dumbbell Shrug",              muscleGroups: ["Shoulders"],                   equipmentType: "Dumbbell"),

        // MARK: Biceps
        ExerciseDefinition(name: "Barbell Curl",                muscleGroups: ["Biceps"],                      equipmentType: "Barbell"),
        ExerciseDefinition(name: "EZ Bar Curl",                 muscleGroups: ["Biceps"],                      equipmentType: "Barbell"),
        ExerciseDefinition(name: "Dumbbell Curl",               muscleGroups: ["Biceps"],                      equipmentType: "Dumbbell"),
        ExerciseDefinition(name: "Hammer Curl",                 muscleGroups: ["Biceps", "Forearms"],          equipmentType: "Dumbbell"),
        ExerciseDefinition(name: "Incline Dumbbell Curl",       muscleGroups: ["Biceps"],                      equipmentType: "Dumbbell"),
        ExerciseDefinition(name: "Concentration Curl",          muscleGroups: ["Biceps"],                      equipmentType: "Dumbbell"),
        ExerciseDefinition(name: "Spider Curl",                 muscleGroups: ["Biceps"],                      equipmentType: "Dumbbell"),
        ExerciseDefinition(name: "Preacher Curl",               muscleGroups: ["Biceps"],                      equipmentType: "Machine"),
        ExerciseDefinition(name: "Cable Curl",                  muscleGroups: ["Biceps"],                      equipmentType: "Cable"),
        ExerciseDefinition(name: "Cable Hammer Curl",           muscleGroups: ["Biceps", "Forearms"],          equipmentType: "Cable"),
        ExerciseDefinition(name: "Zottman Curl",                muscleGroups: ["Biceps", "Forearms"],          equipmentType: "Dumbbell"),

        // MARK: Triceps
        ExerciseDefinition(name: "Close-Grip Bench Press",      muscleGroups: ["Triceps", "Chest"],            equipmentType: "Barbell"),
        ExerciseDefinition(name: "Skull Crusher",               muscleGroups: ["Triceps"],                     equipmentType: "Barbell"),
        ExerciseDefinition(name: "JM Press",                    muscleGroups: ["Triceps"],                     equipmentType: "Barbell"),
        ExerciseDefinition(name: "Triceps Pushdown",            muscleGroups: ["Triceps"],                     equipmentType: "Cable"),
        ExerciseDefinition(name: "Rope Pushdown",               muscleGroups: ["Triceps"],                     equipmentType: "Cable"),
        ExerciseDefinition(name: "Overhead Cable Extension",    muscleGroups: ["Triceps"],                     equipmentType: "Cable"),
        ExerciseDefinition(name: "Triceps Dip",                 muscleGroups: ["Triceps", "Chest"],            equipmentType: "Bodyweight"),
        ExerciseDefinition(name: "Diamond Push-Up",             muscleGroups: ["Triceps", "Chest"],            equipmentType: "Bodyweight"),
        ExerciseDefinition(name: "Dumbbell Kickback",           muscleGroups: ["Triceps"],                     equipmentType: "Dumbbell"),
        ExerciseDefinition(name: "Overhead Dumbbell Extension", muscleGroups: ["Triceps"],                     equipmentType: "Dumbbell"),

        // MARK: Forearms
        ExerciseDefinition(name: "Wrist Curl",                  muscleGroups: ["Forearms"],                    equipmentType: "Barbell"),
        ExerciseDefinition(name: "Reverse Wrist Curl",          muscleGroups: ["Forearms"],                    equipmentType: "Barbell"),
        ExerciseDefinition(name: "Reverse Curl",                muscleGroups: ["Forearms", "Biceps"],          equipmentType: "Barbell"),
        ExerciseDefinition(name: "Farmer Carry",                muscleGroups: ["Forearms", "Core"],            equipmentType: "Dumbbell"),

        // MARK: Legs
        ExerciseDefinition(name: "Barbell Back Squat",          muscleGroups: ["Legs", "Core"],                equipmentType: "Barbell"),
        ExerciseDefinition(name: "Front Squat",                 muscleGroups: ["Legs", "Core"],                equipmentType: "Barbell"),
        ExerciseDefinition(name: "Box Squat",                   muscleGroups: ["Legs"],                        equipmentType: "Barbell"),
        ExerciseDefinition(name: "Pause Squat",                 muscleGroups: ["Legs"],                        equipmentType: "Barbell"),
        ExerciseDefinition(name: "Goblet Squat",                muscleGroups: ["Legs", "Core"],                equipmentType: "Dumbbell"),
        ExerciseDefinition(name: "Bulgarian Split Squat",       muscleGroups: ["Legs"],                        equipmentType: "Dumbbell"),
        ExerciseDefinition(name: "Walking Lunge",               muscleGroups: ["Legs", "Core"],                equipmentType: "Dumbbell"),
        ExerciseDefinition(name: "Reverse Lunge",               muscleGroups: ["Legs"],                        equipmentType: "Dumbbell"),
        ExerciseDefinition(name: "Romanian Deadlift",           muscleGroups: ["Legs", "Back"],                equipmentType: "Barbell"),
        ExerciseDefinition(name: "Dumbbell Romanian Deadlift",  muscleGroups: ["Legs", "Back"],                equipmentType: "Dumbbell"),
        ExerciseDefinition(name: "Stiff-Leg Deadlift",          muscleGroups: ["Legs", "Back"],                equipmentType: "Barbell"),
        ExerciseDefinition(name: "Hip Thrust",                  muscleGroups: ["Legs"],                        equipmentType: "Barbell"),
        ExerciseDefinition(name: "Leg Press",                   muscleGroups: ["Legs"],                        equipmentType: "Machine"),
        ExerciseDefinition(name: "Hack Squat",                  muscleGroups: ["Legs"],                        equipmentType: "Machine"),
        ExerciseDefinition(name: "Leg Extension",               muscleGroups: ["Legs"],                        equipmentType: "Machine"),
        ExerciseDefinition(name: "Hamstring Curl",              muscleGroups: ["Legs"],                        equipmentType: "Machine"),
        ExerciseDefinition(name: "Seated Leg Curl",             muscleGroups: ["Legs"],                        equipmentType: "Machine"),
        ExerciseDefinition(name: "Nordic Hamstring Curl",       muscleGroups: ["Legs"],                        equipmentType: "Bodyweight"),
        ExerciseDefinition(name: "Standing Calf Raise",         muscleGroups: ["Legs"],                        equipmentType: "Machine"),
        ExerciseDefinition(name: "Seated Calf Raise",           muscleGroups: ["Legs"],                        equipmentType: "Machine"),
        ExerciseDefinition(name: "Step-Up",                     muscleGroups: ["Legs"],                        equipmentType: "Dumbbell"),

        // MARK: Core
        ExerciseDefinition(name: "Plank",                       muscleGroups: ["Core"],                        equipmentType: "Bodyweight", isTimed: true),
        ExerciseDefinition(name: "Side Plank",                  muscleGroups: ["Core"],                        equipmentType: "Bodyweight", isTimed: true),
        ExerciseDefinition(name: "Hanging Leg Raise",           muscleGroups: ["Core"],                        equipmentType: "Bodyweight"),
        ExerciseDefinition(name: "Ab Wheel Rollout",            muscleGroups: ["Core"],                        equipmentType: "Bodyweight"),
        ExerciseDefinition(name: "Dead Bug",                    muscleGroups: ["Core"],                        equipmentType: "Bodyweight", isTimed: true),
        ExerciseDefinition(name: "Dragon Flag",                 muscleGroups: ["Core"],                        equipmentType: "Bodyweight"),
        ExerciseDefinition(name: "Decline Crunch",              muscleGroups: ["Core"],                        equipmentType: "Bodyweight"),
        ExerciseDefinition(name: "Russian Twist",               muscleGroups: ["Core"],                        equipmentType: "Bodyweight"),
        ExerciseDefinition(name: "Cable Crunch",                muscleGroups: ["Core"],                        equipmentType: "Cable"),
        ExerciseDefinition(name: "Pallof Press",                muscleGroups: ["Core"],                        equipmentType: "Cable"),
        ExerciseDefinition(name: "Landmine Twist",              muscleGroups: ["Core"],                        equipmentType: "Barbell"),
    ]
    // swiftlint:enable function_body_length
}
