// iOS 26+ only. No #available guards.

import SwiftUI
import SwiftData

struct FeaturedRoutineCard: View {
    let routine: RoutineTemplate
    let suggestion: FeaturedRoutineSuggestion
    let avgMinutes: Int?
    let onTap: () -> Void
    let onEdit: () -> Void

    @Environment(\.OrinTheme) private var theme
    @Environment(\.OrinCardMaterial) private var cardMaterial
    @State private var hapticTrigger = false

    var body: some View {
        Button {
            hapticTrigger.toggle()
            onTap()
        } label: {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack(alignment: .top, spacing: Spacing.md) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(suggestion.routineName)
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.textPrimary)
                            .lineLimit(2)
                        Text(summaryLine)
                            .font(Typography.caption)
                            .foregroundStyle(Color.white.opacity(0.52))
                            .lineLimit(1)
                    }

                    Spacer(minLength: Spacing.sm)
                }

                Text("Start Workout")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.black.opacity(0.85))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(theme.accentColor, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
                    .fill(cardMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [theme.accentColor.opacity(0.22), theme.accentColor.opacity(0.10)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .overlay {
                        // Inner lift — simulates light hitting the top surface
                        RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.06), Color.clear],
                                    startPoint: .top,
                                    endPoint: .center
                                )
                            )
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
            }
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
        var parts: [String] = []
        if !routine.muscleGroupSummary.isEmpty {
            parts.append(routine.muscleGroupSummary)
        }
        parts.append("\(suggestion.exerciseCount) exercises")
        if let avgMinutes {
            parts.append("\(avgMinutes) min avg")
        }
        return parts.joined(separator: " · ")
    }
}

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
