// iOS 26+ only. No #available guards.

import Foundation
import SwiftData

@Model
final class WorkoutSession {
    @Attribute(.unique) var id: UUID
    var startedAt: Date?
    var completedAt: Date?
    var routineTemplateId: UUID?
    var notes: String?
    @Relationship(deleteRule: .cascade, inverse: \ExerciseSnapshot.workoutSession) var exercises: [ExerciseSnapshot]

    init(
        id: UUID = UUID(),
        startedAt: Date? = nil,
        completedAt: Date? = nil,
        routineTemplateId: UUID? = nil,
        notes: String? = nil,
        exercises: [ExerciseSnapshot] = []
    ) {
        self.id = id
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.routineTemplateId = routineTemplateId
        self.notes = notes
        self.exercises = exercises
    }
}
