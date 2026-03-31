// iOS 26+ only. No #available guards.

import Foundation
import SwiftData

enum LoadTrackingMode: String, CaseIterable, Codable {
    case none
    case externalWeight
    case bodyweightPlusLoad
}

@Model
final class ExerciseDefinition {
    @Attribute(.unique) var id: UUID
    var name: String
    var muscleGroups: [String]
    var equipmentType: String
    var isCustom: Bool
    var archivedAt: Date?
    var createdAt: Date
    var currentPR: Double
    var previousPR: Double
    var prDate: Date?
    /// Explicitly overridden weight increment in lbs. Nil = use equipment-type default.
    /// Optional so lightweight migration succeeds for existing rows (nil → resolvedWeightIncrement
    /// returns the equipment default, preserving correct behaviour without data loss).
    var weightIncrement: Double?
    /// Optional first-tap weight in lbs for a blank set. Nil = use equipment-type default.
    /// Some implements (EZ bar, trap bar, selectorized stacks) need an explicit
    /// start load so repeated increments line up with real-world equipment.
    var startingWeight: Double?
    /// Controls whether the exercise tracks no weight, external load only,
    /// or bodyweight plus added load.
    var loadTrackingModeRaw: String = LoadTrackingMode.externalWeight.rawValue
    /// True for exercises measured by duration (planks, holds) rather than reps.
    /// Defaults to false — safe lightweight migration for existing records.
    var isTimed: Bool = false
    /// True when a seeded exercise has been manually modified by the user.
    /// Always false for custom exercises (user owns them entirely).
    var isEdited: Bool = false

    init(
        id: UUID = UUID(),
        name: String,
        muscleGroups: [String] = [],
        equipmentType: String,
        isCustom: Bool = false,
        archivedAt: Date? = nil,
        createdAt: Date = .now,
        currentPR: Double = .zero,
        previousPR: Double = .zero,
        prDate: Date? = nil,
        weightIncrement: Double? = nil,
        startingWeight: Double? = nil,
        loadTrackingMode: LoadTrackingMode = .externalWeight,
        isTimed: Bool = false
    ) {
        self.id = id
        self.name = name
        self.muscleGroups = muscleGroups
        self.equipmentType = equipmentType
        self.isCustom = isCustom
        self.archivedAt = archivedAt
        self.createdAt = createdAt
        self.currentPR = currentPR
        self.previousPR = previousPR
        self.prDate = prDate
        self.weightIncrement = weightIncrement
        self.startingWeight = startingWeight
        self.loadTrackingModeRaw = loadTrackingMode.rawValue
        self.isTimed = isTimed
    }

    /// Effective increment: explicit override if set, otherwise equipment-type default.
    var resolvedWeightIncrement: Double {
        weightIncrement ?? ExerciseDefinition.defaultIncrement(for: equipmentType)
    }

    /// Effective starting weight: explicit override if set, otherwise equipment-type default.
    var resolvedStartingWeight: Double {
        startingWeight ?? ExerciseDefinition.defaultStartingWeight(for: equipmentType)
    }

    var loadTrackingMode: LoadTrackingMode {
        get { LoadTrackingMode(rawValue: loadTrackingModeRaw) ?? .externalWeight }
        set { loadTrackingModeRaw = newValue.rawValue }
    }

    var tracksWeight: Bool { loadTrackingMode != .none }
    var isArchived: Bool { archivedAt != nil }

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
        case "Dumbbell":   return 2.5   // safer default than 5; some racks include 2.5 lb jumps
        case "Cable":      return 5.0   // common effective jump on commercial cable stacks
        case "Machine":    return 5.0   // conservative selectorized-machine default
        case "Kettlebell": return 5.0   // common lb-labelled increment in US gyms
        case "Bodyweight": return 2.5   // added weight belt
        case "Band":       return 5.0
        default:           return 2.5
        }
    }

    /// Starting load for the first tap on a blank set.
    static func defaultStartingWeight(for equipmentType: String) -> Double {
        switch equipmentType {
        case "Barbell":    return 45
        case "Dumbbell":   return 10
        case "Cable":      return 10
        case "Machine":    return 10
        case "Kettlebell": return 15
        case "Bodyweight": return 0
        case "Band":       return 0
        default:           return 45
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
