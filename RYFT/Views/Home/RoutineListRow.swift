// iOS 26+ only. No #available guards.

import SwiftUI
import SwiftData

struct RoutineListRow: View {
    let routine: RoutineTemplate
    let avgMinutes: Int?
    let onTap: () -> Void
    let onEdit: () -> Void

    @Environment(\.ryftCardMaterial) private var cardMaterial
    @State private var hapticTrigger = false

    var body: some View {
        Button {
            hapticTrigger.toggle()
            onTap()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(routine.name)
                        .font(Typography.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    if !routine.muscleGroupSummary.isEmpty {
                        Text(routine.muscleGroupSummary)
                            .font(Typography.caption)
                            .foregroundStyle(Color.textMuted)
                    }
                }
                Spacer()
                HStack(spacing: Spacing.sm) {
                    VStack(alignment: .trailing, spacing: Spacing.xs) {
                        Text("\(routine.entries.count) exercises")
                            .font(Typography.caption)
                            .foregroundStyle(Color.textMuted)
                        Text(avgMinutes.map { "\($0) min avg" } ?? "No history yet")
                            .font(Typography.caption)
                            .foregroundStyle(Color.textFaint)
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardMaterial, in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
            .proGlass(specular: false)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
        .contextMenu {
            Button { onEdit() } label: {
                Label("Edit Routine", systemImage: "pencil")
            }
        }
    }
}

// MARK: - Previews

#Preview("With history") {
    let scenario = HomePreviewData.featured
    let routine = scenario.routines[1]
    return RoutineListRow(
        routine: routine,
        avgMinutes: scenario.avgMinutes[routine.id],
        onTap: {},
        onEdit: {}
    )
    .padding()
    .environment(\.ryftCardMaterial, .regularMaterial)
    .modelContainer(scenario.container)
    .preferredColorScheme(.dark)
}

#Preview("No history") {
    let scenario = HomePreviewData.routinesOnly
    let routine = scenario.routines[0]
    return RoutineListRow(routine: routine, avgMinutes: nil, onTap: {}, onEdit: {})
        .padding()
        .environment(\.ryftCardMaterial, .regularMaterial)
        .modelContainer(scenario.container)
        .preferredColorScheme(.dark)
}
