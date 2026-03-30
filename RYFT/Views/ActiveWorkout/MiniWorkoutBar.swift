// iOS 26+ only. No #available guards.

import SwiftUI

/// Mini workout bar rendered inside .tabViewBottomAccessory(isEnabled:).
/// The system provides the Liquid Glass capsule — this view supplies only the content layout.
struct MiniWorkoutBar: View {
    let service: ActiveWorkoutService
    @Environment(\.ryftTheme) private var theme

    var body: some View {
        if let vm = service.viewModel {
            HStack(spacing: 0) {
                // ── Left: exercise + set context ─────────────────────────────
                Button {
                    service.isShowingFullWorkout = true
                } label: {
                    HStack(alignment: .center, spacing: 8) {
                        LiveDot(color: theme.accentColor)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(service.focusedExerciseName ?? "Workout")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)

                            Text(setLabel(vm: vm))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 16)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Divider()
                    .frame(height: 28)
                    .padding(.horizontal, 12)

                // ── Right: rest timer or elapsed ─────────────────────────────
                Button {
                    service.isShowingFullWorkout = true
                } label: {
                    RestTimerIndicator(timer: vm.restTimer, openedAt: vm.openedAt)
                        .padding(.trailing, 16)
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func setLabel(vm: ActiveWorkoutViewModel) -> String {
        guard let focus = vm.currentFocus,
              vm.draftExercises.indices.contains(focus.exerciseIndex) else {
            return "—"
        }
        let exercise = vm.draftExercises[focus.exerciseIndex]
        return "Set \(focus.setIndex + 1) of \(exercise.sets.count)"
    }
}

// MARK: - Live Dot

/// Pulsing accent dot — signals an active live state, like Apple's call/recording indicator.
private struct LiveDot: View {
    let color: Color
    @State private var isPulsing = false

    var body: some View {
        ZStack {
            // Ripple ring
            Circle()
                .fill(color.opacity(0.25))
                .frame(width: 7, height: 7)
                .scaleEffect(isPulsing ? 2.6 : 1.0)
                .opacity(isPulsing ? 0 : 1)
                .animation(
                    .easeOut(duration: 1.2).repeatForever(autoreverses: false),
                    value: isPulsing
                )

            // Solid core
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
        }
        .onAppear { isPulsing = true }
    }
}

// MARK: - Rest Timer Indicator

/// Shows rest countdown when active; falls back to elapsed workout time when idle.
private struct RestTimerIndicator: View {
    let timer: RestTimerState
    let openedAt: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { ctx in
            if timer.isActive, let label = timer.remainingLabel(at: ctx.date) {
                let phase = timer.tintColor(at: ctx.date)
                Text(label)
                    .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                    .foregroundStyle(phaseColor(phase))
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: true))
            } else {
                // Elapsed time when no rest timer active
                Text(elapsedLabel(at: ctx.date))
                    .font(.system(.subheadline, design: .monospaced).weight(.regular))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }

    private func elapsedLabel(at now: Date) -> String {
        let seconds = Int(now.timeIntervalSince(openedAt))
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }

    private func phaseColor(_ phase: TimerTintPhase) -> Color {
        switch phase {
        case .calm:      Color.textPrimary.opacity(0.78)
        case .readySoon: Color.ryftAmber
        }
    }
}
