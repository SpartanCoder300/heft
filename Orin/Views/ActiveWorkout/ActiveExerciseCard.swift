// iOS 26+ only. No #available guards.

import SwiftUI
import SwiftData

// MARK: - Active Exercise Card

struct ActiveExerciseCard: View {
    let vm: ActiveWorkoutViewModel
    let exerciseIndex: Int
    let theme: AccentTheme

    @Environment(\.modelContext) private var modelContext
    @State private var showingRemoveConfirm = false
    @State private var editingDefinition: ExerciseDefinition? = nil
    @State private var isShowingHistory = false
    @State private var prefetchedDefinition: ExerciseDefinition? = nil

    private var exercise: ActiveWorkoutViewModel.DraftExercise? {
        guard vm.draftExercises.indices.contains(exerciseIndex) else { return nil }
        return vm.draftExercises[exerciseIndex]
    }

    @ViewBuilder
    var body: some View {
        if let exercise { cardBody(exercise: exercise) }
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
                        editingDefinition = prefetchedDefinition
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

                    Divider()

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

            Divider().opacity(0.3)

            // ── Set rows ──────────────────────────────────────────────
            ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { sIdx, set in
                SetRow(
                    setNumber: sIdx + 1,
                    weightText: set.weightText,
                    repsText: set.repsText,
                    durationText: set.durationText,
                    isTimed: exercise.isTimed,
                    tracksWeight: exercise.tracksWeight,
                    setType: set.setType,
                    isLogged: set.isLogged,
                    isFocused: vm.currentFocus == ActiveWorkoutViewModel.SetFocus(
                        exerciseIndex: exerciseIndex, setIndex: sIdx
                    ),
                    isFirstInCard: sIdx == 0,
                    isLastInCard: sIdx == exercise.sets.count - 1,
                    isPR: set.isPR,
                    justGotPR: vm.lastPRSetID != nil && vm.lastPRSetID == set.loggedRecord?.id,
                    accentColor: theme.accentColor,
                    placeholderDisplayText: placeholderText(for: exercise, setIndex: sIdx),
                    placeholderDelay: Double(max(0, sIdx - 1)) * 0.05,
                    previousSet: sIdx < exercise.previousSets.count ? exercise.previousSets[sIdx] : exercise.previousSets.last,
                    justLogged: vm.lastLoggedFocus == ActiveWorkoutViewModel.SetFocus(exerciseIndex: exerciseIndex, setIndex: sIdx),
                    onCycleType: { vm.cycleSetType(exerciseIndex: exerciseIndex, setIndex: sIdx) },
                    onFocus: { vm.setManualFocus(exerciseIndex: exerciseIndex, setIndex: sIdx) },
                    onLog: { vm.logSet(exerciseIndex: exerciseIndex, setIndex: sIdx) },
                    onDelete: { vm.removeSet(exerciseIndex: exerciseIndex, setIndex: sIdx) },
                    onUndo: { vm.unlogSet(exerciseIndex: exerciseIndex, setIndex: sIdx) },
                    onCopyFromAbove: sIdx > 0 ? { vm.copySetFromAbove(exerciseIndex: exerciseIndex, setIndex: sIdx) } : nil,
                    onAdoptPlaceholder: sIdx > 0 ? { vm.adoptPlaceholderValues(exerciseIndex: exerciseIndex, setIndex: sIdx) } : nil
                )
                .transition(.opacity.combined(with: .move(edge: .bottom)))

                if sIdx < exercise.sets.count - 1 {
                    Divider()
                        .opacity(0.15)
                        .padding(.horizontal, Spacing.md)
                }
            }
            .animation(Motion.standardSpring, value: exercise.sets.count)

            // ── Add Set ───────────────────────────────────────────────
            Divider()
                .opacity(0.15)
                .padding(.horizontal, Spacing.md)

            Button {
                vm.addSet(toExerciseAt: exerciseIndex)
            } label: {
                Label("Add Set", systemImage: "plus")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.textFaint)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

        }
        .cardSurface(border: true)
        .alert("Remove \(exercise.exerciseName)?", isPresented: $showingRemoveConfirm) {
            Button("Remove", role: .destructive) {
                vm.removeExercise(at: exerciseIndex)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove the exercise and all its logged sets from this session.")
        }
        .sheet(item: $editingDefinition, onDismiss: {
            vm.syncDefinition(at: exerciseIndex)
        }) { definition in
            ExerciseEditorView(exercise: definition, allowsLifecycleActions: false)
        }
        .sheet(isPresented: $isShowingHistory) {
            ExerciseHistoryView(exerciseName: exercise.exerciseName, exerciseLineageID: exercise.exerciseLineageID)
                .environment(\.OrinCardMaterial, .regularMaterial)
        }
        .task(id: exerciseIndex) {
            if let definitionID = exercise.exerciseDefinitionID {
                let descriptor = FetchDescriptor<ExerciseDefinition>(predicate: #Predicate { $0.id == definitionID })
                prefetchedDefinition = (try? modelContext.fetch(descriptor))?.first
            } else if let lineageID = exercise.exerciseLineageID {
                let descriptor = FetchDescriptor<ExerciseDefinition>(predicate: #Predicate { $0.id == lineageID })
                prefetchedDefinition = (try? modelContext.fetch(descriptor))?.first
            } else {
                let name = exercise.exerciseName
                let descriptor = FetchDescriptor<ExerciseDefinition>(predicate: #Predicate { $0.name == name })
                prefetchedDefinition = (try? modelContext.fetch(descriptor))?.first
            }
        }
    }

    /// Returns the placeholder display string for a set that has no user-entered values,
    /// derived reactively from set 0. Returns nil if set 0 is also empty or this is set 0.
    private func placeholderText(for exercise: ActiveWorkoutViewModel.DraftExercise, setIndex: Int) -> String? {
        guard setIndex > 0 else { return nil }
        let set = exercise.sets[setIndex]
        guard !set.isLogged,
              set.weightText.isEmpty, set.repsText.isEmpty, set.durationText.isEmpty else { return nil }
        let first = exercise.sets[0]
        guard !first.weightText.isEmpty || !first.repsText.isEmpty || !first.durationText.isEmpty else { return nil }

        if exercise.isTimed {
            let secs = Int(first.durationText) ?? 0
            let durationLabel = first.durationText.isEmpty ? "—" : formatDuration(secs)
            guard exercise.tracksWeight else { return durationLabel }
            let w = first.weightText.isEmpty ? "—" : first.weightText
            return "\(w) lb · \(durationLabel)"
        }
        guard exercise.tracksWeight else {
            let r = first.repsText.isEmpty ? "—" : first.repsText
            return "\(r) reps"
        }
        let w = first.weightText.isEmpty ? "—" : first.weightText
        let r = first.repsText.isEmpty ? "—" : first.repsText
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
