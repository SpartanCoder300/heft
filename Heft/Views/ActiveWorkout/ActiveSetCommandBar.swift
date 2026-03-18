// iOS 26+ only. No #available guards.

import SwiftUI

/// Persistent bottom panel showing the focused set's controls and a LOG button.
/// Always in the thumb zone — the primary interaction surface for logging.
struct ActiveSetCommandBar: View {
    let vm: ActiveWorkoutViewModel
    @Environment(\.heftTheme) private var theme

    @State private var showingNavigator = false

    var body: some View {
        if let focus = vm.currentFocus {
            let exercise = vm.draftExercises[focus.exerciseIndex]

            VStack(spacing: Spacing.sm) {

                // ── Context row — tap to reveal set navigator ─────────
                Button { withAnimation(Motion.standardSpring) { showingNavigator.toggle() } } label: {
                    HStack {
                        Text(exercise.exerciseName)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.textMuted)
                        Text("· Set \(focus.setIndex + 1) of \(exercise.sets.count)")
                            .font(.caption)
                            .foregroundStyle(Color.textFaint)
                        Spacer()
                        Image(systemName: "chevron.up")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.textFaint)
                            .rotationEffect(showingNavigator ? .degrees(180) : .zero)
                    }
                }
                .buttonStyle(.plain)

                // ── Set navigator strip ──────────────────────────────
                if showingNavigator {
                    SetNavigatorStrip(vm: vm)
                }

                // ── Controls row ─────────────────────────────────────
                HStack(spacing: Spacing.sm) {
                    CompactStepper(
                        text: Binding(
                            get: { vm.draftExercises[focus.exerciseIndex].sets[focus.setIndex].weightText },
                            set: { vm.draftExercises[focus.exerciseIndex].sets[focus.setIndex].weightText = $0 }
                        ),
                        unit: "lbs",
                        step: 2.5,
                        minValue: 0,
                        maxValue: 999,
                        isInteger: false,
                        firstTapDefault: weightDefault(for: exercise.equipmentType)
                    )

                    CompactStepper(
                        text: Binding(
                            get: { vm.draftExercises[focus.exerciseIndex].sets[focus.setIndex].repsText },
                            set: { vm.draftExercises[focus.exerciseIndex].sets[focus.setIndex].repsText = $0 }
                        ),
                        unit: "reps",
                        step: 1,
                        minValue: 0,
                        maxValue: 50,
                        isInteger: true
                    )

                    // LOG — primary action for the entire screen
                    Button { vm.logFocusedSet() } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(theme.accentColor)
                            .frame(width: 56, height: 52)
                            .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.sm)
            .padding(.bottom, Spacing.xs)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
            .padding(.horizontal, Spacing.md)
            .padding(.bottom, Spacing.sm)
            .contentTransition(.numericText())
            .animation(Motion.standardSpring, value: focus)
        }
    }

    private func weightDefault(for equipmentType: String) -> Double? {
        switch equipmentType {
        case "Barbell":    return 45
        case "Dumbbell":   return 10
        case "Cable":      return 20
        case "Machine":    return 45
        case "Kettlebell": return 35
        case "Bodyweight": return nil
        default:           return 45
        }
    }
}

// MARK: - Set Navigator Strip

/// Horizontal strip showing all exercises as pills with set-progress dots.
/// Tap a dot to jump focus to that set.
private struct SetNavigatorStrip: View {
    let vm: ActiveWorkoutViewModel
    @Environment(\.heftTheme) private var theme

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.md) {
                ForEach(Array(vm.draftExercises.enumerated()), id: \.element.id) { eIdx, exercise in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(exercise.exerciseName)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.textMuted)
                            .lineLimit(1)

                        HStack(spacing: 4) {
                            ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { sIdx, set in
                                Circle()
                                    .fill(dotColor(set: set, eIdx: eIdx, sIdx: sIdx))
                                    .frame(width: 8, height: 8)
                                    .onTapGesture {
                                        if !set.isLogged {
                                            vm.setManualFocus(exerciseIndex: eIdx, setIndex: sIdx)
                                        }
                                    }
                            }
                        }
                    }
                }
            }
            .padding(.vertical, Spacing.xs)
        }
    }

    private func dotColor(set: ActiveWorkoutViewModel.DraftSet, eIdx: Int, sIdx: Int) -> Color {
        if set.isLogged { return Color.heftGreen }
        if vm.currentFocus == ActiveWorkoutViewModel.SetFocus(exerciseIndex: eIdx, setIndex: sIdx) {
            return theme.accentColor
        }
        return Color.textFaint.opacity(0.4)
    }
}
