// iOS 26+ only. No #available guards.

import Charts
import SwiftUI
import SwiftData

struct ExerciseHistoryChart: View {
    /// Snapshots sorted newest-first. The chart shows the oldest 12 in chronological order.
    let snapshots: [ExerciseSnapshot]

    private struct DataPoint: Identifiable {
        let id: UUID
        let date: Date
        let maxWeight: Double
        let hasPR: Bool
    }

    private var points: [DataPoint] {
        Array(snapshots.prefix(12))
            .reversed()
            .compactMap { snap in
                guard let date = snap.workoutSession?.completedAt else { return nil }
                let working = snap.sets.filter { $0.setType != .warmup && $0.weight > 0 && $0.reps > 0 }
                guard let best = working.max(by: {
                    ExerciseDefinition.estimatedOneRepMax(weight: $0.weight, reps: $0.reps) <
                    ExerciseDefinition.estimatedOneRepMax(weight: $1.weight, reps: $1.reps)
                }) else { return nil }
                let e1rm = ExerciseDefinition.estimatedOneRepMax(weight: best.weight, reps: best.reps)
                guard e1rm > 0 else { return nil }
                return DataPoint(
                    id: snap.id,
                    date: date,
                    maxWeight: e1rm,
                    hasPR: snap.sets.contains { $0.isPersonalRecord }
                )
            }
    }

    var body: some View {
        if points.count >= 2 {
            Chart(points) { point in
                LineMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value("e1RM", point.maxWeight)
                )
                .foregroundStyle(Color.ryftAmber.opacity(0.5))
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value("e1RM", point.maxWeight)
                )
                .foregroundStyle(point.hasPR ? Color.ryftAmber : .secondary)
                .symbolSize(point.hasPR ? 72 : 36)
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 3)) { value in
                    AxisGridLine()
                        .foregroundStyle(.quaternary)
                    AxisValueLabel {
                        if let w = value.as(Double.self) {
                            Text(w.truncatingRemainder(dividingBy: 1) == 0
                                 ? "\(Int(w))" : String(format: "%.1f", w))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .frame(height: 120)
        }
    }
}

// MARK: - Preview

#Preview {
    ExerciseHistoryChart(snapshots: HistoryRootPreviewData.exerciseHistorySnapshots)
        .padding()
        .modelContainer(HistoryRootPreviewData.exerciseHistoryContainer)
        .preferredColorScheme(.dark)
}
