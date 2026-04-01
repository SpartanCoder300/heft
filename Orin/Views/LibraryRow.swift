// iOS 26+ only. No #available guards.

import SwiftUI
import SwiftData

struct LibraryRow: View {
    let exercise: ExerciseDefinition
    let matchRanges: [Range<String.Index>]
    let accentColor: Color
    /// Number of times this exercise was added in the current picker session (removable).
    var addedCount: Int = 0
    /// Number of times this exercise already exists in the workout from before this session.
    var inUseCount: Int = 0
    let onTap: () -> Void
    let onEdit: () -> Void
    var onAddAgain: (() -> Void)? = nil

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: 2) {
                    HighlightedText(
                        text: exercise.name,
                        ranges: matchRanges,
                        highlightColor: accentColor
                    )
                    .font(Typography.body)

                    let subtitle = subtitleText
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(Typography.caption)
                            .foregroundStyle(Color.textFaint)
                    }
                }

                Spacer()

                if exercise.tracksWeight && exercise.currentPR > 0 {
                    Text(formattedPR(exercise.currentPR))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Color.textFaint)
                }

                if exercise.isTimed {
                    Image(systemName: "timer")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.textFaint)
                }

                if addedCount > 0 {
                    HStack(spacing: 3) {
                        if addedCount > 1 {
                            Text("\(addedCount)")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(accentColor)
                        }
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(accentColor)
                    }
                } else if inUseCount > 0 {
                    Text(inUseCount == 1 ? "In Workout" : "\(inUseCount)× In Workout")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.textFaint)
                }

                if exercise.isCustom {
                    Text("Custom")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(accentColor)
                        .textCase(.uppercase)
                        .tracking(0.4)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(accentColor.opacity(0.12), in: Capsule())
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            if let onAddAgain {
                Button(action: onAddAgain) {
                    Label("Add Again", systemImage: "plus.circle")
                }
            }
            Button(action: onEdit) {
                Label("Edit Exercise", systemImage: "pencil")
            }
        }
    }

    private func formattedPR(_ weight: Double) -> String {
        if weight == weight.rounded() { return "\(Int(weight)) lbs" }
        return String(format: "%.1f lbs", weight)
    }

    private var subtitleText: String {
        var parts: [String] = []
        if !exercise.equipmentType.isEmpty {
            parts.append(exercise.equipmentType)
        }
        let muscles = exercise.muscleGroups.prefix(2)
        if !muscles.isEmpty {
            parts.append(contentsOf: muscles)
        }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Previews

#Preview("Standard") {
    {
        let exercise = ExerciseDefinition(
            name: "Bench Press",
            muscleGroups: ["Chest", "Triceps"],
            equipmentType: "Barbell",
            weightIncrement: 2.5,
            isTimed: false
        )
        PersistenceController.previewContainer.mainContext.insert(exercise)
        return LibraryRow(exercise: exercise, matchRanges: [], accentColor: AccentTheme.midnight.accentColor, onTap: {}, onEdit: {})
            .padding()
            .preferredColorScheme(.dark)
    }()
}

#Preview("Custom + highlighted") {
    {
        let exercise = ExerciseDefinition(
            name: "Z Press",
            muscleGroups: ["Shoulders"],
            equipmentType: "Barbell",
            weightIncrement: 5,
            isTimed: false
        )
        exercise.isCustom = true
        PersistenceController.previewContainer.mainContext.insert(exercise)
        let range = "Z Press".range(of: "Z Pre")!
        return LibraryRow(exercise: exercise, matchRanges: [range], accentColor: AccentTheme.midnight.accentColor, addedCount: 1, onTap: {}, onEdit: {})
            .padding()
            .preferredColorScheme(.dark)
    }()
}
