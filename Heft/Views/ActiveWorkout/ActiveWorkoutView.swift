// iOS 26+ only. No #available guards.

import SwiftUI
import SwiftData

struct ActiveWorkoutView: View {
    let vm: ActiveWorkoutViewModel
    let onDismiss: () -> Void

    @State private var completedSession: WorkoutSession?
    @State private var isShowingCancelPRWarning = false
    @Environment(\.heftTheme) private var theme

    var body: some View {
        @Bindable var vm = vm

        ZStack {
            // ── Workout content ────────────────────────────────────────────────
            NavigationStack {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: Spacing.md) {
                            // ── Inline rest timer ─────────────────────────────
                            if vm.restTimer.isActive {
                                RestTimerBanner(restTimer: vm.restTimer, vm: vm)
                                    .transition(.move(edge: .top).combined(with: .opacity))
                            }

                            if vm.draftExercises.isEmpty {
                                EmptyWorkoutPrompt(accentColor: theme.accentColor)
                            } else {
                                ForEach(Array(vm.draftExercises.enumerated()), id: \.element.id) { idx, exercise in
                                    ActiveExerciseCard(
                                        vm: vm,
                                        exerciseIndex: idx,
                                        theme: theme
                                    )
                                    .id(exercise.id)
                                }
                            }
                        }
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.lg)
                        .animation(Motion.standardSpring, value: vm.restTimer.isActive)
                    }
                    .onChange(of: vm.currentFocus) { _, newFocus in
                        guard let focus = newFocus,
                              vm.draftExercises.indices.contains(focus.exerciseIndex) else { return }
                        withAnimation(Motion.standardSpring) {
                            proxy.scrollTo(
                                vm.draftExercises[focus.exerciseIndex].id,
                                anchor: .center
                            )
                        }
                    }
                }
                .themedBackground()
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("End") { vm.isShowingEndConfirm = true }
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.heftRed)
                    }
                    ToolbarItem(placement: .principal) {
                        TimelineView(.periodic(from: vm.openedAt, by: 1.0)) { ctx in
                            Text(vm.elapsedLabel(at: ctx.date))
                                .font(.system(size: 17, weight: .semibold, design: .monospaced))
                                .foregroundStyle(Color.textPrimary)
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { vm.isShowingExercisePicker = true } label: {
                            Image(systemName: "plus").fontWeight(.semibold)
                        }
                        .accessibilityLabel("Add exercise")
                    }
                    ToolbarItemGroup(placement: .bottomBar) {
                        if let focus = vm.currentFocus {
                            let exercise = vm.draftExercises[focus.exerciseIndex]
                            CompactStepper(
                                text: Binding(
                                    get: { vm.draftExercises[focus.exerciseIndex].sets[focus.setIndex].weightText },
                                    set: { vm.draftExercises[focus.exerciseIndex].sets[focus.setIndex].weightText = $0 }
                                ),
                                unit: "lbs",
                                step: exercise.weightIncrement,
                                minValue: 0,
                                maxValue: 999,
                                isInteger: false,
                                firstTapDefault: weightDefault(for: exercise.equipmentType)
                            )
                            .frame(maxWidth: .infinity)
                            CompactStepper(
                                text: Binding(
                                    get: { vm.draftExercises[focus.exerciseIndex].sets[focus.setIndex].repsText },
                                    set: { vm.draftExercises[focus.exerciseIndex].sets[focus.setIndex].repsText = $0 }
                                ),
                                unit: "reps",
                                step: 1,
                                minValue: 0,
                                maxValue: 50,
                                isInteger: true,
                                firstTapDefault: 5
                            )
                            Button { vm.logFocusedSet() } label: {
                                Image(systemName: "checkmark")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(theme.accentColor)
                            }
                        }
                    }
                }
                .alert("End Workout?", isPresented: $vm.isShowingEndConfirm) {
                    Button("Finish") {
                        if let session = vm.endWorkout() {
                            completedSession = session
                        } else {
                            onDismiss()
                        }
                    }
                    Button("Cancel Workout", role: .destructive) {
                        if vm.hasPendingPRs {
                            isShowingCancelPRWarning = true
                        } else {
                            vm.cancelWorkout()
                            onDismiss()
                        }
                    }
                    Button("Back", role: .cancel) {}
                } message: {
                    Text(vm.isSessionStarted
                         ? "\(vm.elapsedLabel(at: .now)) · \(vm.loggedSetCount) sets logged"
                         : "No sets logged — this session won't be saved.")
                }
                .alert("Discard Your PR?", isPresented: $isShowingCancelPRWarning) {
                    Button("Discard & Cancel", role: .destructive) {
                        vm.cancelWorkout()
                        onDismiss()
                    }
                    Button("Keep Workout", role: .cancel) {}
                } message: {
                    Text("You set a new personal record this workout. Cancelling will permanently discard it.")
                }
                .navigationDestination(item: $completedSession) { session in
                    WorkoutSummaryView(session: session, onDone: { onDismiss() })
                }
                .sheet(isPresented: $vm.isShowingExercisePicker) {
                    ExercisePicker { exercise in
                        vm.addExercise(named: exercise.name)
                    }
                }
                .onChange(of: vm.isAllSetsLogged) { _, allDone in
                    guard allDone else { return }
                    // Brief pause so the user sees the final set turn green, then prompt
                    Task {
                        try? await Task.sleep(for: .seconds(0.8))
                        vm.isShowingEndConfirm = true
                    }
                }
            }
            .task { vm.setup() }

            // ── PR moment overlay ──────────────────────────────────────────────
            if let moment = vm.showingPRMoment {
                Color.black.opacity(0.55)
                    .ignoresSafeArea()
                    .transition(.opacity)

                PRMomentOverlay(moment: moment) {
                    vm.dismissPRMoment()
                }
                .transition(
                    .scale(scale: 0.88, anchor: .center)
                    .combined(with: .opacity)
                )
            }
        }
        .animation(Motion.standardSpring, value: vm.showingPRMoment != nil)
    }
}

// MARK: - Helpers

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

// MARK: - Empty Workout Prompt

struct EmptyWorkoutPrompt: View {
    let accentColor: Color

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: DesignTokens.Icon.placeholder))
                .foregroundStyle(accentColor)
            VStack(spacing: Spacing.xs) {
                Text("Ready when you are")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.textPrimary)
                Text("Tap + to add your first exercise.")
                    .font(.subheadline)
                    .foregroundStyle(Color.textMuted)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.xl)
        .padding(.top, Spacing.xxl)
    }
}

#Preview("Empty workout") {
    let vm = ActiveWorkoutViewModel(
        modelContext: PersistenceController.previewContainer.mainContext,
        pendingRoutineID: nil
    )
    ActiveWorkoutView(vm: vm, onDismiss: {})
        .environment(AppState())
        .modelContainer(PersistenceController.previewContainer)
}
