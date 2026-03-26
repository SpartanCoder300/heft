// iOS 26+ only. No #available guards.

import SwiftUI

struct HomePreviousBestsCard: View {
    let vm: ActiveWorkoutViewModel
    @Environment(\.ryftCardMaterial) private var cardMaterial

    private var exercisesWithHistory: [(ActiveWorkoutViewModel.DraftExercise, [ActiveWorkoutViewModel.PreviousSet])] {
        vm.draftExercises.compactMap { ex in
            let sets = ex.previousSets.filter { $0.weight > 0 || $0.reps > 0 }
            guard !sets.isEmpty else { return nil }
            return (ex, sets)
        }
    }

    var body: some View {
        if !exercisesWithHistory.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                SectionHeader(title: "Last Time")

                VStack(spacing: 0) {
                    ForEach(Array(exercisesWithHistory.enumerated()), id: \.element.0.id) { idx, pair in
                        exerciseRow(exercise: pair.0, sets: pair.1)
                        if idx < exercisesWithHistory.count - 1 {
                            Divider()
                                .opacity(0.1)
                                .padding(.leading, Spacing.md)
                        }
                    }
                }
                .background(cardMaterial, in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
                .proGlass()
            }
        }
    }

    @ViewBuilder
    private func exerciseRow(exercise: ActiveWorkoutViewModel.DraftExercise, sets: [ActiveWorkoutViewModel.PreviousSet]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(exercise.exerciseName)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(1)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.xs) {
                    ForEach(Array(sets.enumerated()), id: \.offset) { _, set in
                        Text(setLabel(set))
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.white.opacity(0.08), in: Capsule())
                    }
                }
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm + 2)
    }

    private func setLabel(_ set: ActiveWorkoutViewModel.PreviousSet) -> String {
        let w = set.weight.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(set.weight))" : String(format: "%.1f", set.weight)
        if set.weight > 0 && set.reps > 0 { return "\(w) × \(set.reps)" }
        if set.reps > 0                   { return "\(set.reps) reps" }
        return "\(w) lbs"
    }
}
