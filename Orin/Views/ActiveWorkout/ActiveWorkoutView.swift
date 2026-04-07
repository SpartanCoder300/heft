// iOS 26+ only. No #available guards.

import SwiftUI
import SwiftData
import AudioToolbox

struct ActiveWorkoutView: View {
    let vm: ActiveWorkoutViewModel
    let onDismiss: () -> Void

    @State private var completedSession: WorkoutSession?
    @State private var isShowingCancelPRWarning = false
    @Environment(\.OrinTheme) private var theme

    private var shouldRunSetupTask: Bool {
        let environment = ProcessInfo.processInfo.environment
        return environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1"
            && environment["XCODE_RUNNING_FOR_PLAYGROUNDS"] != "1"
    }

    private var pickerExistingExerciseCounts: [String: Int] {
        vm.draftExercises.enumerated().reduce(into: [:]) { counts, entry in
            let (index, exercise) = entry
            guard vm.swappingExerciseIndex != index else { return }
            counts[exercise.exerciseName, default: 0] += 1
        }
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
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
                    .onChange(of: vm.focusRevealRequestID) { _, _ in
                        guard let focus = vm.currentFocus,
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
                .simultaneousGesture(
                    TapGesture().onEnded {
                        dismissKeyboard()
                    }
                )
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
                    if vm.swappingExerciseIndex != nil { vm.cancelSwap() }
                }) {
                    let isSwapping = vm.swappingExerciseIndex != nil
                    ExercisePicker(
                        onSelect: { exercise in
                            if let idx = vm.swappingExerciseIndex {
                                vm.swapExercise(at: idx, named: exercise.name)
                            } else {
                                vm.addExercise(named: exercise.name)
                            }
                        },
                        dismissesOnSelection: isSwapping,
                        existingExerciseCounts: pickerExistingExerciseCounts,
                        title: isSwapping ? "Replace Exercise" : "Add Exercise"
                    )
                }
            }
            .task {
                guard shouldRunSetupTask else { return }
                vm.setup()
            }

            // ── PR moment overlay ──────────────────────────────────────────────
            if let moment = vm.showingPRMoment {
                PRCelebrationBackdrop()
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

private struct PRCelebrationBackdrop: View {
    @State private var scrimOpacity: Double = 0.78
    @State private var washOpacity: Double = 0.0
    @State private var spotlightOpacity: Double = 0.0
    @State private var spotlightScale: CGFloat = 0.72
    @State private var haloOpacity: Double = 0.0
    @State private var flashOpacity: Double = 0.0

    var body: some View {
        ZStack {
            Color.black.opacity(scrimOpacity)

            LinearGradient(
                stops: [
                    .init(color: Color.white.opacity(0.34), location: 0.00),
                    .init(color: Color.OrinAmber.opacity(0.18), location: 0.06),
                    .init(color: .clear, location: 0.20)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .opacity(flashOpacity)
            .blur(radius: 20)

            LinearGradient(
                stops: [
                    .init(color: Color.white.opacity(0.08), location: 0.00),
                    .init(color: Color.OrinAmber.opacity(0.10), location: 0.08),
                    .init(color: Color.OrinAmber.opacity(0.035), location: 0.22),
                    .init(color: Color.black.opacity(0.00), location: 0.46),
                    .init(color: .clear, location: 1.00)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .opacity(washOpacity)

            EllipticalGradient(
                colors: [
                    Color.white.opacity(0.80),
                    Color.OrinAmber.opacity(0.42),
                    Color.OrinAmber.opacity(0.08),
                    .clear
                ],
                center: .top
            )
            .scaleEffect(x: 1.28, y: spotlightScale, anchor: .top)
            .opacity(spotlightOpacity)
            .blur(radius: 26)
            .offset(y: -132)

            LinearGradient(
                stops: [
                    .init(color: Color.white.opacity(0.14), location: 0.00),
                    .init(color: Color.OrinAmber.opacity(0.10), location: 0.08),
                    .init(color: Color.OrinAmber.opacity(0.03), location: 0.20),
                    .init(color: .clear, location: 0.36)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .opacity(spotlightOpacity)
            .blur(radius: 34)

            RadialGradient(
                colors: [
                    Color.white.opacity(0.10),
                    Color.OrinAmber.opacity(0.20),
                    Color.OrinAmber.opacity(0.06),
                    .clear
                ],
                center: .center,
                startRadius: 70,
                endRadius: 255
            )
            .opacity(haloOpacity)
            .blur(radius: 18)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.10)) {
                flashOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.12)) {
                scrimOpacity = 0.82
            }
            withAnimation(.easeOut(duration: 0.18)) {
                washOpacity = 1.0
            }
            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                spotlightOpacity = 1.0
                spotlightScale = 1.04
            }
            withAnimation(.easeOut(duration: 0.22).delay(0.04)) {
                haloOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.22).delay(0.08)) {
                flashOpacity = 0.0
            }
            withAnimation(.easeOut(duration: 0.95).delay(0.14)) {
                scrimOpacity = 0.66
                washOpacity = 0.52
                spotlightOpacity = 0.64
                haloOpacity = 0.54
            }
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
    @State private var skipTrigger = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var countdownHapticCount = 0

    private let cardWidth: CGFloat = 136
    private let cardHeight: CGFloat = 54

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { context in
            let now = context.date
            let progress = timer.progress(at: now) ?? 1.0
            let textColor = timerTextColor(progress: progress)
            let remaining = timer.targetEndDate
                .map { max(0, Int(ceil($0.timeIntervalSince(now)))) } ?? 0
            let inFinalCountdown = remaining <= 5 && remaining > 0 && timer.isActive

            Button {
                isShowingActions = true
            } label: {
                timerContent(at: now, textColor: textColor, progress: progress)
                    .scaleEffect(pulseScale)
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
                            .fill(Color.OrinAmber.opacity(timerCardTintOpacity(progress: progress)))
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.18), Color.white.opacity(0.06)],
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
            .sensoryFeedback(.impact(weight: .heavy, intensity: 1.0), trigger: timer.pulseCount)
            .sensoryFeedback(.impact(weight: .light), trigger: countdownHapticCount)
            .onChange(of: remaining) { _, newVal in
                guard timer.isActive, [3, 2, 1].contains(newVal) else { return }
                countdownHapticCount += 1
            }
            .onChange(of: inFinalCountdown) { _, active in
                if active {
                    withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                        pulseScale = 1.02
                    }
                } else {
                    withAnimation(.spring(response: 0.3)) { pulseScale = 1.0 }
                }
            }
            .onChange(of: timer.pulseCount) { _, _ in
                playRestCompleteSound()
                withAnimation(.spring(response: 0.3)) { pulseScale = 1.0 }
            }
            .popover(isPresented: $isShowingActions, attachmentAnchor: .point(.bottom), arrowEdge: .top) {
                RestTimerActionsSheet(
                    onAdjust: { seconds in onAdjust(seconds); adjustTrigger += 1 },
                    onSkip: { onSkip(); skipTrigger += 1 }
                )
            }
        }
    }

    private func timerContent(at now: Date, textColor: Color, progress: Double) -> some View {
        let warmth = max(0.0, min(1.0, (0.30 - progress) / 0.30))
        return VStack(spacing: 2) {
            HStack(spacing: 5) {
                Image(systemName: "timer")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(textColor.opacity(0.72))
                Text("Rest")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .tracking(0.3)
                    .foregroundStyle(Color.textPrimary.opacity(0.55))
            }

            Text(timer.remainingLabel(at: now) ?? "0:00")
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(textColor)
                .contentTransition(.numericText(countsDown: true))
                .shadow(color: textColor.opacity(0.12), radius: 6)
                .padding(.top, -1)

            // Track brightens slightly as urgency builds
            Capsule()
                .fill(.white.opacity(0.12 + warmth * 0.08))
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(textColor)
                        .frame(width: 76 * CGFloat(progress))
                }
                .frame(width: 76, height: 3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Continuously interpolates white → OrinAmber.
    /// Neutral until 30% remaining, then gradually warms.
    private func timerTextColor(progress: Double) -> Color {
        let warmth = max(0.0, min(1.0, (0.30 - progress) / 0.30))
        return Color(
            red:   1.0 + (0.961 - 1.0) * warmth,
            green: 1.0 + (0.620 - 1.0) * warmth,
            blue:  1.0 + (0.043 - 1.0) * warmth
        ).opacity(0.88)
    }

    /// Background tint: barely present when calm, builds toward urgent.
    private func timerCardTintOpacity(progress: Double) -> Double {
        let warmth = max(0.0, min(1.0, (0.30 - progress) / 0.30))
        return 0.03 + warmth * 0.07
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
    if let soundID = RestCompleteSound.cachedSoundID {
        AudioServicesPlayAlertSound(soundID)
    } else {
        AudioServicesPlayAlertSound(SystemSoundID(1057))
    }
}

private enum RestCompleteSound {
    static let cachedSoundID: SystemSoundID? = {
        guard let url = Bundle.main.url(forResource: "rest-complete", withExtension: "caf") else {
            return nil
        }
        var soundID: SystemSoundID = 0
        let status = AudioServicesCreateSystemSoundID(url as CFURL, &soundID)
        return status == kAudioServicesNoError ? soundID : nil
    }()
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
