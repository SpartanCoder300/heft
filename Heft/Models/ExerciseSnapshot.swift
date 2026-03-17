// iOS 26+ only. No #available guards.

import Foundation
import SwiftData

@Model
final class ExerciseSnapshot {
    @Attribute(.unique) var id: UUID
    var exerciseName: String
    var order: Int
    @Relationship(deleteRule: .cascade, inverse: \SetRecord.exerciseSnapshot) var sets: [SetRecord]
    var workoutSession: WorkoutSession?

    init(
        id: UUID = UUID(),
        exerciseName: String,
        order: Int,
        sets: [SetRecord] = [],
        workoutSession: WorkoutSession? = nil
    ) {
        self.id = id
        self.exerciseName = exerciseName
        self.order = order
        self.sets = sets
        self.workoutSession = workoutSession
    }
}
