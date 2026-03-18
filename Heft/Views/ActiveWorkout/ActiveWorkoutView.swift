// iOS 26+ only. No #available guards.

import SwiftUI
import SwiftData

struct ActiveWorkoutView: View {
    @State private var vm: ActiveWorkoutViewModel
    @State private var completedSession: WorkoutSession?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.heftTheme) private var theme

    init(modelContext: ModelContext, pendingRoutineID: UUID?) {
        _vm = State(initialValue: ActiveWorkoutViewModel(
            modelContext: modelContext,
            pendingRoutineID: pendingRoutineID
        ))
    }

    var body: some View {
        @Bindable var vm = vm

        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: Spacing.md) {
                        if vm.draftExercises.isEmpty {
                            EmptyWorkoutPrompt(accentColor: theme.accentColor)
                        } else {
                            ActiveExerciseCard(
                                vm: vm,
                                exerciseIndex: vm.activeExerciseIndex,
                                theme: theme
                            )
                            .id("active")

                            if vm.draftExercises.count > 1 {
                                OtherExercisesSection(vm: vm)
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.lg)
                }
                .onChange(of: vm.activeExerciseIndex) { _, _ in
                    withAnimation(Motion.standardSpring) {
                        proxy.scrollTo("active", anchor: .top)
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
                }
            }
            .confirmationDialog(
                "End Workout?",
                isPresented: $vm.isShowingEndConfirm,
                titleVisibility: .visible
            ) {
                Button("Finish") {
                    if let session = vm.endWorkout() {
                        completedSession = session
                    } else {
                        dismiss()
                    }
                }
            } message: {
                Text(vm.isSessionStarted
                     ? "\(vm.elapsedLabel(at: .now)) · \(vm.loggedSetCount) sets logged"
                     : "No sets logged — this session won't be saved.")
            }
            .navigationDestination(item: $completedSession) { session in
                WorkoutSummaryView(session: session, onDone: { dismiss() })
            }
            .sheet(isPresented: $vm.isShowingExercisePicker) {
                ExercisePicker { exercise in
                    vm.addExercise(named: exercise.name)
                }
            }
            .sheet(isPresented: $vm.isShowingRestTimer) {
                RestTimerSheet(restTimer: vm.restTimer, vm: vm)
                    .presentationDetents([.fraction(0.92)])
                    .presentationDragIndicator(.hidden)
                    .presentationCornerRadius(Radius.large)
                    .presentationBackground(.clear)
            }
            .onChange(of: vm.restTimer.isActive) { _, isActive in
                vm.isShowingRestTimer = isActive
            }
        }
        .task { vm.setup() }
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
    ActiveWorkoutView(
        modelContext: PersistenceController.previewContainer.mainContext,
        pendingRoutineID: nil
    )
    .environment(AppState())
    .modelContainer(PersistenceController.previewContainer)
}
