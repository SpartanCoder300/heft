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

// MARK: - Widget

struct RYFTWidgetsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            LockScreenBanner(context: context)
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
            .contentMargins(.trailing, 6, for: .compactLeading)
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
                Text("\(state.setsLogged) sets")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.6))
                    .contentTransition(.numericText(countsDown: false))
            }
            // Expands to fill all available space — pushes timer to far right edge
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(state.startedAt, style: .timer)
                .font(.system(size: 17, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.8))
                .frame(width: 56, alignment: .trailing)
        }
        .padding(20)
    }
}

private struct RestingBanner: View {
    let endsAt: Date
    let totalDuration: TimeInterval
    let exercise: String

    var phaseColor: Color { restPhaseColor(endsAt: endsAt, totalDuration: totalDuration) }
    var startDate: Date { endsAt.addingTimeInterval(-totalDuration) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Rest")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
                    .textCase(.uppercase)
                    .tracking(0.5)
                Spacer()
                Text(timerInterval: Date.now...endsAt, countsDown: true, showsHours: false)
                    .font(.system(size: 22, weight: .semibold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(phaseColor)
            }

            ProgressView(timerInterval: startDate...endsAt, countsDown: true,
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
            VStack(alignment: .leading, spacing: 2) {
                Text("Rest")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
                    .textCase(.uppercase)
                    .tracking(0.8)
                Text(timerInterval: Date.now...endsAt, countsDown: true, showsHours: false)
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(restPhaseColor(endsAt: endsAt, totalDuration: total))
                    .minimumScaleFactor(0.7)
            }
            .padding(.leading, 12)
            .padding(.vertical, 8)
        } else {
            VStack(alignment: .leading, spacing: 3) {
                Text(context.state.currentExercise)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .dynamicIsland(verticalPlacement: .belowIfTooWide)
                Text("\(context.state.setsLogged) sets")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(context.state.accentColor)
                    .contentTransition(.numericText(countsDown: false))
            }
            .padding(.leading, 12)
            .padding(.vertical, 8)
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
        } else {
            Text(context.state.startedAt, style: .timer)
                .font(.system(size: 24, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(.white)
                .padding(.trailing, 12)
                .padding(.vertical, 8)
        }
    }
}

private struct ExpandedBottom: View {
    let context: ActivityViewContext<WorkoutActivityAttributes>

    var body: some View {
        if context.state.isResting, let endsAt = context.state.restEndsAt,
           let total = context.state.totalRestDuration {
            ProgressView(
                timerInterval: endsAt.addingTimeInterval(-total)...endsAt,
                countsDown: true,
                label: { EmptyView() },
                currentValueLabel: { EmptyView() }
            )
            .progressViewStyle(.linear)
            .tint(restPhaseColor(endsAt: endsAt, totalDuration: total))
            .padding(.horizontal, 12)
        } else {
            HStack(spacing: 4) {
                Text(context.attributes.routineName)
                    .lineLimit(1)
                Text("·")
                Text("\(context.state.setsLogged) sets")
                    .contentTransition(.numericText(countsDown: false))
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.white.opacity(0.45))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
        }
    }
}

// MARK: - Dynamic Island Compact

private struct CompactLeading: View {
    let context: ActivityViewContext<WorkoutActivityAttributes>

    var body: some View {
        if context.state.isResting, let endsAt = context.state.restEndsAt,
           let total = context.state.totalRestDuration {
            // Rest: countdown is the dominant, urgent signal
            Text(timerInterval: Date.now...endsAt, countsDown: true, showsHours: false)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(restPhaseColor(endsAt: endsAt, totalDuration: total))
                .minimumScaleFactor(0.8)
                .lineLimit(1)
        } else {
            // Working: icon signals activity type instantly
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(context.state.accentColor)
        }
    }
}

private struct CompactTrailing: View {
    let context: ActivityViewContext<WorkoutActivityAttributes>

    var body: some View {
        if context.state.isResting {
            // Rest trailing: stable white — countdown + keyline already track the phase
            Text("\(context.state.setsLogged)")
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.75))
                .contentTransition(.numericText(countsDown: false))
        } else {
            // Working trailing: elapsed timer with showsHours: false so it stays M:SS
            // even past 60 min, preventing layout blowout in the compact pill.
            Text(timerInterval: context.state.startedAt...Date.distantFuture,
                 countsDown: false, showsHours: false)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.8))
                .minimumScaleFactor(0.8)
                .lineLimit(1)
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
            Text(timerInterval: Date.now...endsAt, countsDown: true, showsHours: false)
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
              restEndsAt: nil,
              totalRestDuration: nil,
              accentR: 0.486, accentG: 0.498, accentB: 0.961) // Midnight
    }
    fileprivate static var resting: WorkoutActivityAttributes.ContentState {
        .init(startedAt: .now.addingTimeInterval(-780),
              currentExercise: "Barbell Bench Press",
              setsLogged: 5,
              restEndsAt: .now.addingTimeInterval(75),
              totalRestDuration: 90,
              accentR: 0.486, accentG: 0.498, accentB: 0.961) // Midnight
    }
}

#Preview("Working", as: .content, using: WorkoutActivityAttributes.preview) {
    RYFTWidgetsLiveActivity()
} contentStates: {
    WorkoutActivityAttributes.ContentState.working
}

#Preview("Resting", as: .content, using: WorkoutActivityAttributes.preview) {
    RYFTWidgetsLiveActivity()
} contentStates: {
    WorkoutActivityAttributes.ContentState.resting
}
