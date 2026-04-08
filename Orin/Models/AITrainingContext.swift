// iOS 26+ only. No #available guards.

import Foundation
import SwiftData

enum TrainingGoal: String, CaseIterable, Codable {
    case strength
    case hypertrophy
    case endurance
    case weightLoss
    case maintenance
}

enum ExperienceLevel: String, CaseIterable, Codable {
    case beginner       // < 1 year
    case intermediate   // 1–3 years
    case advanced       // 3+ years
}

/// Single-row user profile used to personalise AI coaching prompts.
/// Only one instance should exist in the store; create on first launch.
@Model
final class AITrainingContext {
    var id: UUID = UUID()
    /// Raw value of TrainingGoal.
    var goalRaw: String = TrainingGoal.hypertrophy.rawValue
    /// Raw value of ExperienceLevel.
    var experienceLevelRaw: String = ExperienceLevel.intermediate.rawValue
    /// Self-reported years of consistent training. 0 = unknown.
    var trainingAgeYears: Double = 0
    /// Freeform user description of injuries or movement limitations.
    var injuriesOrLimitations: String = ""
    /// Target body weight in lbs. Nil = no explicit target.
    var targetBodyWeightLbs: Double?
    /// How many sessions per week the user is aiming for.
    var sessionsPerWeekTarget: Int = 4
    var updatedAt: Date = Date.now

    var goal: TrainingGoal {
        get { TrainingGoal(rawValue: goalRaw) ?? .hypertrophy }
        set { goalRaw = newValue.rawValue }
    }

    var experienceLevel: ExperienceLevel {
        get { ExperienceLevel(rawValue: experienceLevelRaw) ?? .intermediate }
        set { experienceLevelRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        goal: TrainingGoal = .hypertrophy,
        experienceLevel: ExperienceLevel = .intermediate,
        trainingAgeYears: Double = 0,
        injuriesOrLimitations: String = "",
        targetBodyWeightLbs: Double? = nil,
        sessionsPerWeekTarget: Int = 4
    ) {
        self.id = id
        self.goalRaw = goal.rawValue
        self.experienceLevelRaw = experienceLevel.rawValue
        self.trainingAgeYears = trainingAgeYears
        self.injuriesOrLimitations = injuriesOrLimitations
        self.targetBodyWeightLbs = targetBodyWeightLbs
        self.sessionsPerWeekTarget = sessionsPerWeekTarget
    }
}
