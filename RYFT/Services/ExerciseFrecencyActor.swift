// iOS 26+ only. No #available guards.

import Foundation
import SwiftData

/// Computes frecency scores for exercise lineages based on historical usage.
/// score = (1 / (daysSinceLastUse + 1)) * log(timesUsed + 1)
@ModelActor
actor ExerciseFrecencyActor {

    /// Returns a dictionary mapping exercise lineage → frecency score.
    /// Only exercises that appear in at least one completed session are scored.
    func scores() throws -> [UUID: Double] {
        let snapshots = try modelContext.fetch(FetchDescriptor<ExerciseSnapshot>())
        let definitions = try modelContext.fetch(FetchDescriptor<ExerciseDefinition>())
        let lineageByName = Dictionary(uniqueKeysWithValues: definitions.map { ($0.name, $0.id) })

        // Group by exercise name, collecting last-used dates and total usage counts.
        struct Usage {
            var count: Int = 0
            var lastUsed: Date = .distantPast
        }

        var usageMap: [UUID: Usage] = [:]

        for snapshot in snapshots {
            guard let lineageID = snapshot.exerciseLineageID ?? lineageByName[snapshot.exerciseName] else { continue }
            let sessionDate = snapshot.workoutSession?.completedAt
                           ?? snapshot.workoutSession?.startedAt
                           ?? .distantPast
            var u = usageMap[lineageID, default: Usage()]
            u.count += 1
            if sessionDate > u.lastUsed { u.lastUsed = sessionDate }
            usageMap[lineageID] = u
        }

        let now = Date.now
        var result: [UUID: Double] = [:]
        for (lineageID, usage) in usageMap {
            let days = now.timeIntervalSince(usage.lastUsed) / 86_400
            let recency = 1.0 / (days + 1)
            let frequency = log(Double(usage.count) + 1)
            result[lineageID] = recency * frequency
        }
        return result
    }
}
