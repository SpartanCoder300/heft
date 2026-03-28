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

struct ProgressAnalyticsReport {
    let weeklyVolume: [MuscleVolumeData]
    let progression: [ExerciseProgressionData]
    let frequency: [MuscleFrequencyData]
    let intensity: [IntensityData]
    let fatigue: [FatigueData]
    let prTracking: [PRTrackingData]
    let imbalances: [ImbalanceData]
    let adherence: AdherenceData
    let highlights: [String]
}

// MARK: - Engine

/// Pure value type. Feed it completed sessions + exercise definitions, call `compute()`.
/// No SwiftData queries inside — pass data in from the view layer.
struct ProgressAnalyticsEngine {
    let sessions: [WorkoutSession]          // all completed sessions, any order
    let definitions: [ExerciseDefinition]   // full library for muscle-group lookup

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

            guard let currentE1RM = bestE1RM(for: sorted.first?.sets ?? []) else { continue }

            // e1RM ~30 days ago: find the snapshot closest to 30 days back
            let recent = sorted.filter { $0.workoutSession!.completedAt! >= ago30 }
            let older  = sorted.filter {
                let d = $0.workoutSession!.completedAt!
                return d >= ago60 && d < ago30
            }
            let baseE1RM = bestE1RM(for: (older.first ?? recent.last)?.sets ?? []) ?? currentE1RM

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

        func avgIntensity(snaps: [ExerciseSnapshot]) -> Double? {
            let allWorking = snaps.flatMap { $0.sets }.filter { $0.setType != .warmup && $0.weight > 0 && $0.reps > 0 }
            guard !allWorking.isEmpty else { return nil }
            let bestAll = allWorking.map { e1rm(weight: $0.weight, reps: $0.reps) }.max() ?? 1
            guard bestAll > 0 else { return nil }
            let avg = allWorking.map { $0.weight }.reduce(0, +) / Double(allWorking.count)
            return avg / bestAll
        }

        var results: [IntensityData] = []
        for (name, snaps) in byExercise {
            let recent  = snaps.filter { $0.workoutSession?.completedAt.map { $0 >= ago14 } ?? false }
            let earlier = snaps.filter { ($0.workoutSession?.completedAt).map { $0 >= ago28 && $0 < ago14 } ?? false }

            guard let currentIntensity = avgIntensity(snaps: recent) else { continue }
            let priorIntensity = avgIntensity(snaps: earlier)

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
        let lowerMuscles: Set<String> = ["Legs"]

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
