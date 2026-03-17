// iOS 26+ only. No #available guards.

import Foundation
import SwiftData

@Model
final class BodyWeightEntry {
    @Attribute(.unique) var id: UUID
    var date: Date
    var weight: Double
    var unit: String

    init(
        id: UUID = UUID(),
        date: Date = .now,
        weight: Double,
        unit: String
    ) {
        self.id = id
        self.date = date
        self.weight = weight
        self.unit = unit
    }
}
