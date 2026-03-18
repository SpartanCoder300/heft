// iOS 26+ only. No #available guards.

import SwiftUI

// MARK: - Active Exercise Card

struct ActiveExerciseCard: View {
    let vm: ActiveWorkoutViewModel
    let exerciseIndex: Int
    let theme: AccentTheme

    private var exercise: ActiveWorkoutViewModel.DraftExercise {
        vm.draftExercises[exerciseIndex]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Header ────────────────────────────────────────────────
            HStack(alignment: .center) {
                Text(exercise.exerciseName)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                Menu {
                    Button("Remove Exercise", role: .destructive) {
                        vm.removeExercise(at: exerciseIndex)
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.textMuted)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.sm)

            // ── Previous session ──────────────────────────────────────
            if !exercise.previousSets.isEmpty {
                Text("Last  \(previousLabel)")
                    .font(.caption)
                    .foregroundStyle(Color.textFaint)
                    .padding(.horizontal, Spacing.md)
                    .padding(.bottom, Spacing.sm)
            } else {
                Color.clear.frame(height: Spacing.sm)
            }

            Divider().overlay(Color.white.opacity(0.07))

            // ── Set rows ──────────────────────────────────────────────
            ForEach(exercise.sets.indices, id: \.self) { sIdx in
                let isDropset = exercise.sets[sIdx].setType == .dropset
                let nextIsDropset = sIdx + 1 < exercise.sets.count
                    && exercise.sets[sIdx + 1].setType == .dropset

                SetRow(
                    setNumber: sIdx + 1,
                    weightText: Binding(
                        get: { vm.draftExercises[exerciseIndex].sets[sIdx].weightText },
                        set: { vm.draftExercises[exerciseIndex].sets[sIdx].weightText = $0 }
                    ),
                    repsText: Binding(
                        get: { vm.draftExercises[exerciseIndex].sets[sIdx].repsText },
                        set: { vm.draftExercises[exerciseIndex].sets[sIdx].repsText = $0 }
                    ),
                    setType: exercise.sets[sIdx].setType,
                    isDropset: isDropset,
                    isLogged: exercise.sets[sIdx].isLogged,
                    onCycleType: { vm.cycleSetType(exerciseIndex: exerciseIndex, setIndex: sIdx) },
                    onLog: { vm.logSet(exerciseIndex: exerciseIndex, setIndex: sIdx) }
                )

                if sIdx < exercise.sets.count - 1 && !nextIsDropset {
                    Divider()
                        .overlay(Color.white.opacity(0.05))
                        .padding(.horizontal, Spacing.md)
                }
            }

            Divider().overlay(Color.white.opacity(0.07))

            // ── Add Set ───────────────────────────────────────────────
            Button { vm.addSet(toExerciseAt: exerciseIndex) } label: {
                Label("Add Set", systemImage: "plus")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(theme.accentColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.sm)
            }
            .buttonStyle(.plain)
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
    }

    private var previousLabel: String {
        exercise.previousSets
            .map { "\(vm.formatWeight($0.weight)) × \($0.reps)" }
            .joined(separator: "   ")
    }
}

// MARK: - Set Row

private struct SetRow: View {
    let setNumber: Int
    @Binding var weightText: String
    @Binding var repsText: String
    let setType: SetType
    let isDropset: Bool
    let isLogged: Bool
    let onCycleType: () -> Void
    let onLog: () -> Void

    var body: some View {
        HStack(spacing: 0) {

            // Set number + type chip
            HStack(spacing: 5) {
                Text(isDropset ? "↳" : "\(setNumber)")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(isDropset ? Color.heftAccentAbyss.opacity(0.7) : Color.textFaint)
                    .frame(width: 18, alignment: .center)

                SetTypeChip(setType: setType, onTap: isLogged ? nil : onCycleType)
            }
            .padding(.leading, isDropset ? Spacing.xl : Spacing.md)
            .frame(width: 72, alignment: .leading)

            // Weight stepper
            CompactStepper(
                text: $weightText,
                unit: "lbs",
                step: 2.5,
                minValue: 0,
                maxValue: 999,
                isInteger: false,
                isLogged: isLogged
            )
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Spacing.xs)

            // Reps stepper
            CompactStepper(
                text: $repsText,
                unit: "reps",
                step: 1,
                minValue: 0,
                maxValue: 50,
                isInteger: true,
                isLogged: isLogged
            )
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Spacing.xs)

            // Log button
            Button(action: onLog) {
                Image(systemName: isLogged ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundStyle(isLogged ? Color.heftGreen : Color.textFaint.opacity(0.5))
                    .frame(width: 52, height: 52)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isLogged)
        }
        .padding(.vertical, 4)
        .opacity(isLogged ? 0.5 : 1.0)
        .animation(Motion.standardSpring, value: isLogged)
    }
}
