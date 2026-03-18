// iOS 26+ only. No #available guards.

import SwiftUI
import SwiftData

// MARK: - Rest Timer Sheet

struct RestTimerSheet: View {
    let restTimer: RestTimerState
    let vm: ActiveWorkoutViewModel
    @Environment(\.heftTheme) private var theme

    private let ringSize: CGFloat = 200
    private let ringLineWidth: CGFloat = 10

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { ctx in
            let now = ctx.date
            let _ = restTimer.tick(at: now)
            let tint = restTimer.tintColor(at: now)
            let tintColor = color(for: tint)
            let progress = restTimer.progress(at: now) ?? 0
            let label = restTimer.remainingLabel(at: now) ?? "0:00"

            VStack(spacing: 0) {
                // ── Drag indicator ──────────────────────────────────
                Capsule()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 36, height: 4)
                    .padding(.top, Spacing.md)
                    .padding(.bottom, Spacing.lg)

                Spacer(minLength: 0)

                // ── Arc ring + countdown ────────────────────────────
                ZStack {
                    Circle()
                        .stroke(tintColor.opacity(0.08), lineWidth: ringLineWidth)

                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(tintColor, style: StrokeStyle(lineWidth: ringLineWidth, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(Motion.standardSpring, value: progress)

                    VStack(spacing: 4) {
                        Text("REST")
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(1.5)
                            .foregroundStyle(Color.textFaint)

                        Text(label)
                            .font(.system(size: 50, weight: .light, design: .monospaced))
                            .tracking(-1.5)
                            .foregroundStyle(tintColor)
                            .contentTransition(.numericText(countsDown: true))
                            .animation(Motion.standardSpring, value: label)

                        if let info = nextSetInfo {
                            Text("\(info.exerciseName) · Set \(info.setNumber)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color.textFaint)
                        }
                    }
                }
                .frame(width: ringSize, height: ringSize)
                .phaseAnimator([1.0, 1.08, 1.0], trigger: restTimer.pulseCount) { content, scale in
                    content.scaleEffect(scale)
                } animation: { _ in
                    Motion.standardSpring
                }
                .sensoryFeedback(.impact(weight: .heavy, intensity: 1.0), trigger: restTimer.pulseCount)

                Spacer(minLength: Spacing.lg)

                // ── Next Set card ───────────────────────────────────
                if let info = nextSetInfo {
                    NextSetCard(
                        info: info,
                        accentColor: theme.accentColor,
                        onAdjustWeight: { vm.adjustWeight(exerciseIndex: info.exerciseIndex, setIndex: info.setIndex, increment: $0) },
                        onAdjustReps:   { vm.adjustReps(exerciseIndex: info.exerciseIndex,   setIndex: info.setIndex, increment: $0) }
                    )
                    .padding(.horizontal, Spacing.lg)
                }

                Spacer(minLength: Spacing.lg)

                // ── Controls ────────────────────────────────────────
                HStack(spacing: Spacing.sm) {
                    TimerControlButton(label: "−30s") { restTimer.adjust(seconds: -30) }
                    TimerControlButton(label: "Skip Rest", isSkip: true, tintColor: tintColor) { restTimer.skip() }
                    TimerControlButton(label: "+30s") { restTimer.adjust(seconds: 30) }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.xl)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                Color.heftBackground
                    .opacity(0.55)
                    .background(.ultraThinMaterial)
                    .ignoresSafeArea()
            }
        }
    }

    private var nextSetInfo: NextSetInfo? {
        for eIdx in vm.draftExercises.indices {
            let exercise = vm.draftExercises[eIdx]
            guard let sIdx = exercise.sets.firstIndex(where: { !$0.isLogged }) else { continue }
            let set = exercise.sets[sIdx]
            return NextSetInfo(
                exerciseName: exercise.exerciseName,
                exerciseIndex: eIdx,
                setIndex: sIdx,
                setNumber: sIdx + 1,
                totalSets: exercise.sets.count,
                weight: set.weightText,
                reps: set.repsText
            )
        }
        return nil
    }

    private func color(for phase: TimerTintPhase) -> Color {
        switch phase {
        case .green: Color.heftGreen
        case .amber: Color.heftAmber
        case .red:   Color.heftRed
        }
    }
}

// MARK: - Next Set Info

private struct NextSetInfo {
    let exerciseName: String
    let exerciseIndex: Int
    let setIndex: Int
    let setNumber: Int
    let totalSets: Int
    let weight: String
    let reps: String
}

// MARK: - Next Set Card

private struct NextSetCard: View {
    let info: NextSetInfo
    let accentColor: Color
    let onAdjustWeight: (Bool) -> Void
    let onAdjustReps: (Bool) -> Void

    var body: some View {
        VStack(spacing: Spacing.md) {
            HStack {
                Text("NEXT SET")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.0)
                    .foregroundStyle(accentColor)
                Spacer()
                Text("Set \(info.setNumber) of \(info.totalSets)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.textFaint)
            }

            Text(info.exerciseName)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            GeometryReader { geo in
                let fraction = CGFloat(info.setNumber - 1) / CGFloat(max(1, info.totalSets))
                ZStack(alignment: .leading) {
                    Capsule().fill(accentColor.opacity(0.15))
                    Capsule().fill(accentColor).frame(width: geo.size.width * fraction)
                }
            }
            .frame(height: 4)

            HStack(spacing: Spacing.md) {
                TimerStepperField(label: "WEIGHT", value: info.weight, unit: "lbs", onAdjust: onAdjustWeight)
                TimerStepperField(label: "REPS",   value: info.reps,   unit: "",    onAdjust: onAdjustReps)
            }
        }
        .padding(Spacing.md)
        .background(accentColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(accentColor.opacity(0.35), lineWidth: 1)
        )
    }
}

// MARK: - Timer Stepper Field

private struct TimerStepperField: View {
    let label: String
    let value: String
    let unit: String
    let onAdjust: (Bool) -> Void

    var body: some View {
        VStack(spacing: Spacing.xs) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(Color.textFaint)

            HStack(spacing: 0) {
                Button { onAdjust(false); UIImpactFeedbackGenerator(style: .light).impactOccurred() } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.textMuted)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                VStack(spacing: 0) {
                    Text(value.isEmpty ? "—" : value)
                        .font(.system(size: 20, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.textPrimary)
                    if !unit.isEmpty {
                        Text(unit)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(Color.textFaint)
                    }
                }
                .frame(minWidth: 48)

                Button { onAdjust(true); UIImpactFeedbackGenerator(style: .light).impactOccurred() } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.textMuted)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Timer Control Button

private struct TimerControlButton: View {
    let label: String
    var isSkip: Bool = false
    var tintColor: Color = .clear
    var onTap: (() -> Void)?

    var body: some View {
        Button { onTap?() } label: {
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isSkip ? tintColor : Color.textMuted)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    isSkip ? AnyShapeStyle(.clear) : AnyShapeStyle(Color.white.opacity(0.07)),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
                .overlay(
                    isSkip
                        ? RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(tintColor.opacity(0.35), lineWidth: 1)
                        : nil
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Previews

#Preview("Green") {
    @Previewable @State var timer = RestTimerState()
    let vm = ActiveWorkoutViewModel(
        modelContext: PersistenceController.previewContainer.mainContext,
        pendingRoutineID: nil
    )
    RestTimerSheet(restTimer: timer, vm: vm)
        .onAppear { timer.simulateInProgress(totalDuration: 90, elapsed: 10) }
}

#Preview("Amber") {
    @Previewable @State var timer = RestTimerState()
    let vm = ActiveWorkoutViewModel(
        modelContext: PersistenceController.previewContainer.mainContext,
        pendingRoutineID: nil
    )
    RestTimerSheet(restTimer: timer, vm: vm)
        .onAppear { timer.simulateInProgress(totalDuration: 90, elapsed: 55) }
}

#Preview("Red") {
    @Previewable @State var timer = RestTimerState()
    let vm = ActiveWorkoutViewModel(
        modelContext: PersistenceController.previewContainer.mainContext,
        pendingRoutineID: nil
    )
    RestTimerSheet(restTimer: timer, vm: vm)
        .onAppear { timer.simulateInProgress(totalDuration: 90, elapsed: 78) }
}
