// iOS 26+ only. No #available guards.

import SwiftUI

struct SummaryExerciseCard: View {
    let row: WorkoutSummaryViewModel.ExerciseRow
    let formatWeight: (Double) -> String
    var cardIndex: Int? = nil
    var onNameTap: (() -> Void)? = nil
    @Environment(\.OrinCardMaterial) private var cardMaterial

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.sm) {
            VStack(alignment: .leading, spacing: 3) {
                if let onNameTap {
                    Button(action: onNameTap) {
                        HStack(spacing: 4) {
                            Text(row.name)
                                .font(.body.weight(.medium))
                                .foregroundStyle(.primary)
                            Image(systemName: "chevron.right")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                } else {
                    Text(row.name)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                }
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: Spacing.sm)
            if row.hasPR {
                SummaryPRBadge(
                    weight: row.prWeight!,
                    reps: row.prReps!,
                    formatWeight: formatWeight
                )
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, 14)
        .background(cardMaterial, in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
        .proGlass(cardIndex: cardIndex)
    }

    private var subtitle: String {
        let sets = "\(row.setCount) \(row.setCount == 1 ? "set" : "sets")"
        guard row.maxWeight > 0 else { return sets }
        return "\(sets) · \(formatWeight(row.maxWeight)) lbs max"
    }
}

// MARK: - Previews

private let _formatWeight: (Double) -> String = { w in
    w.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(w))" : String(format: "%.1f", w)
}

#Preview("No PR") {
    let row = WorkoutSummaryViewModel.ExerciseRow(
        id: UUID(),
        name: "Squat",
        lineageID: nil,
        setCount: 3,
        maxWeight: 225,
        volume: 4050,
        prWeight: nil,
        prReps: nil
    )
    SummaryExerciseCard(row: row, formatWeight: _formatWeight)
        .padding()
        .environment(\.OrinCardMaterial, .regularMaterial)
        .preferredColorScheme(.dark)
}

#Preview("With PR") {
    let row = WorkoutSummaryViewModel.ExerciseRow(
        id: UUID(),
        name: "Bench Press",
        lineageID: nil,
        setCount: 4,
        maxWeight: 185,
        volume: 2960,
        prWeight: 185,
        prReps: 5
    )
    SummaryExerciseCard(row: row, formatWeight: _formatWeight)
        .padding()
        .environment(\.OrinCardMaterial, .regularMaterial)
        .preferredColorScheme(.dark)
}
