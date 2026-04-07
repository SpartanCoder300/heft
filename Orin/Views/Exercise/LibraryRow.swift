// iOS 26+ only. No #available guards.

import SwiftUI
import SwiftData

struct LibraryRow: View {
    let exercise: ExerciseDefinition
    let matchRanges: [Range<String.Index>]
    let accentColor: Color
    var isSelected: Bool = false
    var isPinnedSelection: Bool = false
    /// Number of times this exercise was added in the current picker session (removable).
    var addedCount: Int = 0
    /// Number of times this exercise already exists in the workout from before this session.
    var inUseCount: Int = 0
    /// Dims this row — used for selected exercises shown in the library section.
    var isDimmed: Bool = false
    let onTap: () -> Void
    let onEdit: () -> Void
    var onAddAgain: (() -> Void)? = nil

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.md) {
                    HighlightedText(
                        text: exercise.name,
                        ranges: matchRanges,
                        highlightColor: accentColor
                    )
                    .font(Typography.body)
                    .foregroundStyle(titleColor)

                    Spacer()

                    if isSelected {
                        checkmarkBadge
                    } else if inUseCount > 0 {
                        Text(inUseCount == 1 ? "In Workout" : "\(inUseCount)× In Workout")
                            .font(.system(size: 13))
                            .foregroundStyle(metadataColor)
                    }
                }

                HStack(spacing: Spacing.md) {
                    let subtitle = subtitleText
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(Typography.caption)
                            .foregroundStyle(subtitleColor)
                    }

                    Spacer()

                    if exercise.tracksWeight && exercise.currentPR > 0 {
                        Text(formattedPR(exercise.currentPR))
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(metadataColor)
                    }

                    if exercise.isTimed {
                        Image(systemName: "timer")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(metadataColor)
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
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(isDimmed ? 0.44 : 1.0)
        .animation(.easeOut(duration: 0.18), value: isSelected)
        .animation(.easeOut(duration: 0.18), value: isDimmed)
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

    private var titleColor: Color {
        if isSelected {
            return Color.primary.opacity(isPinnedSelection ? 0.96 : (isDimmed ? 0.62 : 0.9))
        }
        return Color.primary.opacity(isDimmed ? 0.68 : 0.84)
    }

    private var subtitleColor: Color {
        if isSelected {
            return Color.textMuted.opacity(isPinnedSelection ? 0.82 : (isDimmed ? 0.22 : 0.72))
        }
        return Color.textFaint.opacity(isDimmed ? 0.64 : 1.0)
    }

    private var metadataColor: Color {
        isSelected ? Color.textMuted.opacity(isPinnedSelection ? 0.84 : (isDimmed ? 0.24 : 0.74)) : Color.textFaint
    }

    private var checkmarkColor: Color {
        accentColor.opacity(isDimmed ? 0.4 : 0.82)
    }

    private var checkmarkBackgroundColor: Color {
        return accentColor.opacity(isDimmed ? 0.02 : 0.09)
    }

    @ViewBuilder
    private var checkmarkBadge: some View {
        ZStack {
            Circle()
                .fill(checkmarkBackgroundColor)
                .frame(width: 18, height: 18)

            if addedCount > 1 {
                Text("\(addedCount)")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(checkmarkColor)
            } else {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(checkmarkColor)
                    .contentTransition(.symbolEffect(.replace))
            }
        }
        .frame(width: 18, alignment: .trailing)
        .padding(.trailing, 2)
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
        return LibraryRow(exercise: exercise, matchRanges: [range], accentColor: AccentTheme.midnight.accentColor, isSelected: true, isPinnedSelection: true, addedCount: 1, onTap: {}, onEdit: {})
            .padding()
            .preferredColorScheme(.dark)
    }()
}
