// iOS 26+ only. No #available guards.

import SwiftUI
import SwiftData
import AudioToolbox

struct ActiveWorkoutView: View {
    let vm: ActiveWorkoutViewModel
    let onDismiss: () -> Void

    @State private var completedSession: WorkoutSession?
    @State private var isShowingCancelPRWarning = false
    @Environment(\.ryftTheme) private var theme

    var body: some View {
        @Bindable var vm = vm

        ZStack {
            NavigationStack {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: Spacing.md) {
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
                        .padding(.top, Spacing.lg)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onAppear {
                        guard let focus = vm.currentFocus,
                              vm.draftExercises.indices.contains(focus.exerciseIndex) else { return }
                        let id = vm.draftExercises[focus.exerciseIndex].id
                        // Defer one runloop cycle — layout must complete before
                        // proxy.scrollTo has a valid scroll geometry to target.
                        Task { @MainActor in
                            proxy.scrollTo(id, anchor: .center)
                        }
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
                .overlay(alignment: .bottom) {
                    BottomCommandBackdrop(theme: theme)
                        .allowsHitTesting(false)
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Finish") { vm.isShowingEndConfirm = true }
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                    }
                    ToolbarItem(placement: .principal) {
                        TimelineView(.periodic(from: .now, by: 1.0)) { ctx in
                            Text(vm.elapsedLabel(at: ctx.date))
                                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                                .monospacedDigit()
                                .foregroundStyle(Color.textPrimary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .glassEffect(in: Capsule())
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { vm.isShowingExercisePicker = true } label: {
                            Image(systemName: "plus").fontWeight(.semibold)
                        }
                        .accessibilityLabel("Add exercise")
                    }
                }
                .safeAreaInset(edge: .top, spacing: 0) {
                    if vm.restTimer.isActive {
                        RestTimerBar(
                            timer: vm.restTimer,
                            onAdjust: { vm.adjustRest(by: $0) },
                            onSkip: { vm.skipRest() }
                        )
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.sm)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    ActiveWorkoutCommandPanel(
                        vm: vm,
                        theme: theme,
                        onComplete: { session in
                            playWorkoutCompleteHaptic()
                            completedSession = session
                        },
                        onDismiss: onDismiss
                    )
                    .frame(maxWidth: .infinity)
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: vm.restTimer.isActive)
                .alert("End Workout?", isPresented: $vm.isShowingEndConfirm) {
                    Button("Finish") {
                        if let session = vm.endWorkout() {
                            playWorkoutCompleteHaptic()
                            completedSession = session
                        } else {
                            onDismiss()
                        }
                    }
                    Button("Cancel Workout", role: .destructive) {
                        UINotificationFeedbackGenerator().notificationOccurred(.warning)
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
                        UINotificationFeedbackGenerator().notificationOccurred(.warning)
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
                .sheet(isPresented: $vm.isShowingExercisePicker, onDismiss: {
                    vm.cancelSwap()
                }) {
                    ExercisePicker { exercise in
                        if let idx = vm.swappingExerciseIndex {
                            vm.swapExercise(at: idx, named: exercise.name)
                        } else {
                            vm.addExercise(named: exercise.name)
                        }
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
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(
                    .scale(scale: 0.88, anchor: .center)
                    .combined(with: .opacity)
                )
            }
        }
        // Fill the bottom safe area with the theme background so the command
        // panel shadow blends seamlessly into the screen bottom — no hard edge.
        .background(theme.backgroundColor, ignoresSafeAreaEdges: .bottom)
        .animation(Motion.standardSpring, value: vm.showingPRMoment != nil)
    }

    // MARK: - Haptics

    /// Bar drops, then the achievement lands. Two beats, 300ms apart.
    private func playWorkoutCompleteHaptic() {
        Task {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            try? await Task.sleep(for: .milliseconds(300))
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

}

// MARK: - Rest Timer Bar

private struct BottomCommandBackdrop: View {
    let theme: AccentTheme

    private let fadeHeight: CGFloat = 110

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                Spacer(minLength: 0)

                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: Color.black.opacity(0.18), location: 0.18),
                        .init(color: Color.black.opacity(0.44), location: 0.42),
                        .init(color: Color.black.opacity(0.70), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: fadeHeight)

                theme.backgroundColor
                    .frame(height: proxy.safeAreaInsets.bottom)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

private struct RestTimerBar: View {
    let timer: RestTimerState
    let onAdjust: (TimeInterval) -> Void
    let onSkip: () -> Void

    @State private var adjustTrigger = 0
    @State private var skipTrigger   = 0

    private let sideWidth:  CGFloat = 56
    private let skipWidth:  CGFloat = 56
    private let barHeight:  CGFloat = 64

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { context in
            let now   = context.date
            let color = restPhaseColor(timer.tintColor(at: now))

            HStack(spacing: 0) {
                // Mirror of separator + skip on the right — keeps timer centred
                Color.clear.frame(width: skipWidth + 1)

                adjustButton(label: "−30s", seconds: -30)

                timerContent(at: now, color: color)
                    .frame(maxWidth: .infinity)

                adjustButton(label: "+30s", seconds: 30)

                Rectangle()
                    .fill(.white.opacity(0.10))
                    .frame(width: 1, height: 20)

                skipButton()
            }
            .frame(height: barHeight)
            .glassEffect(in: RoundedRectangle(cornerRadius: Radius.large,
                                               style: .continuous))
            .sensoryFeedback(.selection, trigger: adjustTrigger)
            .sensoryFeedback(.impact(weight: .medium), trigger: skipTrigger)
            .sensoryFeedback(.impact(weight: .heavy, intensity: 1.0),
                             trigger: timer.pulseCount)
            .onChange(of: timer.pulseCount) { _, _ in
                playRestCompleteSound()
            }
        }
    }

    private func timerContent(at now: Date, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(timer.remainingLabel(at: now) ?? "0:00")
                .font(.system(size: 24, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(color)
                .contentTransition(.numericText(countsDown: true))

            Capsule()
                .fill(color.opacity(0.15))
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(color)
                        .frame(width: 80 * CGFloat(timer.progress(at: now) ?? 0))
                }
                .frame(width: 80, height: 3)
        }
    }

    private func adjustButton(label: String, seconds: Double) -> some View {
        Button {
            onAdjust(seconds)
            adjustTrigger += 1
        } label: {
            Text(label)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(width: sideWidth, height: barHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func skipButton() -> some View {
        Button {
            onSkip()
            skipTrigger += 1
        } label: {
            Image(systemName: "forward.end.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.ryftGreen)
                .frame(width: skipWidth, height: barHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Helpers

/// Plays the rest-complete sound. Prefers a bundled "rest-complete.caf" asset —
/// drop the file into the project and it picks up automatically.
/// Falls back to system sound 1057 until a branded asset is ready.
private func playRestCompleteSound() {
    if let url = Bundle.main.url(forResource: "rest-complete", withExtension: "caf") {
        var soundID: SystemSoundID = 0
        AudioServicesCreateSystemSoundID(url as CFURL, &soundID)
        AudioServicesPlayAlertSound(soundID)
    } else {
        AudioServicesPlayAlertSound(SystemSoundID(1057))
    }
}

private func restPhaseColor(_ phase: TimerTintPhase) -> Color {
    switch phase {
    case .green: .secondary
    case .amber: Color.ryftAmber
    case .red:   .primary
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

// MARK: - Previews

private func previewVM(allLogged: Bool = false) -> ActiveWorkoutViewModel {
    let vm = ActiveWorkoutViewModel(
        modelContext: PersistenceController.previewContainer.mainContext,
        pendingRoutineID: nil
    )
    let sets: (String, String) -> [ActiveWorkoutViewModel.DraftSet] = { weight, reps in
        (0..<3).map { _ in
            var s = ActiveWorkoutViewModel.DraftSet()
            s.weightText = weight
            s.repsText = reps
            s.isLogged = allLogged
            return s
        }
    }
    vm.draftExercises = [
        ActiveWorkoutViewModel.DraftExercise(
            exerciseName: "Bench Press",
            equipmentType: "Barbell",
            weightIncrement: 5,
            sets: sets("135", "8")
        ),
        ActiveWorkoutViewModel.DraftExercise(
            exerciseName: "Squat",
            equipmentType: "Barbell",
            weightIncrement: 5,
            sets: sets("225", "5")
        ),
        ActiveWorkoutViewModel.DraftExercise(
            exerciseName: "Bench Press",
            equipmentType: "Barbell",
            weightIncrement: 5,
            sets: sets("135", "8")
        ),
        ActiveWorkoutViewModel.DraftExercise(
            exerciseName: "Squat",
            equipmentType: "Barbell",
            weightIncrement: 5,
            sets: sets("225", "5")
        ),
    ]
    return vm
}

#Preview("Editing panel") {
    ActiveWorkoutView(vm: previewVM(), onDismiss: {})
        .previewEnvironments()
}

#Preview("Complete Workout panel") {
    ActiveWorkoutView(vm: previewVM(allLogged: true), onDismiss: {})
        .previewEnvironments()
}

#Preview("Empty") {
    let vm = ActiveWorkoutViewModel(
        modelContext: PersistenceController.previewContainer.mainContext,
        pendingRoutineID: nil
    )
    ActiveWorkoutView(vm: vm, onDismiss: {})
        .previewEnvironments()
}

private extension View {
    func previewEnvironments() -> some View {
        self
            .environment(AppState())
            .environment(MeshEngine())
            .environment(\.ryftTheme, .midnight)
            .environment(\.ryftCardMaterial, .regularMaterial)
            .modelContainer(PersistenceController.previewContainer)
    }
}
