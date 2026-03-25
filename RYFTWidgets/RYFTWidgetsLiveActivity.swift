// iOS 26+ only. No #available guards.

import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Brand colours (duplicated from main target — widget extension is a separate module)

private extension Color {
    static let ryftBg    = Color(red: 0.038, green: 0.036, blue: 0.058)
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

// MARK: - Widget

struct RYFTWidgetsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            LockScreenBanner(context: context)
                .activityBackgroundTint(Color.ryftBg)
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
            .keylineTint(.ryftGreen)
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
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.ryftGreen)

            VStack(alignment: .leading, spacing: 2) {
                Text(state.currentExercise)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text("\(state.setsLogged) sets logged")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.6))
            }

            Spacer()

            Text(state.startedAt, style: .timer)
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
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
                Text(timerInterval: Date.now...endsAt, countsDown: true)
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
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - Dynamic Island Expanded

private struct ExpandedLeading: View {
    let context: ActivityViewContext<WorkoutActivityAttributes>

    var body: some View {
        if context.state.isResting, let endsAt = context.state.restEndsAt,
           let total = context.state.totalRestDuration {
            VStack(alignment: .leading, spacing: 4) {
                Text(timerInterval: Date.now...endsAt, countsDown: true)
                    .font(.system(size: 26, weight: .bold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(restPhaseColor(endsAt: endsAt, totalDuration: total))
                    .minimumScaleFactor(0.7)
                Text("Rest")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
                    .textCase(.uppercase)
                    .tracking(0.5)
            }
            .padding(.leading, 4)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Text(context.state.currentExercise)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Text("\(context.state.setsLogged) sets")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.ryftGreen)
            }
            .padding(.leading, 4)
        }
    }
}

private struct ExpandedTrailing: View {
    let context: ActivityViewContext<WorkoutActivityAttributes>

    var body: some View {
        if context.state.isResting {
            VStack(alignment: .trailing, spacing: 4) {
                Text("Next")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
                    .textCase(.uppercase)
                    .tracking(0.5)
                Text(context.state.currentExercise)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .multilineTextAlignment(.trailing)
            }
            .padding(.trailing, 4)
        } else {
            VStack(alignment: .trailing, spacing: 4) {
                Text(context.state.startedAt, style: .timer)
                    .font(.system(size: 20, weight: .semibold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                Text(context.attributes.routineName)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.4))
                    .lineLimit(1)
            }
            .padding(.trailing, 4)
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
            .padding(.horizontal, 4)
        } else {
            EmptyView()
        }
    }
}

// MARK: - Dynamic Island Compact

private struct CompactLeading: View {
    let context: ActivityViewContext<WorkoutActivityAttributes>

    var body: some View {
        if context.state.isResting, let endsAt = context.state.restEndsAt,
           let total = context.state.totalRestDuration {
            Text(timerInterval: Date.now...endsAt, countsDown: true)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(restPhaseColor(endsAt: endsAt, totalDuration: total))
                .padding(.leading, 4)
        } else {
            Text(context.state.startedAt, style: .timer)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.8))
                .padding(.leading, 4)
        }
    }
}

private struct CompactTrailing: View {
    let context: ActivityViewContext<WorkoutActivityAttributes>

    var body: some View {
        // Leading already shows the countdown during rest — show set count here for context.
        Text("\(context.state.setsLogged)")
            .font(.system(size: 14, weight: .semibold, design: .monospaced))
            .foregroundStyle(context.state.isResting ? Color.ryftAmber : Color.ryftGreen)
            .padding(.trailing, 4)
    }
}

// MARK: - Minimal

private struct MinimalView: View {
    let context: ActivityViewContext<WorkoutActivityAttributes>

    var body: some View {
        if context.state.isResting, let endsAt = context.state.restEndsAt,
           let total = context.state.totalRestDuration {
            Text(timerInterval: Date.now...endsAt, countsDown: true)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(restPhaseColor(endsAt: endsAt, totalDuration: total))
                .minimumScaleFactor(0.7)
        } else {
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.ryftGreen)
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
              totalRestDuration: nil)
    }
    fileprivate static var resting: WorkoutActivityAttributes.ContentState {
        .init(startedAt: .now.addingTimeInterval(-780),
              currentExercise: "Barbell Bench Press",
              setsLogged: 5,
              restEndsAt: .now.addingTimeInterval(75),
              totalRestDuration: 90)
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
