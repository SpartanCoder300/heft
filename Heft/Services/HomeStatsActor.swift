// iOS 26+ only. No #available guards.

import Foundation
import SwiftData

/// Result of the featured-routine ranking. Sendable so it can cross actor boundaries.
struct FeaturedRoutineSuggestion: Sendable {
    let routineID: UUID
    let routineName: String
    let exerciseCount: Int
    let daysSinceLast: Int   // 0 = completed today
    let avgIntervalDays: Int // rounded, minimum 1
}

@ModelActor
actor HomeStatsActor {

    /// Number of completed sessions in the current calendar week.
    func sessionCountThisWeek() -> Int {
        let descriptor = FetchDescriptor<WorkoutSession>()
        guard let sessions = try? modelContext.fetch(descriptor) else { return 0 }
        guard let weekStart = Self.currentWeekStart() else { return 0 }
        return sessions.filter { ($0.completedAt ?? .distantPast) >= weekStart }.count
    }

    /// Number of personal records logged this calendar week.
    func prCountThisWeek() -> Int {
        guard let weekStart = Self.currentWeekStart() else { return 0 }
        let descriptor = FetchDescriptor<SetRecord>(
            predicate: #Predicate<SetRecord> { record in
                record.isPersonalRecord && record.loggedAt >= weekStart
            }
        )
        return (try? modelContext.fetchCount(descriptor)) ?? 0
    }

    /// Consecutive days ending today on which at least one session was completed.
    func currentStreak() -> Int {
        let descriptor = FetchDescriptor<WorkoutSession>()
        guard let sessions = try? modelContext.fetch(descriptor) else { return 0 }

        let calendar = Calendar.current
        let completedDays = Set(
            sessions
                .compactMap { $0.completedAt }
                .map { calendar.startOfDay(for: $0) }
        )

        var streak = 0
        var day = calendar.startOfDay(for: .now)
        while completedDays.contains(day) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return streak
    }

    /// Returns the routine the user is most overdue to run, based on their history.
    ///
    /// Algorithm:
    /// - Groups all completed sessions by routineTemplateId
    /// - Computes average interval between consecutive sessions (all history)
    /// - Scores each routine: daysSinceLast / avgIntervalDays
    /// - Excludes routines whose last session was more than 21 days ago
    /// - Requires ≥ 2 historical sessions to compute a meaningful average
    func featuredRoutine() -> FeaturedRoutineSuggestion? {
        guard let sessions = try? modelContext.fetch(FetchDescriptor<WorkoutSession>()),
              let routines  = try? modelContext.fetch(FetchDescriptor<RoutineTemplate>())
        else { return nil }

        let now = Date.now
        let maxStaleDays = 21.0

        // Build sorted completion-date arrays per routine (all history)
        var datesByRoutine: [UUID: [Date]] = [:]
        for session in sessions {
            guard let rid = session.routineTemplateId,
                  let completedAt = session.completedAt else { continue }
            datesByRoutine[rid, default: []].append(completedAt)
        }

        let routineLookup = Dictionary(uniqueKeysWithValues: routines.map { ($0.id, $0) })

        var bestID: UUID?
        var bestScore = -1.0
        var bestDaysSinceLast = 0
        var bestAvgInterval = 1

        for (routineID, unsorted) in datesByRoutine {
            let dates = unsorted.sorted()

            // Need ≥ 2 sessions to derive a personal cadence
            guard dates.count >= 2 else { continue }

            let daysSinceLast = now.timeIntervalSince(dates.last!) / 86_400
            guard daysSinceLast <= maxStaleDays else { continue }

            // Average gap across all pairs of consecutive sessions
            var totalGap: TimeInterval = 0
            for i in 1..<dates.count {
                totalGap += dates[i].timeIntervalSince(dates[i - 1])
            }
            let avgDays = totalGap / Double(dates.count - 1) / 86_400
            guard avgDays > 0 else { continue }

            let score = daysSinceLast / avgDays
            if score > bestScore {
                bestScore = score
                bestID = routineID
                bestDaysSinceLast = max(0, Int(daysSinceLast.rounded()))
                bestAvgInterval = max(1, Int(avgDays.rounded()))
            }
        }

        // Don't surface a recommendation if the user essentially just ran it
        guard bestScore > 0.1 else { return nil }

        guard let routineID = bestID,
              let template = routineLookup[routineID] else { return nil }

        return FeaturedRoutineSuggestion(
            routineID: routineID,
            routineName: template.name,
            exerciseCount: template.entries.count,
            daysSinceLast: bestDaysSinceLast,
            avgIntervalDays: bestAvgInterval
        )
    }

    private static func currentWeekStart() -> Date? {
        let calendar = Calendar.current
        return calendar.date(
            from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: .now)
        )
    }
}
