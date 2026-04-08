// iOS 26+ only. No #available guards.

import Foundation
import SwiftData

/// Owns all WorkoutSession mutations that have side effects on persisted models.
/// Views and view models must call these methods instead of touching modelContext directly.
///
/// Created fresh per call-site (same pattern as HomeStatsActor) — no singleton needed
/// since all state lives in SwiftData.
@ModelActor
actor SessionService {

    // MARK: - Write path (session completion)

    /// Call immediately after a session's completedAt is set and saved.
    /// Creates or updates the WeeklySnapshot for the session's week.
    func upsertWeeklySnapshot(for sessionID: PersistentIdentifier) {
        guard
            let session = modelContext.model(for: sessionID) as? WorkoutSession,
            let completedAt = session.completedAt
        else { return }

        let week = weekStart(for: completedAt)
        let sessions = completedSessions(in: week)
        let definitions = allDefinitions()
        upsert(weekStarting: week, sessions: sessions, muscleGroupMap: muscleMap(definitions))
    }

    // MARK: - Delete path

    /// Deletes the session and maintains the WeeklySnapshot for its week.
    /// Call this instead of modelContext.delete(session) from the view layer.
    func deleteSession(_ sessionID: PersistentIdentifier) {
        guard
            let session = modelContext.model(for: sessionID) as? WorkoutSession,
            let completedAt = session.completedAt
        else {
            // Incomplete / never-started session — just delete with no snapshot work.
            if let session = modelContext.model(for: sessionID) as? WorkoutSession {
                modelContext.delete(session)
                try? modelContext.save()
            }
            return
        }

        let week = weekStart(for: completedAt)
        modelContext.delete(session)
        try? modelContext.save()

        let remaining = completedSessions(in: week)
        if remaining.isEmpty {
            deleteSnapshot(for: week)
        } else {
            let definitions = allDefinitions()
            upsert(weekStarting: week, sessions: remaining, muscleGroupMap: muscleMap(definitions))
        }
    }

    // MARK: - Snapshot upsert

    private func upsert(
        weekStarting: Date,
        sessions: [WorkoutSession],
        muscleGroupMap: [String: [String]]
    ) {
        let snapshot = fetchSnapshot(for: weekStarting) ?? {
            let s = WeeklySnapshot(weekStarting: weekStarting)
            modelContext.insert(s)
            return s
        }()

        snapshot.totalSessions            = sessions.count
        snapshot.totalVolume              = totalVolume(sessions)
        snapshot.totalSets                = totalWorkingSets(sessions)
        snapshot.avgSessionDurationMinutes = avgDuration(sessions)
        snapshot.setsByMuscle             = setsByMuscle(sessions, map: muscleGroupMap)
        snapshot.topE1RMs                 = topE1RMs(sessions)
        snapshot.prCount                  = prCount(sessions)

        try? modelContext.save()
    }

    // MARK: - Snapshot field computation

    private func totalVolume(_ sessions: [WorkoutSession]) -> Double {
        let sets = sessions.flatMap { $0.exercises }.flatMap { $0.sets }
            .filter { $0.setType != .warmup && $0.weight > 0 }
        return sets.reduce(0) { $0 + $1.weight * Double($1.reps) }
    }

    private func totalWorkingSets(_ sessions: [WorkoutSession]) -> Int {
        sessions.flatMap { $0.exercises }.flatMap { $0.sets }
            .filter { $0.setType != .warmup && $0.weight > 0 }
            .count
    }

    private func avgDuration(_ sessions: [WorkoutSession]) -> Double {
        let durations: [Double] = sessions.compactMap { s in
            guard let start = s.startedAt, let end = s.completedAt, end > start else { return nil }
            return end.timeIntervalSince(start) / 60.0
        }
        guard !durations.isEmpty else { return 0 }
        return durations.reduce(0, +) / Double(durations.count)
    }

    private func setsByMuscle(
        _ sessions: [WorkoutSession],
        map: [String: [String]]
    ) -> [String: Int] {
        var counts: [String: Int] = [:]
        for snap in sessions.flatMap(\.exercises) {
            let muscles = map[snap.exerciseName] ?? []
            let working = snap.sets.filter { $0.setType != .warmup && $0.weight > 0 }
            for muscle in muscles {
                counts[muscle, default: 0] += working.count
            }
        }
        return counts
    }

    private func topE1RMs(_ sessions: [WorkoutSession]) -> [String: Double] {
        var best: [String: Double] = [:]
        for snap in sessions.flatMap(\.exercises) {
            for set in snap.sets where set.setType != .warmup && set.weight > 0 && set.reps > 0 {
                let v = e1rm(weight: set.weight, reps: set.reps)
                if v > (best[snap.exerciseName] ?? 0) {
                    best[snap.exerciseName] = v
                }
            }
        }
        return best
    }

    private func prCount(_ sessions: [WorkoutSession]) -> Int {
        sessions.flatMap { $0.exercises }.flatMap { $0.sets }
            .filter { $0.isPersonalRecord }
            .count
    }

    private func e1rm(weight: Double, reps: Int) -> Double {
        guard weight > 0, reps > 1 else { return weight }
        return weight * (1.0 + Double(reps) / 30.0)
    }

    // MARK: - Fetch helpers

    private func completedSessions(in week: Date) -> [WorkoutSession] {
        let end = week.addingTimeInterval(7 * 86400)
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { s in
                s.completedAt != nil &&
                s.completedAt! >= week &&
                s.completedAt! < end
            }
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func fetchSnapshot(for weekStarting: Date) -> WeeklySnapshot? {
        let end = weekStarting.addingTimeInterval(3600) // 1-hour window guards DST edges
        let descriptor = FetchDescriptor<WeeklySnapshot>(
            predicate: #Predicate { s in
                s.weekStarting >= weekStarting && s.weekStarting < end
            }
        )
        return (try? modelContext.fetch(descriptor))?.first
    }

    private func deleteSnapshot(for weekStarting: Date) {
        guard let snapshot = fetchSnapshot(for: weekStarting) else { return }
        modelContext.delete(snapshot)
        try? modelContext.save()
    }

    private func allDefinitions() -> [ExerciseDefinition] {
        (try? modelContext.fetch(FetchDescriptor<ExerciseDefinition>())) ?? []
    }

    private func muscleMap(_ definitions: [ExerciseDefinition]) -> [String: [String]] {
        Dictionary(uniqueKeysWithValues: definitions.map { ($0.name, $0.muscleGroups) })
    }

    // MARK: - Week boundary

    /// Returns Monday 00:00:00 local time of the week containing `date` (ISO 8601).
    private func weekStart(for date: Date) -> Date {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = .current
        return cal.dateInterval(of: .weekOfYear, for: date)?.start ?? date
    }
}
