// iOS 26+ only. No #available guards.

import SwiftUI
import SwiftData

// MARK: - Active Exercise Card

struct ActiveExerciseCard: View {
    let vm: ActiveWorkoutViewModel
    let exerciseIndex: Int
    let theme: AccentTheme

    @State private var showingRemoveConfirm = false

    private var exercise: ActiveWorkoutViewModel.DraftExercise? {
        guard vm.draftExercises.indices.contains(exerciseIndex) else { return nil }
        return vm.draftExercises[exerciseIndex]
    }

    var body: some View {
        guard let exercise else { return AnyView(EmptyView()) }
        return AnyView(cardBody(exercise: exercise))
    }

    @ViewBuilder
    private func cardBody(exercise: ActiveWorkoutViewModel.DraftExercise) -> some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Header ────────────────────────────────────────────────
            HStack(alignment: .center) {
                Text(exercise.exerciseName)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                Menu {
                    Button {
                        // TODO: navigate to ExerciseDetailView (§17)
                    } label: {
                        Label("View History", systemImage: "chart.line.uptrend.xyaxis")
                    }

                    Button {
                        vm.isShowingExercisePicker = true
                    } label: {
                        Label("Add Superset", systemImage: "arrow.2.squarepath")
                    }

                    Button {
                        vm.addDropset(toExerciseAt: exerciseIndex)
                    } label: {
                        Label("Add Dropset", systemImage: "arrow.turn.down.right")
                    }

                    Button {
                        vm.moveExercise(at: exerciseIndex, direction: .up)
                    } label: {
                        Label("Move Up", systemImage: "arrow.up")
                    }
                    .disabled(exerciseIndex == 0)

                    Button {
                        vm.moveExercise(at: exerciseIndex, direction: .down)
                    } label: {
                        Label("Move Down", systemImage: "arrow.down")
                    }
                    .disabled(exerciseIndex == vm.draftExercises.count - 1)

                    Divider()

                    Button(role: .destructive) {
                        showingRemoveConfirm = true
                    } label: {
                        Label("Remove from Workout", systemImage: "trash")
                    }

                    Button(role: .destructive) {
                        vm.isShowingEndConfirm = true
                    } label: {
                        Label("End Workout", systemImage: "xmark.circle")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.textMuted)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                        .accessibilityLabel("Exercise options")
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.sm)

            // ── Previous session ──────────────────────────────────────
            if !exercise.previousSets.isEmpty {
                Text("Last \(previousLabel(for: exercise))")
                    .font(.caption)
                    .foregroundStyle(Color.textFaint)
                    .padding(.horizontal, Spacing.md)
                    .padding(.bottom, Spacing.sm)
            } else {
                Color.clear.frame(height: Spacing.sm)
            }

            Divider().overlay(Color.white.opacity(0.07))

            // ── Set type legend ───────────────────────────────────────
            Text("W warmup  ·  N normal  ·  D dropset")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.textFaint)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.md)
                .padding(.top, Spacing.xs)

            // ── Set rows ──────────────────────────────────────────────
            ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { sIdx, set in
                SetRow(
                    setNumber: sIdx + 1,
                    weightText: set.weightText,
                    repsText: set.repsText,
                    setType: set.setType,
                    isLogged: set.isLogged,
                    isFocused: vm.currentFocus == ActiveWorkoutViewModel.SetFocus(
                        exerciseIndex: exerciseIndex, setIndex: sIdx
                    ),
                    isPR: set.isPR,
                    justGotPR: vm.lastPRSetID != nil && vm.lastPRSetID == set.loggedRecord?.id,
                    accentColor: theme.accentColor,
                    onCycleType: { vm.cycleSetType(exerciseIndex: exerciseIndex, setIndex: sIdx) },
                    onFocus: { vm.setManualFocus(exerciseIndex: exerciseIndex, setIndex: sIdx) },
                    onLog: { vm.logSet(exerciseIndex: exerciseIndex, setIndex: sIdx) },
                    onDelete: { vm.removeSet(exerciseIndex: exerciseIndex, setIndex: sIdx) },
                    onUndo: { vm.unlogSet(exerciseIndex: exerciseIndex, setIndex: sIdx) }
                )

                if sIdx < exercise.sets.count - 1 {
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
        .alert("Remove \(exercise.exerciseName)?", isPresented: $showingRemoveConfirm) {
            Button("Remove", role: .destructive) {
                vm.removeExercise(at: exerciseIndex)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove the exercise and all its logged sets from this session.")
        }
    }

    private func previousLabel(for exercise: ActiveWorkoutViewModel.DraftExercise) -> String {
        exercise.previousSets
            .map { "\(vm.formatWeight($0.weight)) × \($0.reps)" }
            .joined(separator: "   ")
    }
}


// MARK: - Set Row

/// Compact set row — values display only, editing via bottom command bar.
/// Tap row to focus, tap circle to log directly.
private struct SetRow: View {
    let setNumber: Int
    let weightText: String
    let repsText: String
    let setType: SetType
    let isLogged: Bool
    let isFocused: Bool
    let isPR: Bool
    let justGotPR: Bool
    let accentColor: Color
    let onCycleType: () -> Void
    let onFocus: () -> Void
    let onLog: () -> Void
    let onDelete: () -> Void
    let onUndo: () -> Void

    @State private var rowScale: CGFloat = 1.0
    @State private var badgeScale: CGFloat = 0

    var body: some View {
        HStack(spacing: 6) {
            // Focused accent bar
            RoundedRectangle(cornerRadius: 1.5)
                .fill(isFocused ? accentColor : .clear)
                .frame(width: 3, height: 28)

            Text("\(setNumber)")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.textFaint)
                .frame(width: 20, alignment: .center)

            SetTypeChip(setType: setType, onTap: isLogged ? nil : onCycleType)

            Text(displayText)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(isLogged ? Color.heftGreen : Color.textPrimary)
                .contentTransition(.numericText())
                .animation(Motion.standardSpring, value: weightText)
                .animation(Motion.standardSpring, value: repsText)

            // PR badge — pops in with spring animation when PR is detected
            if isPR {
                Text("PR")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.heftGold, in: Capsule())
                    .scaleEffect(badgeScale)
            }

            Spacer()

            // Log / status button
            Button(action: onLog) {
                Image(systemName: isLogged ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isLogged ? Color.heftGreen : Color.textFaint.opacity(0.4))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isLogged)
        }
        .scaleEffect(rowScale)
        .padding(.vertical, 4)
        .padding(.leading, Spacing.xs)
        .padding(.trailing, Spacing.sm)
        .background(isFocused ? accentColor.opacity(0.08) : .clear)
        .contentShape(Rectangle())
        .onTapGesture {
            if !isLogged { onFocus() }
        }
        .opacity(isLogged && !isPR ? 0.5 : 1.0)
        .animation(Motion.standardSpring, value: isLogged)
        .animation(Motion.standardSpring, value: isFocused)
        .contextMenu {
            if isLogged {
                Button(action: onUndo) {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                }
            } else {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete Set", systemImage: "trash")
                }
            }
        }
        .onAppear {
            // If this set was already a PR (e.g. view re-mounted), show badge immediately
            if isPR { badgeScale = 1.0 }
        }
        .onChange(of: justGotPR) { _, newVal in
            guard newVal else { return }
            // Badge: scale from zero with bouncy spring
            badgeScale = 0
            withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                badgeScale = 1.0
            }
            // Row: pulse scale 1.0 → 1.05 → 1.0
            withAnimation(.spring(response: 0.18, dampingFraction: 0.4)) {
                rowScale = 1.05
            }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(180))
                withAnimation(Motion.standardSpring) {
                    rowScale = 1.0
                }
            }
        }
    }

    private var displayText: String {
        let w = weightText.isEmpty ? "—" : weightText
        let r = repsText.isEmpty ? "—" : repsText
        return "\(w) × \(r)"
    }
}

// MARK: - Previews

#Preview("With sets") {
    {
        let vm = ActiveWorkoutViewModel(
            modelContext: PersistenceController.previewContainer.mainContext,
            pendingRoutineID: nil
        )
        vm.addExercise(named: "Bench Press")
        vm.addSet(toExerciseAt: 0)
        vm.addSet(toExerciseAt: 0)
        vm.draftExercises[0].sets[0].weightText = "135"
        vm.draftExercises[0].sets[0].repsText = "8"
        vm.draftExercises[0].sets[1].weightText = "135"
        vm.draftExercises[0].sets[1].repsText = "8"
        return ActiveExerciseCard(vm: vm, exerciseIndex: 0, theme: AccentTheme.midnight)
            .padding()
    }()
}

#Preview("With previous performance") {
    {
        let vm = ActiveWorkoutViewModel(
            modelContext: PersistenceController.previewContainer.mainContext,
            pendingRoutineID: nil
        )
        vm.addExercise(named: "Squat")
        vm.draftExercises[0].sets[0].weightText = "225"
        vm.draftExercises[0].sets[0].repsText = "5"
        vm.draftExercises[0].previousSets = [
            .init(weight: 225, reps: 5),
            .init(weight: 225, reps: 5),
            .init(weight: 215, reps: 6),
        ]
        return ActiveExerciseCard(vm: vm, exerciseIndex: 0, theme: AccentTheme.midnight)
            .padding()
    }()
}
