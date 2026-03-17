// iOS 26+ only. No #available guards.

import Foundation
import SwiftData

@Model
final class RoutineEntry {
    @Attribute(.unique) var id: UUID
    var exerciseDefinition: ExerciseDefinition?
    var order: Int
    var targetSets: Int
    var targetRepsMin: Int
    var targetRepsMax: Int
    var restSeconds: Int
    var routineTemplate: RoutineTemplate?

    init(
        id: UUID = UUID(),
        exerciseDefinition: ExerciseDefinition? = nil,
        order: Int,
        targetSets: Int,
        targetRepsMin: Int,
        targetRepsMax: Int,
        restSeconds: Int,
        routineTemplate: RoutineTemplate? = nil
    ) {
        self.id = id
        self.exerciseDefinition = exerciseDefinition
        self.order = order
        self.targetSets = targetSets
        self.targetRepsMin = targetRepsMin
        self.targetRepsMax = targetRepsMax
        self.restSeconds = restSeconds
        self.routineTemplate = routineTemplate
    }
}
