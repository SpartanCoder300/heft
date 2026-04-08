// iOS 26+ only. No #available guards.

import Foundation

// MARK: - Output Types

struct MuscleVolumeData {
    let muscle: String
    let sets: Int
    let lastWeekSets: Int
    var trend: Int { sets - lastWeekSets }
    var status: VolumeStatus {
        switch sets {
        case ..<8:  return .low
        case 8...20: return .good
        default:    return .high
        }
    }
}

enum VolumeStatus: String { case low, good, high }

struct ExerciseProgressionData {
    let exercise: String
    let currentE1RM: Double
    let change30d: Double       // lbs; negative = regression
    let isPlateaued: Bool       // last 3 sessions within 2% of each other
}

struct MuscleFrequencyData {
    let muscle: String
    let sessionsPerWeek: Double // rolling 4-week average
}

struct IntensityData {
    enum Trend { case increasing, stable, decreasing }
    let exercise: String
    let avgIntensity: Double    // avg working weight / best e1RM (0–1)
    let trend: Trend
}

struct FatigueData {
    let muscle: String
    let volumeChangePct: Double  // this week vs last week, e.g. 0.30 = +30%
    let strengthChangePct: Double
    var isFlagged: Bool { volumeChangePct > 0.25 && strengthChangePct < -0.05 }
}

struct PRTrackingData {
    let exercise: String
    let lastPRDaysAgo: Int?
    let prsLast30Days: Int
}

struct ImbalanceData {
    enum Kind: String { case pushPull = "push_pull", upperLower = "upper_lower" }
    let kind: Kind
    let labelA: String          // e.g. "Push"
    let labelB: String          // e.g. "Pull"
    let setsA: Int
    let setsB: Int
    var ratio: Double { setsB > 0 ? Double(setsA) / Double(setsB) : Double(setsA) }
    var isImbalanced: Bool { ratio > 1.5 || ratio < 0.67 }
}

struct AdherenceData {
    let completedLast28Days: Int
    var avgPerWeek: Double { Double(completedLast28Days) / 4.0 }
}

struct BodyWeightTrendData {
    let currentWeight: Double           // most recent entry in lbs
    let change30d: Double               // lbs; negative = loss
    let change90d: Double
    let avgWeight30d: Double
    /// e1RM / body weight for key lifts. Empty if no body weight logged.
    let strengthRatios: [String: Double]
}

struct SessionDurationData {
    enum Trend { case increasing, stable, decreasing }
    let avgMinutes: Double              // rolling 4-week average
    let trend: Trend                    // vs prior 4 weeks
    let longestRecentMinutes: Double    // single longest session in last 28 days
}

struct MuscleRecoveryData {
    let muscle: String
    let daysSinceLastTrained: Int
    /// Historical average days between sessions for this muscle (rolling all-time).
    let avgRestDays: Double
}

struct RoutineAdherenceData {
    let routineID: UUID
    let routineName: String
    let completionsLast28Days: Int
    /// Historical average days between completions. Nil if fewer than 2 completions.
    let avgIntervalDays: Double?
    /// Days since last completion. Nil if never completed.
    let daysSinceLast: Int?
    /// completionsLast28Days / expected count based on avgIntervalDays. Clamped 0–1.
    var adherenceRate: Double {
        guard let interval = avgIntervalDays, interval > 0 else { return 0 }
        let expected = 28.0 / interval
        return min(1.0, Double(completionsLast28Days) / expected)
    }
}

struct RepRangeDistributionData {
    let muscle: String
    let strengthPct: Double     // sets with 1–5 reps  (0–1)
    let hypertrophyPct: Double  // sets with 6–12 reps (0–1)
    let endurancePct: Double    // sets with 13+ reps  (0–1)
    let totalSets: Int
}

struct DeloadReadiness {
    enum State { case fresh, accumulating, recommended }
    let score: Double               // 0–1; higher = more need for deload
    let state: State                // bucketed from score
    let fatigueFlags: Int           // muscles with isFlagged
    let plateauedExercises: Int     // exercises with isPlateaued
    let daysSinceLastPR: Int?       // nil if no PRs ever logged
    let decliningIntensityCount: Int // exercises with trend == .decreasing
}

struct TrainingDensityData {
    enum Trend { case increasing, stable, decreasing }
    let setsPerHour: Double     // rolling 4-week average
    let trend: Trend            // vs prior 4 weeks
}

struct ProgressAnalyticsReport {
    let weeklyVolume: [MuscleVolumeData]
    let progression: [ExerciseProgressionData]
    let frequency: [MuscleFrequencyData]
    let intensity: [IntensityData]
    let fatigue: [FatigueData]
    let prTracking: [PRTrackingData]
    let imbalances: [ImbalanceData]
    let adherence: AdherenceData
    let bodyWeightTrend: BodyWeightTrendData?
    let sessionDuration: SessionDurationData?
    let muscleRecovery: [MuscleRecoveryData]
    let routineAdherence: [RoutineAdherenceData]
    let repRangeDistribution: [RepRangeDistributionData]
    let deloadReadiness: DeloadReadiness
    let trainingDensity: TrainingDensityData?
    let highlights: [String]
}

// MARK: - Engine

/// Pure value type. Feed it completed sessions + exercise definitions, call `compute()`.
/// No SwiftData queries inside — pass data in from the view layer.
struct ProgressAnalyticsEngine {
    let sessions: [WorkoutSession]          // all completed sessions, any order
    let definitions: [ExerciseDefinition]   // full library for muscle-group lookup
    var bodyWeightEntries: [BodyWeightEntry] = []
    var routines: [RoutineTemplate] = []

    // MARK: - Public

    func compute() -> ProgressAnalyticsReport {
        let volume   = computeWeeklyVolume()
        let progress = computeProgression()
        let freq     = computeFrequency()
        let intens   = computeIntensity()
        let fatigue  = computeFatigue(volume: volume, progression: progress)
        let prs      = computePRTracking()
        let imbal    = computeImbalances()
        let adhere   = computeAdherence()
        let bwTrend  = computeBodyWeightTrend(progression: progress)
        let duration = computeSessionDuration()
        let recovery = computeMuscleRecovery()
        let routineAdh = computeRoutineAdherence()
        let repRanges  = computeRepRangeDistribution()
        let deload     = computeDeloadReadiness(fatigue: fatigue, progression: progress, intensity: intens, prs: prs)
        let density    = computeTrainingDensity()
        let hi       = generateHighlights(
            volume: volume, progression: progress,
            fatigue: fatigue, imbalances: imbal, prs: prs
        )
        return ProgressAnalyticsReport(
            weeklyVolume: volume,
            progression: progress,
            frequency: freq,
            intensity: intens,
            fatigue: fatigue,
            prTracking: prs,
            imbalances: imbal,
            adherence: adhere,
            bodyWeightTrend: bwTrend,
            sessionDuration: duration,
            muscleRecovery: recovery,
            routineAdherence: routineAdh,
            repRangeDistribution: repRanges,
            deloadReadiness: deload,
            trainingDensity: density,
            highlights: hi
        )
    }

    // MARK: - Private helpers

    private var muscleGroupMap: [String: [String]] {
        Dictionary(uniqueKeysWithValues: definitions.map { ($0.name, $0.muscleGroups) })
    }

    private var completed: [WorkoutSession] {
        sessions.filter { $0.completedAt != nil }
    }

    /// Returns sessions whose completedAt falls within the given date interval.
    private func sessions(in range: ClosedRange<Date>) -> [WorkoutSession] {
        completed.filter { range.contains($0.completedAt!) }
    }

    /// Working sets only (no warmups, weight > 0).
    private func workingSets(in session: WorkoutSession) -> [SetRecord] {
        session.exercises.flatMap { $0.sets }.filter { $0.setType != .warmup && $0.weight > 0 }
    }

    private func e1rm(weight: Double, reps: Int) -> Double {
        ExerciseDefinition.estimatedOneRepMax(weight: weight, reps: reps)
    }

    private func bestE1RM(for sets: [SetRecord]) -> Double? {
        let working = sets.filter { $0.setType != .warmup && $0.weight > 0 && $0.reps > 0 }
        guard let top = working.max(by: {
            e1rm(weight: $0.weight, reps: $0.reps) < e1rm(weight: $1.weight, reps: $1.reps)
        }) else { return nil }
        let v = e1rm(weight: top.weight, reps: top.reps)
        return v > 0 ? v : nil
    }

    // MARK: - 1. Weekly volume

    private func computeWeeklyVolume() -> [MuscleVolumeData] {
        let now      = Date.now
        let thisWeek = now.addingTimeInterval(-7 * 86400)...now
        let lastWeek = now.addingTimeInterval(-14 * 86400)...now.addingTimeInterval(-7 * 86400)

        func setCounts(in range: ClosedRange<Date>) -> [String: Int] {
            var counts: [String: Int] = [:]
            for session in sessions(in: range) {
                for snap in session.exercises {
                    let muscles = muscleGroupMap[snap.exerciseName] ?? []
                    let working = snap.sets.filter { $0.setType != .warmup && $0.weight > 0 }
                    for muscle in muscles {
                        counts[muscle, default: 0] += working.count
                    }
                }
            }
            return counts
        }

        let thisCounts = setCounts(in: thisWeek)
        let lastCounts = setCounts(in: lastWeek)
        let allMuscles = Set(thisCounts.keys).union(lastCounts.keys)

        return allMuscles.sorted().map { muscle in
            MuscleVolumeData(
                muscle: muscle,
                sets: thisCounts[muscle, default: 0],
                lastWeekSets: lastCounts[muscle, default: 0]
            )
        }
    }

    // MARK: - 2. Exercise progression

    private func computeProgression() -> [ExerciseProgressionData] {
        let now     = Date.now
        let ago30   = now.addingTimeInterval(-30 * 86400)
        let ago60   = now.addingTimeInterval(-60 * 86400)

        // Group snapshots by exercise name, newest-first
        var byExercise: [String: [ExerciseSnapshot]] = [:]
        for session in completed {
            for snap in session.exercises {
                byExercise[snap.exerciseName, default: []].append(snap)
            }
        }

        var results: [ExerciseProgressionData] = []
        for (name, snaps) in byExercise {
            let sorted = snaps
                .filter { $0.workoutSession?.completedAt != nil }
                .sorted { $0.workoutSession!.completedAt! > $1.workoutSession!.completedAt! }

            // Use best e1RM across last 3 sessions so a single bad day doesn't deflate current strength.
            let currentE1RM = bestE1RM(for: sorted.prefix(3).flatMap(\.sets))
            guard let currentE1RM else { continue }

            // e1RM ~30 days ago: best across the 2-3 sessions closest to the 30-day mark.
            let recent = sorted.filter { $0.workoutSession!.completedAt! >= ago30 }
            let older  = sorted.filter {
                let d = $0.workoutSession!.completedAt!
                return d >= ago60 && d < ago30
            }
            // Use up to 3 sessions from the base window; fall back to the oldest recent session.
            let baseSnaps = older.isEmpty ? Array(recent.suffix(1)) : Array(older.prefix(3))
            let baseE1RM = bestE1RM(for: baseSnaps.flatMap(\.sets)) ?? currentE1RM

            // Plateau: last 3 sessions all within 2% of each other
            let last3E1RMs = recent.prefix(3).compactMap { bestE1RM(for: $0.sets) }
            let isPlateaued: Bool = {
                guard last3E1RMs.count == 3, let maxV = last3E1RMs.max(), maxV > 0 else { return false }
                return last3E1RMs.allSatisfy { abs($0 - maxV) / maxV < 0.02 }
            }()

            results.append(ExerciseProgressionData(
                exercise: name,
                currentE1RM: currentE1RM,
                change30d: currentE1RM - baseE1RM,
                isPlateaued: isPlateaued
            ))
        }
        return results.sorted { $0.exercise < $1.exercise }
    }

    // MARK: - 3. Muscle frequency

    private func computeFrequency() -> [MuscleFrequencyData] {
        let cutoff = Date.now.addingTimeInterval(-28 * 86400)
        let recent = completed.filter { $0.completedAt! >= cutoff }

        var sessionsByMuscle: [String: Set<UUID>] = [:]
        for session in recent {
            for snap in session.exercises {
                let muscles = muscleGroupMap[snap.exerciseName] ?? []
                for muscle in muscles {
                    sessionsByMuscle[muscle, default: []].insert(session.id)
                }
            }
        }

        return sessionsByMuscle
            .sorted { $0.key < $1.key }
            .map { muscle, sessionIDs in
                MuscleFrequencyData(
                    muscle: muscle,
                    sessionsPerWeek: Double(sessionIDs.count) / 4.0
                )
            }
    }

    // MARK: - 4. Intensity profile

    private func computeIntensity() -> [IntensityData] {
        let now      = Date.now
        let ago14    = now.addingTimeInterval(-14 * 86400)
        let ago28    = now.addingTimeInterval(-28 * 86400)

        var byExercise: [String: [ExerciseSnapshot]] = [:]
        for session in completed {
            for snap in session.exercises { byExercise[snap.exerciseName, default: []].append(snap) }
        }

        // allTimeSnaps is passed in so the denominator (best ever e1RM) stays fixed across both
        // time windows, making the trend comparison stable.
        func avgIntensity(snaps: [ExerciseSnapshot], allTimeSnaps: [ExerciseSnapshot]) -> Double? {
            let allWorking = snaps.flatMap { $0.sets }.filter { $0.setType != .warmup && $0.weight > 0 && $0.reps > 0 }
            guard !allWorking.isEmpty else { return nil }
            let allTimeSets = allTimeSnaps.flatMap { $0.sets }
                .filter { $0.setType != .warmup && $0.weight > 0 && $0.reps > 0 }
            let allTimeBest = allTimeSets.map { e1rm(weight: $0.weight, reps: $0.reps) }.max() ?? 1
            guard allTimeBest > 0 else { return nil }
            let avg = allWorking.map { $0.weight }.reduce(0, +) / Double(allWorking.count)
            return avg / allTimeBest
        }

        var results: [IntensityData] = []
        for (name, snaps) in byExercise {
            let recent  = snaps.filter { $0.workoutSession?.completedAt.map { $0 >= ago14 } ?? false }
            let earlier = snaps.filter { ($0.workoutSession?.completedAt).map { $0 >= ago28 && $0 < ago14 } ?? false }

            guard let currentIntensity = avgIntensity(snaps: recent, allTimeSnaps: snaps) else { continue }
            let priorIntensity = avgIntensity(snaps: earlier, allTimeSnaps: snaps)

            let trend: IntensityData.Trend = {
                guard let prior = priorIntensity else { return .stable }
                let delta = currentIntensity - prior
                if delta > 0.03  { return .increasing }
                if delta < -0.03 { return .decreasing }
                return .stable
            }()

            results.append(IntensityData(exercise: name, avgIntensity: currentIntensity, trend: trend))
        }
        return results.sorted { $0.exercise < $1.exercise }
    }

    // MARK: - 5. Fatigue indicators

    private func computeFatigue(
        volume: [MuscleVolumeData],
        progression: [ExerciseProgressionData]
    ) -> [FatigueData] {
        // Strength change per muscle: average change30d across exercises in that muscle
        var strengthByMuscle: [String: [Double]] = [:]
        for prog in progression {
            let muscles = muscleGroupMap[prog.exercise] ?? []
            for muscle in muscles {
                if prog.currentE1RM > 0 {
                    strengthByMuscle[muscle, default: []].append(prog.change30d / prog.currentE1RM)
                }
            }
        }

        return volume.compactMap { vol in
            guard vol.lastWeekSets > 0 else { return nil }
            let volChange = Double(vol.sets - vol.lastWeekSets) / Double(vol.lastWeekSets)
            let strChanges = strengthByMuscle[vol.muscle] ?? []
            let strChange = strChanges.isEmpty ? 0 : strChanges.reduce(0, +) / Double(strChanges.count)
            return FatigueData(muscle: vol.muscle, volumeChangePct: volChange, strengthChangePct: strChange)
        }
    }

    // MARK: - 6. PR tracking

    private func computePRTracking() -> [PRTrackingData] {
        let now    = Date.now
        let ago30  = now.addingTimeInterval(-30 * 86400)

        var prSetsByExercise: [String: [(date: Date, isRecent: Bool)]] = [:]
        for session in completed {
            guard let date = session.completedAt else { continue }
            for snap in session.exercises {
                let prs = snap.sets.filter { $0.isPersonalRecord }
                if !prs.isEmpty {
                    prSetsByExercise[snap.exerciseName, default: []].append(
                        (date: date, isRecent: date >= ago30)
                    )
                }
            }
        }

        return prSetsByExercise.sorted { $0.key < $1.key }.map { name, entries in
            let sorted     = entries.sorted { $0.date > $1.date }
            let daysAgo    = sorted.first.map { Int(now.timeIntervalSince($0.date) / 86400) }
            let recentCount = entries.filter { $0.isRecent }.count
            return PRTrackingData(exercise: name, lastPRDaysAgo: daysAgo, prsLast30Days: recentCount)
        }
    }

    // MARK: - 7. Imbalance detection

    private func computeImbalances() -> [ImbalanceData] {
        let now      = Date.now
        let cutoff   = now.addingTimeInterval(-28 * 86400)
        let recent   = completed.filter { $0.completedAt! >= cutoff }

        let pushMuscles: Set<String> = ["Chest", "Shoulders", "Triceps"]
        let pullMuscles: Set<String> = ["Back", "Biceps"]
        let upperMuscles: Set<String> = ["Chest", "Back", "Shoulders", "Biceps", "Triceps", "Forearms"]
        let lowerMuscles: Set<String> = ["Legs", "Glutes", "Hamstrings", "Quads", "Calves"]

        func sets(for muscles: Set<String>, in sessions: [WorkoutSession]) -> Int {
            sessions.flatMap { $0.exercises }.reduce(0) { total, snap in
                let matched = (muscleGroupMap[snap.exerciseName] ?? []).contains { muscles.contains($0) }
                guard matched else { return total }
                return total + snap.sets.filter { $0.setType != .warmup && $0.weight > 0 }.count
            }
        }

        let pushSets  = sets(for: pushMuscles,  in: recent)
        let pullSets  = sets(for: pullMuscles,  in: recent)
        let upperSets = sets(for: upperMuscles, in: recent)
        let lowerSets = sets(for: lowerMuscles, in: recent)

        return [
            ImbalanceData(kind: .pushPull,   labelA: "Push", labelB: "Pull",  setsA: pushSets,  setsB: pullSets),
            ImbalanceData(kind: .upperLower,  labelA: "Upper", labelB: "Lower", setsA: upperSets, setsB: lowerSets),
        ]
    }

    // MARK: - 8. Adherence

    private func computeAdherence() -> AdherenceData {
        let cutoff = Date.now.addingTimeInterval(-28 * 86400)
        let count  = completed.filter { $0.completedAt! >= cutoff }.count
        return AdherenceData(completedLast28Days: count)
    }

    // MARK: - 9. Body weight trend

    private func computeBodyWeightTrend(progression: [ExerciseProgressionData]) -> BodyWeightTrendData? {
        let sorted = bodyWeightEntries.sorted { $0.date > $1.date }
        guard let latest = sorted.first else { return nil }

        let now   = Date.now
        let ago30 = now.addingTimeInterval(-30 * 86400)
        let ago90 = now.addingTimeInterval(-90 * 86400)

        let current = latest.weight
        let entries30 = sorted.filter { $0.date >= ago30 }

        let avg30 = entries30.isEmpty ? current
            : entries30.map(\.weight).reduce(0, +) / Double(entries30.count)

        let base30 = sorted.first(where: { $0.date <= ago30 })?.weight ?? current
        let base90 = sorted.first(where: { $0.date <= ago90 })?.weight ?? current

        var ratios: [String: Double] = [:]
        if current > 0 {
            for prog in progression {
                ratios[prog.exercise] = prog.currentE1RM / current
            }
        }

        return BodyWeightTrendData(
            currentWeight: current,
            change30d: current - base30,
            change90d: current - base90,
            avgWeight30d: avg30,
            strengthRatios: ratios
        )
    }

    // MARK: - 10. Session duration

    private func computeSessionDuration() -> SessionDurationData? {
        let now    = Date.now
        let ago28  = now.addingTimeInterval(-28 * 86400)
        let ago56  = now.addingTimeInterval(-56 * 86400)

        func minutes(for sessions: [WorkoutSession]) -> [Double] {
            sessions.compactMap { s -> Double? in
                guard let start = s.startedAt, let end = s.completedAt, end > start else { return nil }
                return end.timeIntervalSince(start) / 60.0
            }
        }

        let recent   = completed.filter { $0.completedAt! >= ago28 }
        let earlier  = completed.filter { $0.completedAt! >= ago56 && $0.completedAt! < ago28 }
        let recentMins  = minutes(for: recent)
        let earlierMins = minutes(for: earlier)

        guard !recentMins.isEmpty else { return nil }

        let avgRecent  = recentMins.reduce(0, +) / Double(recentMins.count)
        let avgEarlier = earlierMins.isEmpty ? avgRecent
            : earlierMins.reduce(0, +) / Double(earlierMins.count)
        let longest    = recentMins.max() ?? avgRecent

        let trend: SessionDurationData.Trend = {
            let delta = avgRecent - avgEarlier
            if delta > 5  { return .increasing }
            if delta < -5 { return .decreasing }
            return .stable
        }()

        return SessionDurationData(avgMinutes: avgRecent, trend: trend, longestRecentMinutes: longest)
    }

    // MARK: - 11. Muscle recovery

    private func computeMuscleRecovery() -> [MuscleRecoveryData] {
        let now = Date.now

        // Build per-muscle list of session dates, sorted newest-first.
        // Collect muscles per session first to avoid duplicate dates when multiple exercises
        // in the same session target the same muscle.
        var datesByMuscle: [String: [Date]] = [:]
        for session in completed {
            guard let date = session.completedAt else { continue }
            var musclesThisSession: Set<String> = []
            for snap in session.exercises {
                for muscle in muscleGroupMap[snap.exerciseName] ?? [] {
                    musclesThisSession.insert(muscle)
                }
            }
            for muscle in musclesThisSession {
                datesByMuscle[muscle, default: []].append(date)
            }
        }

        return datesByMuscle.sorted { $0.key < $1.key }.compactMap { muscle, dates in
            let sorted = dates.sorted(by: >)
            guard let lastDate = sorted.first else { return nil }
            let daysSince = Int(now.timeIntervalSince(lastDate) / 86400)

            // Average gap between consecutive sessions
            let avgRest: Double = {
                guard sorted.count >= 2 else { return 0 }
                let gaps = zip(sorted, sorted.dropFirst()).map { $0.timeIntervalSince($1) / 86400 }
                return gaps.reduce(0, +) / Double(gaps.count)
            }()

            return MuscleRecoveryData(muscle: muscle, daysSinceLastTrained: daysSince, avgRestDays: avgRest)
        }
    }

    // MARK: - 12. Per-routine adherence

    private func computeRoutineAdherence() -> [RoutineAdherenceData] {
        let now   = Date.now
        let ago28 = now.addingTimeInterval(-28 * 86400)

        // Group completed session dates by routineTemplateId
        var datesByRoutine: [UUID: [Date]] = [:]
        for session in completed {
            guard let rid = session.routineTemplateId, let date = session.completedAt else { continue }
            datesByRoutine[rid, default: []].append(date)
        }

        return routines.map { routine in
            let allDates   = (datesByRoutine[routine.id] ?? []).sorted(by: >)
            let recent     = allDates.filter { $0 >= ago28 }
            let lastDate   = allDates.first
            let daysSince  = lastDate.map { Int(now.timeIntervalSince($0) / 86400) }

            let avgInterval: Double? = {
                guard allDates.count >= 2 else { return nil }
                let gaps = zip(allDates, allDates.dropFirst()).map { $0.timeIntervalSince($1) / 86400 }
                return gaps.reduce(0, +) / Double(gaps.count)
            }()

            return RoutineAdherenceData(
                routineID: routine.id,
                routineName: routine.name,
                completionsLast28Days: recent.count,
                avgIntervalDays: avgInterval,
                daysSinceLast: daysSince
            )
        }
    }

    // MARK: - 13. Rep range distribution

    private func computeRepRangeDistribution() -> [RepRangeDistributionData] {
        let cutoff = Date.now.addingTimeInterval(-28 * 86400)
        let recent = completed.filter { $0.completedAt! >= cutoff }

        var setsByMuscle: [String: (strength: Int, hypertrophy: Int, endurance: Int)] = [:]
        for session in recent {
            for snap in session.exercises {
                let muscles = muscleGroupMap[snap.exerciseName] ?? []
                // weight > 0 excluded to include bodyweight exercises; reps > 0 excludes timed sets.
                let working = snap.sets.filter { $0.setType != .warmup && $0.reps > 0 }
                for set in working {
                    for muscle in muscles {
                        var counts = setsByMuscle[muscle] ?? (0, 0, 0)
                        switch set.reps {
                        case 1...5:   counts.strength     += 1
                        case 6...12:  counts.hypertrophy  += 1
                        default:      counts.endurance    += 1
                        }
                        setsByMuscle[muscle] = counts
                    }
                }
            }
        }

        return setsByMuscle.sorted { $0.key < $1.key }.compactMap { muscle, counts in
            let total = counts.strength + counts.hypertrophy + counts.endurance
            guard total > 0 else { return nil }
            let d = Double(total)
            return RepRangeDistributionData(
                muscle: muscle,
                strengthPct: Double(counts.strength) / d,
                hypertrophyPct: Double(counts.hypertrophy) / d,
                endurancePct: Double(counts.endurance) / d,
                totalSets: total
            )
        }
    }

    // MARK: - 14. Deload readiness

    private func computeDeloadReadiness(
        fatigue: [FatigueData],
        progression: [ExerciseProgressionData],
        intensity: [IntensityData],
        prs: [PRTrackingData]
    ) -> DeloadReadiness {
        let flaggedCount    = fatigue.filter(\.isFlagged).count
        let plateauedCount  = progression.filter(\.isPlateaued).count
        let decliningCount  = intensity.filter { $0.trend == .decreasing }.count

        let daysSincePR: Int? = prs
            .compactMap(\.lastPRDaysAgo)
            .min()

        // Weighted composite: fatigue flags carry the most weight
        let fatigueScore    = min(1.0, Double(flaggedCount) / 3.0)   * 0.40
        let plateauScore    = min(1.0, Double(plateauedCount) / 4.0) * 0.25
        let intensityScore  = min(1.0, Double(decliningCount) / 4.0) * 0.20
        let prDroughtScore: Double = {
            guard let days = daysSincePR else { return 0.15 }  // no PRs ever = max drought
            switch days {
            case ..<14:  return 0.0
            case 14..<30: return 0.075
            default:     return 0.15
            }
        }()

        let score = fatigueScore + plateauScore + intensityScore + prDroughtScore

        let state: DeloadReadiness.State = {
            if score >= 0.55 { return .recommended }
            if score >= 0.25 { return .accumulating }
            return .fresh
        }()

        return DeloadReadiness(
            score: score,
            state: state,
            fatigueFlags: flaggedCount,
            plateauedExercises: plateauedCount,
            daysSinceLastPR: daysSincePR,
            decliningIntensityCount: decliningCount
        )
    }

    // MARK: - 15. Training density

    private func computeTrainingDensity() -> TrainingDensityData? {
        let now   = Date.now
        let ago28 = now.addingTimeInterval(-28 * 86400)
        let ago56 = now.addingTimeInterval(-56 * 86400)

        func density(for sessions: [WorkoutSession]) -> Double? {
            let pairs: [(sets: Int, hours: Double)] = sessions.compactMap { s in
                guard let start = s.startedAt, let end = s.completedAt, end > start else { return nil }
                let hours = end.timeIntervalSince(start) / 3600.0
                guard hours > 0 else { return nil }
                let sets = workingSets(in: s).count
                return (sets, hours)
            }
            guard !pairs.isEmpty else { return nil }
            let totalSets  = pairs.map(\.sets).reduce(0, +)
            let totalHours = pairs.map(\.hours).reduce(0, +)
            return totalHours > 0 ? Double(totalSets) / totalHours : nil
        }

        let recent  = completed.filter { $0.completedAt! >= ago28 }
        let earlier = completed.filter { $0.completedAt! >= ago56 && $0.completedAt! < ago28 }

        guard let recentDensity = density(for: recent) else { return nil }
        let priorDensity = density(for: earlier)

        let trend: TrainingDensityData.Trend = {
            guard let prior = priorDensity else { return .stable }
            let delta = recentDensity - prior
            if delta > 2  { return .increasing }
            if delta < -2 { return .decreasing }
            return .stable
        }()

        return TrainingDensityData(setsPerHour: recentDensity, trend: trend)
    }

    // MARK: - Highlights (plain English for AI context)

    private func generateHighlights(
        volume: [MuscleVolumeData],
        progression: [ExerciseProgressionData],
        fatigue: [FatigueData],
        imbalances: [ImbalanceData],
        prs: [PRTrackingData]
    ) -> [String] {
        var highlights: [String] = []

        // Plateaus
        for p in progression where p.isPlateaued {
            highlights.append("\(p.exercise) e1RM has stalled over the last 3 sessions")
        }

        // Strength regressions
        for p in progression where p.change30d < -5 {
            let pct = Int(abs(p.change30d / p.currentE1RM) * 100)
            highlights.append("\(p.exercise) e1RM down \(pct)% over the last 30 days")
        }

        // Volume drops
        for v in volume where v.lastWeekSets > 0 && v.trend < -4 {
            highlights.append("\(v.muscle) volume dropped from \(v.lastWeekSets) to \(v.sets) sets this week")
        }

        // Low volume muscles
        for v in volume where v.status == .low && v.sets > 0 {
            highlights.append("\(v.muscle) at only \(v.sets) working sets this week — below recommended range")
        }

        // Fatigue flags
        for f in fatigue where f.isFlagged {
            let volPct = Int(f.volumeChangePct * 100)
            let strPct = Int(abs(f.strengthChangePct) * 100)
            highlights.append("\(f.muscle): volume up \(volPct)% while strength down \(strPct)% — possible fatigue")
        }

        // Imbalances
        for imb in imbalances where imb.isImbalanced {
            let r = String(format: "%.1f", imb.ratio)
            highlights.append("\(imb.labelA)/\(imb.labelB) ratio is \(r):1 — imbalanced (\(imb.setsA) vs \(imb.setsB) sets)")
        }

        // No recent PRs
        let staleExercises = prs.filter { ($0.lastPRDaysAgo ?? 0) > 30 && $0.prsLast30Days == 0 }
        if staleExercises.count > 2 {
            highlights.append("No PRs in the last 30 days across \(staleExercises.count) tracked lifts")
        }

        return highlights
    }
}
