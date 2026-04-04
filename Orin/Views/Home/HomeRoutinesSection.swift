// iOS 26+ only. No #available guards.

import SwiftUI
import SwiftData

struct HomeRoutinesSection: View {
    let routines: [RoutineTemplate]
    let avgMinutes: [UUID: Int]
    let featured: FeaturedRoutineSuggestion?
    let onStart: (UUID) -> Void
    let onEdit: (RoutineTemplate) -> Void
    let onNew: () -> Void
    let onStartEmpty: () -> Void

    var body: some View {
        let nonFeatured = routines.filter { $0.id != featured?.routineID }
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if routines.isEmpty {
                EmptyRoutinesPrompt(onTap: onNew)
            } else {
                if !nonFeatured.isEmpty {
                    SectionHeader(title: featured != nil ? "Other routines" : "Routines")
                    ForEach(nonFeatured) { routine in
                        RoutineListRow(
                            routine: routine,
                            avgMinutes: avgMinutes[routine.id],
                            onTap: { onStart(routine.id) },
                            onEdit: { onEdit(routine) }
                        )
                    }
                    .opacity(0.72)
                }
                NewRoutineCard(action: onNew)
            }

            Button(action: onStartEmpty) {
                Text("or start empty workout")
                    .font(Typography.caption)
                    .foregroundStyle(Color.textFaint)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.xs)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - New Routine Card

private struct NewRoutineCard: View {
    let action: () -> Void
    @Environment(\.OrinTheme) private var theme

    var body: some View {
        Button(action: action) {
            Label("New Routine", systemImage: "plus.circle.fill")
                .font(Typography.body.weight(.medium))
                .foregroundStyle(theme.accentColor)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
        }
        .buttonStyle(.plain)
    }
}

#Preview("Empty state") {
    HomeRoutinesSection(
        routines: [],
        avgMinutes: [:],
        featured: nil,
        onStart: { _ in },
        onEdit: { _ in },
        onNew: {},
        onStartEmpty: {}
    )
    .padding()
    .preferredColorScheme(.dark)
}

#Preview("With routines") {
    let scenario = HomePreviewData.featured

    NavigationStack {
        HomeRoutinesSection(
            routines: scenario.routines,
            avgMinutes: scenario.avgMinutes,
            featured: scenario.featuredSuggestion,
            onStart: { _ in },
            onEdit: { _ in },
            onNew: {},
            onStartEmpty: {}
        )
        .padding()
    }
    .modelContainer(scenario.container)
    .preferredColorScheme(.dark)
}
