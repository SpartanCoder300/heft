// iOS 26+ only. No #available guards.

import SwiftUI
import SwiftData

struct ExerciseHistorySessionCard: View {
    let snapshot: ExerciseSnapshot
    var previousE1RM: Double? = nil
    @Environment(\.ryftCardMaterial) private var cardMaterial

    private var sortedSets: [SetRecord] {
        snapshot.sets.sorted { $0.loggedAt < $1.loggedAt }
    }

    private var dateLabel: String {
        guard let date = snapshot.workoutSession?.completedAt else { return "Unknown Date" }
        let cal = Calendar.current
        if cal.isDateInToday(date)     { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        let sameYear = cal.component(.year, from: date) == cal.component(.year, from: .now)
        return sameYear
            ? date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
            : date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().year())
    }

    private var bestE1RM: Double? {
        let working = sortedSets.filter { $0.setType != .warmup && $0.weight > 0 && $0.reps > 0 }
        guard let top = working.max(by: {
            ExerciseDefinition.estimatedOneRepMax(weight: $0.weight, reps: $0.reps) <
            ExerciseDefinition.estimatedOneRepMax(weight: $1.weight, reps: $1.reps)
        }) else { return nil }
        let e1rm = ExerciseDefinition.estimatedOneRepMax(weight: top.weight, reps: top.reps)
        return e1rm > 0 ? e1rm : nil
    }

    private var bestE1RMLabel: String? {
        guard let e1rm = bestE1RM else { return nil }
        let v = e1rm.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(e1rm))" : String(format: "%.1f", e1rm)
        return "\(v) lbs e1RM"
    }

    private var e1rmDelta: Double? {
        guard let current = bestE1RM, let prev = previousE1RM, prev > 0 else { return nil }
        let delta = current - prev
        return delta == 0 ? nil : delta
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Header ─────────────────────────────────────────────────
            HStack(alignment: .firstTextBaseline) {
                Text(dateLabel)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer(minLength: Spacing.sm)
                HStack(spacing: Spacing.xs) {
                    if let delta = e1rmDelta {
                        Label(
                            delta > 0
                                ? "+\(formatDelta(delta))" : "-\(formatDelta(abs(delta)))",
                            systemImage: delta > 0 ? "arrow.up" : "arrow.down"
                        )
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(delta > 0 ? Color.green : Color.red)
                        .labelStyle(.titleAndIcon)
                    }
                    if let best = bestE1RMLabel {
                        Text(best)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm + 2)

            Divider().opacity(0.3)

            // ── Set rows ───────────────────────────────────────────────
            ForEach(Array(sortedSets.enumerated()), id: \.element.id) { idx, record in
                SetDetailRow(setNumber: idx + 1, record: record)
                if idx < sortedSets.count - 1 {
                    Divider()
                        .opacity(0.15)
                        .padding(.leading, Spacing.md)
                }
            }
        }
        .background(cardMaterial, in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
        .proGlass(specular: false)
    }

    private func formatDelta(_ value: Double) -> String {
        let v = value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value))" : String(format: "%.1f", value)
        return "\(v) lbs"
    }
}

// MARK: - Preview

#Preview {
    {
        let snapshot = HistoryRootPreviewData.exerciseHistorySnapshots.first!
        return ExerciseHistorySessionCard(snapshot: snapshot)
            .padding()
            .environment(\.ryftCardMaterial, .regularMaterial)
            .modelContainer(HistoryRootPreviewData.exerciseHistoryContainer)
            .preferredColorScheme(.dark)
    }()
}
