// iOS 26+ only. No #available guards.

import SwiftUI
import SwiftData

struct FeaturedRoutineCard: View {
    let routine: RoutineTemplate
    let suggestion: FeaturedRoutineSuggestion
    let avgMinutes: Int?
    let onTap: () -> Void
    let onEdit: () -> Void

    @Environment(\.OrinCardMaterial) private var cardMaterial
    @State private var hapticTrigger = false

    var body: some View {
        Button {
            hapticTrigger.toggle()
            onTap()
        } label: {
            HStack(alignment: .center, spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Up Next")
                        .font(Typography.caption.weight(.semibold))
                        .foregroundStyle(Color.textMuted)
                        .textCase(.uppercase)

                    Text(suggestion.routineName)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(2)

                    if !routine.muscleGroupSummary.isEmpty {
                        Text(routine.muscleGroupSummary)
                            .font(Typography.caption)
                            .foregroundStyle(Color.textMuted)
                            .lineLimit(1)
                    }

                    Text(summaryLine)
                        .font(Typography.caption)
                        .foregroundStyle(Color.textMuted)
                        .lineLimit(1)
                }

                Spacer(minLength: Spacing.sm)

                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardMaterial, in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                    .strokeBorder(.white.opacity(0.13), lineWidth: 1)
            )
            .proGlass()
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
        .contextMenu {
            Button { onEdit() } label: {
                Label("Edit Routine", systemImage: "pencil")
            }
        }
    }

    private var summaryLine: String {
        var parts = ["\(suggestion.exerciseCount) exercises"]
        if let avgMinutes {
            parts.append("\(avgMinutes) min avg")
        }
        return parts.joined(separator: " • ")
    }
}

// MARK: - RoutineTemplate helpers

// MARK: - Previews

#Preview {
    let scenario = HomePreviewData.featured
    let routine = scenario.routines[0]
    let suggestion = scenario.featuredSuggestion!
    return FeaturedRoutineCard(
        routine: routine,
        suggestion: suggestion,
        avgMinutes: scenario.avgMinutes[routine.id],
        onTap: {},
        onEdit: {}
    )
    .padding()
    .environment(\.OrinCardMaterial, .regularMaterial)
    .modelContainer(scenario.container)
    .preferredColorScheme(.dark)
}

// MARK: - RoutineTemplate helpers

extension RoutineTemplate {
    var muscleGroupSummary: String {
        var seen = Set<String>()
        var ordered: [String] = []
        for entry in entries {
            for group in (entry.exerciseDefinition?.muscleGroups ?? []) {
                if seen.insert(group).inserted { ordered.append(group) }
            }
        }
        return ordered.prefix(3).joined(separator: " · ")
    }
}
