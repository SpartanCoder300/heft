// iOS 26+ only. No #available guards.

import SwiftUI
import SwiftData

struct LibraryRow: View {
    let exercise: ExerciseDefinition
    let matchRanges: [Range<String.Index>]
    let accentColor: Color
    let statusText: String?
    let secondaryActionTitle: String?
    let secondaryAction: (() -> Void)?
    let onTap: () -> Void
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: Spacing.sm) {
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

                    if let statusText, !statusText.isEmpty {
                        Text(statusText)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color.textFaint)
                            .textCase(.uppercase)
                            .tracking(0.4)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.08), in: Capsule())
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
                Button(action: onEdit) {
                    Label("Edit Exercise", systemImage: "pencil")
                }
            }

            if let secondaryActionTitle,
               let secondaryAction {
                Button(secondaryActionTitle, action: secondaryAction)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.red)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.12), in: Capsule())
                    .buttonStyle(.plain)
                    .padding(.trailing, Spacing.md)
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
        return LibraryRow(exercise: exercise, matchRanges: [], accentColor: AccentTheme.midnight.accentColor, statusText: nil, secondaryActionTitle: nil, secondaryAction: nil, onTap: {}, onEdit: {})
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
        return LibraryRow(exercise: exercise, matchRanges: [range], accentColor: AccentTheme.midnight.accentColor, statusText: "Added", secondaryActionTitle: "Undo", secondaryAction: {}, onTap: {}, onEdit: {})
            .padding()
            .preferredColorScheme(.dark)
    }()
}
