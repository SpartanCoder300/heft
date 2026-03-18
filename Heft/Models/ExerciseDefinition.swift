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

    init(
        id: UUID = UUID(),
        name: String,
        muscleGroups: [String] = [],
        equipmentType: String,
        isCustom: Bool = false,
        createdAt: Date = .now,
        currentPR: Double = .zero,
        previousPR: Double = .zero,
        prDate: Date? = nil
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
