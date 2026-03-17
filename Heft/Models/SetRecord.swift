// iOS 26+ only. No #available guards.

import Foundation
import SwiftData

@Model
final class SetRecord {
    @Attribute(.unique) var id: UUID
    var weight: Double
    var reps: Int
    var setType: SetType
    var loggedAt: Date
    var isPersonalRecord: Bool
    var duration: Double?
    var exerciseSnapshot: ExerciseSnapshot?

    init(
        id: UUID = UUID(),
        weight: Double,
        reps: Int,
        setType: SetType = .normal,
        loggedAt: Date = .now,
        isPersonalRecord: Bool = false,
        duration: Double? = nil,
        exerciseSnapshot: ExerciseSnapshot? = nil
    ) {
        self.id = id
        self.weight = weight
        self.reps = reps
        self.setType = setType
        self.loggedAt = loggedAt
        self.isPersonalRecord = isPersonalRecord
        self.duration = duration
        self.exerciseSnapshot = exerciseSnapshot
    }
}
