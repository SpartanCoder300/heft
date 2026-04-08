// iOS 26+ only. No #available guards.

import Foundation
import SwiftData

/// Persisted summary of one calendar week (Mon–Sun).
/// Written at session completion so long-range charts never require full history re-scans.
@Model
final class WeeklySnapshot {
    var id: UUID = UUID()
    /// Monday 00:00:00 UTC of the represented week.
    var weekStarting: Date = Date.now
    var totalSessions: Int = 0
    var totalVolume: Double = 0         // sum of weight × reps, working sets only
    var totalSets: Int = 0
    var avgSessionDurationMinutes: Double = 0
    var setsByMuscle: [String: Int] = [:]   // muscle group → working set count
    var topE1RMs: [String: Double] = [:]    // exercise name → best e1RM that week
    var prCount: Int = 0
    var createdAt: Date = Date.now

    init(
        id: UUID = UUID(),
        weekStarting: Date,
        totalSessions: Int = 0,
        totalVolume: Double = 0,
        totalSets: Int = 0,
        avgSessionDurationMinutes: Double = 0,
        setsByMuscle: [String: Int] = [:],
        topE1RMs: [String: Double] = [:],
        prCount: Int = 0
    ) {
        self.id = id
        self.weekStarting = weekStarting
        self.totalSessions = totalSessions
        self.totalVolume = totalVolume
        self.totalSets = totalSets
        self.avgSessionDurationMinutes = avgSessionDurationMinutes
        self.setsByMuscle = setsByMuscle
        self.topE1RMs = topE1RMs
        self.prCount = prCount
    }
}
