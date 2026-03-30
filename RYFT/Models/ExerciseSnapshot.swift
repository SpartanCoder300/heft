// iOS 26+ only. No #available guards.

import Foundation
import SwiftData

@Model
final class ExerciseSnapshot {
    @Attribute(.unique) var id: UUID
    var exerciseName: String
    var equipmentType: String?
    var weightIncrement: Double?
    var startingWeight: Double?
    var loadTrackingModeRaw: String?
    var isTimed: Bool = false
    var restSeconds: Int?
    var draftStateJSON: String?
    var order: Int
    @Relationship(deleteRule: .cascade, inverse: \SetRecord.exerciseSnapshot) var sets: [SetRecord]
    var workoutSession: WorkoutSession?

    var loadTrackingMode: LoadTrackingMode {
        get { LoadTrackingMode(rawValue: loadTrackingModeRaw ?? "") ?? .externalWeight }
        set { loadTrackingModeRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        exerciseName: String,
        equipmentType: String? = nil,
        weightIncrement: Double? = nil,
        startingWeight: Double? = nil,
        loadTrackingModeRaw: String? = nil,
        isTimed: Bool = false,
        restSeconds: Int? = nil,
        draftStateJSON: String? = nil,
        order: Int,
        sets: [SetRecord] = [],
        workoutSession: WorkoutSession? = nil
    ) {
        self.id = id
        self.exerciseName = exerciseName
        self.equipmentType = equipmentType
        self.weightIncrement = weightIncrement
        self.startingWeight = startingWeight
        self.loadTrackingModeRaw = loadTrackingModeRaw
        self.isTimed = isTimed
        self.restSeconds = restSeconds
        self.draftStateJSON = draftStateJSON
        self.order = order
        self.sets = sets
        self.workoutSession = workoutSession
    }
}
