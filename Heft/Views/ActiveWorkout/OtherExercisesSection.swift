// iOS 26+ only. No #available guards.

import SwiftUI

struct OtherExercisesSection: View {
    let vm: ActiveWorkoutViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Also in this workout")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.textFaint)
                .textCase(.uppercase)
                .tracking(0.8)
                .padding(.horizontal, 2)

            ForEach(vm.draftExercises.indices, id: \.self) { idx in
                if idx != vm.activeExerciseIndex {
                    let exercise = vm.draftExercises[idx]
                    let logged = exercise.sets.filter { $0.isLogged }.count

                    Button { vm.activeExerciseIndex = idx } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(exercise.exerciseName)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.textPrimary)
                                Text("\(exercise.sets.count) sets  ·  \(logged) logged")
                                    .font(.caption)
                                    .foregroundStyle(Color.textFaint)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.textFaint)
                        }
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.sm)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
