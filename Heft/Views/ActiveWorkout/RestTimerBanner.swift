// iOS 26+ only. No #available guards.

import SwiftUI

/// Inline rest timer shown at the top of the active workout scroll view.
/// Replaces the sheet modal — zero extra taps to see or adjust the timer.
struct RestTimerBanner: View {
    let restTimer: RestTimerState
    let vm: ActiveWorkoutViewModel

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { ctx in
            timerContent(at: ctx.date)
        }
    }

    @ViewBuilder
    private func timerContent(at now: Date) -> some View {
        let phase = restTimer.tintColor(at: now)
        let tint = phaseColor(phase)
        let progress = restTimer.progress(at: now) ?? 0
        let label = restTimer.remainingLabel(at: now) ?? "0:00"

        VStack(spacing: Spacing.sm) {
            // ── Header row ───────────────────────────────────────────────
            HStack {
                Text("REST")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(tint)
                Spacer()
                Button("Skip") { restTimer.skip() }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
                    .buttonStyle(.plain)
            }

            // ── Timer + controls ─────────────────────────────────────────
            HStack(alignment: .center, spacing: 0) {
                Text(label)
                    .font(.system(size: 48, weight: .light, design: .monospaced))
                    .foregroundStyle(tint)
                    .contentTransition(.numericText(countsDown: true))
                    .monospacedDigit()
                    .animation(Motion.standardSpring, value: label)

                Spacer()

                HStack(spacing: Spacing.sm) {
                    Button {
                        restTimer.adjust(seconds: -30)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Text("−30s")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.textMuted)
                            .frame(width: 60, height: 44)
                            .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button {
                        restTimer.adjust(seconds: 30)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Text("+30s")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.textMuted)
                            .frame(width: 60, height: 44)
                            .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }

            // ── Progress bar ─────────────────────────────────────────────
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(tint.opacity(0.15))
                    Capsule()
                        .fill(tint)
                        .frame(width: geo.size.width * CGFloat(progress))
                }
            }
            .frame(height: 4)
            .animation(Motion.standardSpring, value: progress)
        }
        .padding(Spacing.md)
        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                .strokeBorder(tint.opacity(0.25), lineWidth: 1)
        )
        .phaseAnimator([1.0, 1.02, 1.0], trigger: restTimer.pulseCount) { content, scale in
            content.scaleEffect(scale)
        } animation: { _ in Motion.standardSpring }
        .sensoryFeedback(.impact(weight: .heavy, intensity: 1.0), trigger: restTimer.pulseCount)
        .onAppear { restTimer.tick(at: now) }
    }

    private func phaseColor(_ phase: TimerTintPhase) -> Color {
        switch phase {
        case .green: Color.heftGreen
        case .amber: Color.heftAmber
        case .red:   Color.heftRed
        }
    }
}
