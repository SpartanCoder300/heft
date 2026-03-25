// iOS 26+ only. No #available guards.

import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Brand colours (duplicated from main target — widget extension is a separate module)

private extension Color {
    static let ryftGreen = Color(red: 0.204, green: 0.827, blue: 0.600)
    static let ryftAmber = Color(red: 0.961, green: 0.620, blue: 0.043)
    static let ryftRed   = Color(red: 1.000, green: 0.271, blue: 0.227)
}

private func restPhaseColor(endsAt: Date, totalDuration: TimeInterval) -> Color {
    guard totalDuration > 0 else { return .ryftGreen }
    let ratio = max(0, endsAt.timeIntervalSinceNow) / totalDuration
    if ratio > 0.5 { return .ryftGreen }
    if ratio > 0.2 { return .ryftAmber }
    return .ryftRed
}

/// Returns the Dynamic Island keyline tint — tracks rest phase during rest,
/// user's accent colour during active work.
private func keylineTint(for state: WorkoutActivityAttributes.ContentState) -> Color {
    guard state.isResting,
          let endsAt = state.restEndsAt,
          let total  = state.totalRestDuration else { return state.accentColor }
    return restPhaseColor(endsAt: endsAt, totalDuration: total)
}

private func clampedRestEndDate(_ endsAt: Date) -> Date {
    endsAt < .now ? .now : endsAt
}

private func workoutTimerEndDate(from startedAt: Date) -> Date {
    // Live Activities are limited to ~8 hours active. Keep timer ranges finite.
    startedAt.addingTimeInterval(8 * 60 * 60)
}

private func compactSetLabel(from focusedSetLabel: String?, fallbackSetsLogged: Int) -> String {
    guard let label = focusedSetLabel else { return "\(fallbackSetsLogged)" }
    let parts = label.split(separator: " ")
    if parts.count >= 4, parts[0] == "Set", parts[2] == "of" {
        return "\(parts[1])" + "/" + "\(parts[3])"
    }
    return "\(fallbackSetsLogged)"
}

private func lockScreenBackgroundTint(for state: WorkoutActivityAttributes.ContentState) -> Color {
    // Deep charcoal base with a subtle accent tint for a premium, restrained look.
    let baseR = 0.07
    let baseG = 0.07
    let baseB = 0.065
    let accentR = state.accentR ?? 0.204
    let accentG = state.accentG ?? 0.827
    let accentB = state.accentB ?? 0.600
    let mix = 0.08
    let r = baseR * (1 - mix) + accentR * mix
    let g = baseG * (1 - mix) + accentG * mix
    let b = baseB * (1 - mix) + accentB * mix
    return Color(red: r, green: g, blue: b)
}

// MARK: - Widget

struct RYFTWidgetsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            LockScreenBanner(context: context)
                .activityBackgroundTint(lockScreenBackgroundTint(for: context.state))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    ExpandedLeading(context: context)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ExpandedTrailing(context: context)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedBottom(context: context)
                }
            } compactLeading: {
                CompactLeading(context: context)
            } compactTrailing: {
                CompactTrailing(context: context)
            } minimal: {
                MinimalView(context: context)
            }
            // Nudge compact content inward so it sits snug against the pill
            .contentMargins(.leading, 6, for: .compactLeading)
            .contentMargins(.leading, 6, for: .compactTrailing)
            // Keyline tracks rest phase — pill border goes green → amber → red
            .keylineTint(keylineTint(for: context.state))
            .widgetURL(URL(string: "ryft://workout"))
        }
    }
}

// MARK: - Lock Screen Banner

private struct LockScreenBanner: View {
    let context: ActivityViewContext<WorkoutActivityAttributes>

    var body: some View {
        Group {
            if context.state.isResting, let endsAt = context.state.restEndsAt,
               let total = context.state.totalRestDuration {
                RestingBanner(endsAt: endsAt, totalDuration: total,
                              exercise: context.state.currentExercise)
            } else {
                WorkingBanner(state: context.state,
                              routineName: context.attributes.routineName)
            }
        }
    }
}

private struct WorkingBanner: View {
    let state: WorkoutActivityAttributes.ContentState
    let routineName: String

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(state.accentColor)

            VStack(alignment: .leading, spacing: 3) {
                Text(state.currentExercise)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                let setLabel = state.focusedSetLabel ?? "\(state.setsLogged) sets"
                let setDetail = state.focusedSetDetail
                Text(setDetail.map { "\(setLabel) · \($0)" } ?? setLabel)
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.6))
                    .contentTransition(.numericText(countsDown: false))
                    .widgetAccentable()
            }
            // Expands to fill all available space — pushes timer to far right edge
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(timerInterval: state.startedAt...workoutTimerEndDate(from: state.startedAt),
                 countsDown: false, showsHours: false)
                .font(.system(size: 17, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(width: 56, alignment: .trailing)
        }
        .padding(20)
    }
}

private struct RestingBanner: View {
    let endsAt: Date
    let totalDuration: TimeInterval
    let exercise: String

    var clampedEndDate: Date { clampedRestEndDate(endsAt) }
    var phaseColor: Color { restPhaseColor(endsAt: clampedEndDate, totalDuration: totalDuration) }
    var startDate: Date { clampedEndDate.addingTimeInterval(-totalDuration) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Rest")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
                    .textCase(.uppercase)
                    .tracking(0.5)
                Spacer()
                Text(timerInterval: Date.now...clampedEndDate, countsDown: true, showsHours: false)
                    .font(.system(size: 22, weight: .semibold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(phaseColor)
            }

            ProgressView(timerInterval: startDate...clampedEndDate, countsDown: true,
                         label: { EmptyView() },
                         currentValueLabel: { EmptyView() })
                .progressViewStyle(.linear)
                .tint(phaseColor)

            Text(exercise)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.5))
                .lineLimit(1)
        }
        .padding(20)
    }
}

// MARK: - Dynamic Island Expanded

private struct ExpandedLeading: View {
    let context: ActivityViewContext<WorkoutActivityAttributes>

    var body: some View {
        if context.state.isResting, let endsAt = context.state.restEndsAt,
           let total = context.state.totalRestDuration {
            let clampedEndDate = clampedRestEndDate(endsAt)
            VStack(alignment: .leading, spacing: 2) {
                Text("Rest")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
                    .textCase(.uppercase)
                    .tracking(0.8)
                Text(timerInterval: Date.now...clampedEndDate, countsDown: true, showsHours: false)
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(restPhaseColor(endsAt: clampedEndDate, totalDuration: total))
                    .minimumScaleFactor(0.7)
            }
            .padding(.leading, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    } else {
            VStack(alignment: .leading, spacing: 3) {
                Text(context.state.currentExercise)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .dynamicIsland(verticalPlacement: .belowIfTooWide)
                let setLabel = context.state.focusedSetLabel ?? "\(context.state.setsLogged) sets"
                let setDetail = context.state.focusedSetDetail
                Text(setDetail.map { "\(setLabel) · \($0)" } ?? setLabel)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(context.state.accentColor)
                    .contentTransition(.numericText(countsDown: false))
                    .widgetAccentable()
            }
            .padding(.leading, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    }
    }
}

private struct ExpandedTrailing: View {
    let context: ActivityViewContext<WorkoutActivityAttributes>

    var body: some View {
        if context.state.isResting {
            VStack(alignment: .trailing, spacing: 3) {
                Text("Next")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
                    .textCase(.uppercase)
                    .tracking(0.8)
                Text(context.state.currentExercise)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .multilineTextAlignment(.trailing)
            }
            .padding(.trailing, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                    } else {
            Text(context.state.startedAt, style: .timer)
                .font(.system(size: 24, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(.white)
                .padding(.trailing, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                        }
    }
}

private struct ExpandedBottom: View {
    let context: ActivityViewContext<WorkoutActivityAttributes>

    var body: some View {
        if context.state.isResting, let endsAt = context.state.restEndsAt,
           let total = context.state.totalRestDuration {
            let clampedEndDate = clampedRestEndDate(endsAt)
            ProgressView(
                timerInterval: clampedEndDate.addingTimeInterval(-total)...clampedEndDate,
                countsDown: true,
                label: { EmptyView() },
                currentValueLabel: { EmptyView() }
            )
            .progressViewStyle(.linear)
            .tint(restPhaseColor(endsAt: clampedEndDate, totalDuration: total))
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
                    } else {
            VStack(alignment: .leading, spacing: 6) {
                if context.state.totalSetCount > 0 {
                    ProgressView(value: Double(context.state.setsLogged), total: Double(context.state.totalSetCount))
                        .progressViewStyle(.linear)
                        .tint(context.state.accentColor)
                        .widgetAccentable()
                }
                Text(context.attributes.routineName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.45))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
                    }
    }
}

// MARK: - Dynamic Island Compact

private enum CompactMetrics {
    static let leadingWidth: CGFloat = 40
    static let leadingInset: CGFloat = 4
    static let trailingWidth: CGFloat = 40
}

private struct CompactLeading: View {
    let context: ActivityViewContext<WorkoutActivityAttributes>

    var body: some View {
        if context.state.isResting, let endsAt = context.state.restEndsAt,
           let total = context.state.totalRestDuration {
            // Rest: countdown is the dominant, urgent signal
            HStack(spacing: 0) {
                Spacer().frame(width: CompactMetrics.leadingInset)
                Text(timerInterval: Date.now...clampedRestEndDate(endsAt), countsDown: true, showsHours: false)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(restPhaseColor(endsAt: endsAt, totalDuration: total))
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
            }
            .frame(width: CompactMetrics.leadingWidth, alignment: .leading)
        } else {
            // Working: icon signals activity type instantly
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(context.state.accentColor)
                .frame(width: CompactMetrics.leadingWidth, alignment: .center)
        }
    }
}

private struct CompactTrailing: View {
    let context: ActivityViewContext<WorkoutActivityAttributes>

    var body: some View {
        if context.state.isResting {
            // Rest trailing: focused set (short form) so it matches the current exercise.
            Text(compactSetLabel(from: context.state.focusedSetLabel, fallbackSetsLogged: context.state.setsLogged))
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.75))
                .contentTransition(.numericText(countsDown: false))
                .frame(width: CompactMetrics.trailingWidth, alignment: .trailing)
        } else {
            // Working trailing: elapsed timer with showsHours: false so it stays M:SS
            // even past 60 min, preventing layout blowout in the compact pill.
            Text(timerInterval: context.state.startedAt...workoutTimerEndDate(from: context.state.startedAt),
                 countsDown: false, showsHours: false)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.8))
                .minimumScaleFactor(0.8)
                .lineLimit(1)
                .frame(width: CompactMetrics.trailingWidth, alignment: .trailing)
        }
    }
}

// MARK: - Minimal

private struct MinimalView: View {
    let context: ActivityViewContext<WorkoutActivityAttributes>

    var body: some View {
        if context.state.isResting, let endsAt = context.state.restEndsAt,
           let total = context.state.totalRestDuration {
            // Minimal rest: countdown in 4 chars max (e.g. "1:30") — phase colored
            Text(timerInterval: Date.now...clampedRestEndDate(endsAt), countsDown: true, showsHours: false)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(restPhaseColor(endsAt: endsAt, totalDuration: total))
                .minimumScaleFactor(0.7)
        } else {
            // Minimal working: set count — most readable single metric in a ~20pt circle
            Text("\(context.state.setsLogged)")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(context.state.accentColor)
                .contentTransition(.numericText(countsDown: false))
        }
    }
}

// MARK: - Previews

extension WorkoutActivityAttributes {
    fileprivate static var preview: WorkoutActivityAttributes {
        WorkoutActivityAttributes(routineName: "Push Day")
    }
}

extension WorkoutActivityAttributes.ContentState {
    fileprivate static var working: WorkoutActivityAttributes.ContentState {
        .init(startedAt: .now.addingTimeInterval(-720),
              currentExercise: "Barbell Bench Press",
              setsLogged: 4,
              totalSetCount: 20,
              focusedSetLabel: "Set 3 of 5",
              focusedSetDetail: "135 × 8",
              restEndsAt: nil,
              totalRestDuration: nil,
              accentR: 0.831, accentG: 0.659, accentB: 0.325) // Champagne (Lux)
    }

    fileprivate static var resting: WorkoutActivityAttributes.ContentState {
        .init(startedAt: .now.addingTimeInterval(-780),
              currentExercise: "Barbell Bench Press",
              setsLogged: 5,
              totalSetCount: 20,
              focusedSetLabel: "Set 4 of 5",
              focusedSetDetail: "135 × 8",
              restEndsAt: .now.addingTimeInterval(75),
              totalRestDuration: 90,
              accentR: 0.831, accentG: 0.659, accentB: 0.325) // Champagne (Lux)
    }
}

#Preview("Lock Screen - Working", as: .content, using: WorkoutActivityAttributes.preview) {
    RYFTWidgetsLiveActivity()
} contentStates: {
    WorkoutActivityAttributes.ContentState.working
}

#Preview("Lock Screen - Resting", as: .content, using: WorkoutActivityAttributes.preview) {
    RYFTWidgetsLiveActivity()
} contentStates: {
    WorkoutActivityAttributes.ContentState.resting
}

#Preview("Dynamic Island Expanded - Working", as: .dynamicIsland(.expanded), using: WorkoutActivityAttributes.preview) {
    RYFTWidgetsLiveActivity()
} contentStates: {
    WorkoutActivityAttributes.ContentState.working
}

#Preview("Dynamic Island Expanded - Resting", as: .dynamicIsland(.expanded), using: WorkoutActivityAttributes.preview) {
    RYFTWidgetsLiveActivity()
} contentStates: {
    WorkoutActivityAttributes.ContentState.resting
}

#Preview("Dynamic Island Compact - Working", as: .dynamicIsland(.compact), using: WorkoutActivityAttributes.preview) {
    RYFTWidgetsLiveActivity()
} contentStates: {
    WorkoutActivityAttributes.ContentState.working
}

#Preview("Dynamic Island Compact - Resting", as: .dynamicIsland(.compact), using: WorkoutActivityAttributes.preview) {
    RYFTWidgetsLiveActivity()
} contentStates: {
    WorkoutActivityAttributes.ContentState.resting
}

#Preview("Dynamic Island Minimal - Working", as: .dynamicIsland(.minimal), using: WorkoutActivityAttributes.preview) {
    RYFTWidgetsLiveActivity()
} contentStates: {
    WorkoutActivityAttributes.ContentState.working
}

#Preview("Dynamic Island Minimal - Resting", as: .dynamicIsland(.minimal), using: WorkoutActivityAttributes.preview) {
    RYFTWidgetsLiveActivity()
} contentStates: {
    WorkoutActivityAttributes.ContentState.resting
}
