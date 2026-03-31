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

    private var shouldRunSetupTask: Bool {
        let environment = ProcessInfo.processInfo.environment
        return environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1"
            && environment["XCODE_RUNNING_FOR_PLAYGROUNDS"] != "1"
    }

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
                    .padding(.top, Spacing.md)
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
            .task {
                guard shouldRunSetupTask else { return }
                vm.setup()
            }

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

    private let fadeHeight: CGFloat = 116

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                Spacer(minLength: 0)

                ZStack(alignment: .bottom) {
                    Rectangle()
                        .fill(.thinMaterial)
                        .opacity(0.70)
                        .mask {
                            LinearGradient(
                                stops: [
                                    .init(color: .clear, location: 0),
                                    .init(color: .white.opacity(0.14), location: 0.16),
                                    .init(color: .white.opacity(0.42), location: 0.50),
                                    .init(color: .white, location: 1)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        }

                    Rectangle()
                        .fill(.regularMaterial)
                        .opacity(0.38)
                        .mask {
                            LinearGradient(
                                stops: [
                                    .init(color: .clear, location: 0),
                                    .init(color: .white.opacity(0.04), location: 0.30),
                                    .init(color: .white.opacity(0.18), location: 0.62),
                                    .init(color: .white, location: 1)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        }

                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: Color.black.opacity(0.14), location: 0.16),
                            .init(color: Color.black.opacity(0.34), location: 0.42),
                            .init(color: Color.black.opacity(0.62), location: 1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
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

    @State private var isShowingActions = false
    @State private var adjustTrigger = 0
    @State private var skipTrigger   = 0

    private let cardWidth: CGFloat = 136
    private let cardHeight: CGFloat = 54

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { context in
            let now   = context.date
            let _ = timer.tick(at: now)
            let phase = timer.tintColor(at: now)
            let color = restPhaseColor(phase)

            Button {
                isShowingActions = true
            } label: {
                timerContent(at: now, color: color)
                    .frame(width: cardWidth, height: cardHeight)
                    .contentShape(RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
            }
            .buttonStyle(.plain)
            .glassEffect(in: RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
            .background {
                RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
                    .fill(.regularMaterial.opacity(0.12))
                    .overlay {
                        RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
                            .fill(color.opacity(timerCardTintOpacity(for: phase)))
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.18),
                                Color.white.opacity(0.06)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: Color.black.opacity(0.22), radius: 14, y: 6)
            .shadow(color: Color.black.opacity(0.10), radius: 4, y: 1)
            .sensoryFeedback(.selection, trigger: adjustTrigger)
            .sensoryFeedback(.impact(weight: .medium), trigger: skipTrigger)
            .sensoryFeedback(.impact(weight: .heavy, intensity: 1.0),
                             trigger: timer.pulseCount)
            .onChange(of: timer.pulseCount) { _, _ in
                playRestCompleteSound()
            }
            .popover(isPresented: $isShowingActions, attachmentAnchor: .point(.bottom), arrowEdge: .top) {
                RestTimerActionsSheet(
                    onAdjust: { seconds in
                        onAdjust(seconds)
                        adjustTrigger += 1
                    },
                    onSkip: {
                        onSkip()
                        skipTrigger += 1
                    }
                )
            }
        }
    }

    private func timerContent(at now: Date, color: Color) -> some View {
        VStack(spacing: 5) {
            HStack(spacing: 6) {
                Image(systemName: "timer")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(color.opacity(0.82))

                Text(timer.remainingLabel(at: now) ?? "0:00")
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(color)
                    .contentTransition(.numericText(countsDown: true))
                    .shadow(color: color.opacity(0.18), radius: 6)
            }

            Capsule()
                .fill(.white.opacity(0.14))
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(color)
                        .frame(width: 76 * CGFloat(timer.progress(at: now) ?? 0))
                }
                .frame(width: 76, height: 3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func timerCardTintOpacity(for phase: TimerTintPhase) -> Double {
        switch phase {
        case .calm:      0.06
        case .readySoon: 0.10
        }
    }
}

private struct RestTimerActionsSheet: View {
    let onAdjust: (TimeInterval) -> Void
    let onSkip: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            actionRow("+30s", systemImage: "plus.circle") {
                onAdjust(30)
                dismiss()
            }

            Divider()

            actionRow("−30s", systemImage: "minus.circle") {
                onAdjust(-30)
                dismiss()
            }

            Divider()

            actionRow("Skip", systemImage: "forward.end") {
                onSkip()
                dismiss()
            }
        }
        .frame(width: 180)
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
                .fill(Color.black.opacity(0.22))
        )
        .presentationCompactAdaptation(.popover)
    }

    private func actionRow(
        _ title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, 14)
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
    case .calm:
        return Color.textPrimary.opacity(0.78)
    case .readySoon:
        return Color.ryftAmber
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

#Preview("Editing panel") {
    ActiveWorkoutView(vm: ActiveWorkoutPreviewData.makeViewModel(), onDismiss: {})
        .activeWorkoutPreviewEnvironments()
}

#Preview("Complete Workout panel") {
    ActiveWorkoutView(
        vm: ActiveWorkoutPreviewData.makeViewModel(allLogged: true),
        onDismiss: {}
    )
    .activeWorkoutPreviewEnvironments()
}

#Preview("Rest Timer") {
    ActiveWorkoutView(
        vm: ActiveWorkoutPreviewData.makeViewModel(
            restTimer: (duration: 90, elapsed: 38)
        ),
        onDismiss: {}
    )
    .activeWorkoutPreviewEnvironments()
}

#Preview("Empty") {
    ActiveWorkoutView(vm: ActiveWorkoutPreviewData.emptyViewModel, onDismiss: {})
        .activeWorkoutPreviewEnvironments()
}
