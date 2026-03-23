// iOS 26+ only. No #available guards.

import Foundation
import SwiftData

@Model
final class ExerciseDefinition {
    @Attribute(.unique) var id: UUID
    var name: String
    var muscleGroups: [String]
    var equipmentType: String
    var isCustom: Bool
    var createdAt: Date
    var currentPR: Double
    var previousPR: Double
    var prDate: Date?
    /// Explicitly overridden weight increment in lbs. Nil = use equipment-type default.
    /// Optional so lightweight migration succeeds for existing rows (nil → resolvedWeightIncrement
    /// returns the equipment default, preserving correct behaviour without data loss).
    var weightIncrement: Double?
    /// True for exercises measured by duration (planks, holds) rather than reps.
    /// Defaults to false — safe lightweight migration for existing records.
    var isTimed: Bool = false

    init(
        id: UUID = UUID(),
        name: String,
        muscleGroups: [String] = [],
        equipmentType: String,
        isCustom: Bool = false,
        createdAt: Date = .now,
        currentPR: Double = .zero,
        previousPR: Double = .zero,
        prDate: Date? = nil,
        weightIncrement: Double? = nil,
        isTimed: Bool = false
    ) {
        self.id = id
        self.name = name
        self.muscleGroups = muscleGroups
        self.equipmentType = equipmentType
        self.isCustom = isCustom
        self.createdAt = createdAt
        self.currentPR = currentPR
        self.previousPR = previousPR
        self.prDate = prDate
        self.weightIncrement = weightIncrement
        self.isTimed = isTimed
    }

    /// Effective increment: explicit override if set, otherwise equipment-type default.
    var resolvedWeightIncrement: Double {
        weightIncrement ?? ExerciseDefinition.defaultIncrement(for: equipmentType)
    }

    /// Epley estimated one-rep max: weight × (1 + reps / 30).
    /// Returns weight as-is for 0–1 reps or 0 weight.
    static func estimatedOneRepMax(weight: Double, reps: Int) -> Double {
        guard weight > 0, reps > 1 else { return weight }
        return weight * (1.0 + Double(reps) / 30.0)
    }

    /// Standard weight increment for a given equipment type.
    static func defaultIncrement(for equipmentType: String) -> Double {
        switch equipmentType {
        case "Barbell":    return 2.5   // smallest standard plate pair
        case "Dumbbell":   return 2.0   // typical dumbbell rack step
        case "Cable":      return 2.5   // standard cable stack pin increment
        case "Machine":    return 5.0   // typical plate-loaded / selectorised step
        case "Kettlebell": return 4.0   // ~4kg jump between standard bells
        case "Bodyweight": return 2.5   // added weight belt
        default:           return 2.5
        }
    }

    var iconName: String {
        switch muscleGroups.first {
        case "Chest":     "figure.strengthtraining.traditional"
        case "Back":      "figure.climbing"
        case "Shoulders": "figure.highintensityintervaltraining"
        case "Biceps":    "figure.strengthtraining.functional"
        case "Triceps":   "figure.gymnastics"
        case "Forearms":  "hand.raised.fill"
        case "Legs":      "figure.step.training"
        case "Core":      "figure.core.training.mixed"
        default:          "dumbbell.fill"
        }
    }
}
