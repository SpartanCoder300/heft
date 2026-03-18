// iOS 26+ only. No #available guards.

import Foundation
import SwiftData

@Observable @MainActor
final class WorkoutSummaryViewModel {

    // MARK: - Types

    struct ExerciseRow: Identifiable {
        let id: UUID
        let name: String
        let setCount: Int
        let maxWeight: Double
        let volume: Double
        let prWeight: Double?
        let prReps: Int?

        var hasPR: Bool { prWeight != nil }
    }

    // MARK: - Private

    private let session: WorkoutSession

    // MARK: - Init

    init(session: WorkoutSession) {
        self.session = session
    }

    // MARK: - Computed stats

    var durationLabel: String {
        guard let start = session.startedAt, let end = session.completedAt else { return "—" }
        let minutes = max(1, Int(end.timeIntervalSince(start)) / 60)
        guard minutes >= 60 else { return "\(minutes) min" }
        let h = minutes / 60
        let m = minutes % 60
        return m == 0 ? "\(h) hr" : "\(h) hr \(m) min"
    }

    var totalVolume: Double {
        session.exercises
            .flatMap { $0.sets }
            .filter { $0.setType != .warmup }
            .reduce(0) { $0 + $1.weight * Double($1.reps) }
    }

    var totalVolumeLabel: String {
        let v = totalVolume
        if v >= 1_000 {
            return String(format: "%.1f K lbs", v / 1_000)
        }
        return String(format: "%.0f lbs", v)
    }

    var totalSets: Int {
        session.exercises.flatMap { $0.sets }.count
    }

    var exerciseRows: [ExerciseRow] {
        session.exercises
            .sorted { $0.order < $1.order }
            .map { snap in
                let working = snap.sets.filter { $0.setType != .warmup }
                let maxW = working.map(\.weight).max() ?? 0
                let vol = working.reduce(0.0) { $0 + $1.weight * Double($1.reps) }
                let pr = snap.sets.first { $0.isPersonalRecord }
                return ExerciseRow(
                    id: snap.id,
                    name: snap.exerciseName,
                    setCount: snap.sets.count,
                    maxWeight: maxW,
                    volume: vol,
                    prWeight: pr?.weight,
                    prReps: pr?.reps
                )
            }
    }

    // MARK: - Formatting

    func formatWeight(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(w))" : String(format: "%.1f", w)
    }
}
