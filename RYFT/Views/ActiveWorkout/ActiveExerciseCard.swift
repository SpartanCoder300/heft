// iOS 26+ only. No #available guards.

import SwiftUI
import SwiftData

// MARK: - Active Exercise Card

struct ActiveExerciseCard: View {
    let vm: ActiveWorkoutViewModel
    let exerciseIndex: Int
    let theme: AccentTheme

    @Environment(\.ryftCardMaterial) private var cardMaterial
    @Environment(\.modelContext) private var modelContext
    @State private var showingRemoveConfirm = false
    @State private var isEditingExercise = false
    @State private var editingDefinition: ExerciseDefinition? = nil
    @State private var isShowingHistory = false

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
                        isShowingHistory = true
                    } label: {
                        Label("View History", systemImage: "chart.line.uptrend.xyaxis")
                    }

                    Button {
                        let name = exercise.exerciseName
                        let descriptor = FetchDescriptor<ExerciseDefinition>(predicate: #Predicate { $0.name == name })
                        editingDefinition = (try? modelContext.fetch(descriptor))?.first
                        isEditingExercise = true
                    } label: {
                        Label("Edit Exercise", systemImage: "pencil")
                    }

                    Button {
                        vm.beginSwap(exerciseIndex: exerciseIndex)
                    } label: {
                        Label("Swap Exercise", systemImage: "arrow.left.arrow.right")
                    }

                    Button {
                        vm.isShowingExercisePicker = true
                    } label: {
                        Label("Add Superset", systemImage: "arrow.2.squarepath")
                    }

                    Button {
                        vm.addSet(toExerciseAt: exerciseIndex)
                    } label: {
                        Label("Add Set", systemImage: "plus")
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

            // ── Set rows ──────────────────────────────────────────────
            ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { sIdx, set in
                SetRow(
                    setNumber: sIdx + 1,
                    weightText: set.weightText,
                    repsText: set.repsText,
                    durationText: set.durationText,
                    isTimed: exercise.isTimed,
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
                    onUndo: { vm.unlogSet(exerciseIndex: exerciseIndex, setIndex: sIdx) },
                    onCopyFromAbove: sIdx > 0 ? { vm.copySetFromAbove(exerciseIndex: exerciseIndex, setIndex: sIdx) } : nil
                )

                if sIdx < exercise.sets.count - 1 {
                    Divider()
                        .overlay(Color.white.opacity(0.05))
                        .padding(.horizontal, Spacing.md)
                }
            }

        }
        .background(cardMaterial, in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
        .proGlass(exerciseIndex: exerciseIndex)
        .alert("Remove \(exercise.exerciseName)?", isPresented: $showingRemoveConfirm) {
            Button("Remove", role: .destructive) {
                vm.removeExercise(at: exerciseIndex)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove the exercise and all its logged sets from this session.")
        }
        .sheet(isPresented: $isEditingExercise, onDismiss: {
            vm.syncDefinition(at: exerciseIndex)
        }) {
            ExerciseEditorView(exercise: editingDefinition)
        }
        .sheet(isPresented: $isShowingHistory) {
            ExerciseHistoryView(exerciseName: exercise.exerciseName)
                .environment(\.ryftCardMaterial, .regularMaterial)
        }
    }

    private func previousLabel(for exercise: ActiveWorkoutViewModel.DraftExercise) -> String {
        if exercise.isTimed {
            return exercise.previousSets
                .map { formatDuration(Int($0.duration ?? 0)) }
                .joined(separator: "   ")
        }
        return exercise.previousSets
            .map { "\(vm.formatWeight($0.weight)) × \($0.reps)" }
            .joined(separator: "   ")
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
