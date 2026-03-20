// iOS 26+ only. No #available guards.

import SwiftUI
import SwiftData

struct HomeRootView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.heftTheme) private var theme

    @Query(sort: \RoutineTemplate.createdAt, order: .reverse)
    private var routines: [RoutineTemplate]

    @Query(sort: \WorkoutSession.startedAt, order: .reverse)
    private var sessions: [WorkoutSession]

    @State private var stats = HomeStatsViewModel()
    @State private var routineBuilderRequest: RoutineBuilderRequest? = nil

    /// Most recently used first, falling back to creation date.
    private var sortedRoutines: [RoutineTemplate] {
        routines.sorted { a, b in
            let aDate = a.lastUsedAt ?? a.createdAt
            let bDate = b.lastUsedAt ?? b.createdAt
            return aDate > bDate
        }
    }

    private var recentSessions: [WorkoutSession] {
        Array(sessions.filter { $0.completedAt != nil }.prefix(3))
    }

    private var routineAvgMinutes: [UUID: Int] {
        var byRoutine: [UUID: [TimeInterval]] = [:]
        for session in sessions {
            guard let rid = session.routineTemplateId,
                  let start = session.startedAt,
                  let end = session.completedAt else { continue }
            byRoutine[rid, default: []].append(end.timeIntervalSince(start))
        }
        return byRoutine.compactMapValues { durations -> Int? in
            guard !durations.isEmpty else { return nil }
            return Int(durations.reduce(0, +) / Double(durations.count) / 60)
        }
    }

    var body: some View {
        @Bindable var appState = appState

        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {

                // ── Greeting ───────────────────────────────────────────
                VStack(alignment: .leading, spacing: 2) {
                    Text(Date.now.formatted(.dateTime.weekday(.wide)))
                        .font(Typography.caption)
                        .foregroundStyle(Color.textFaint)
                        .textCase(.uppercase)
                        .tracking(1)
                    Text("Ready to lift?")
                        .font(Typography.display)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.textPrimary)
                }

                // ── Stat Chips ─────────────────────────────────────────
                HStack(spacing: Spacing.sm) {
                    StatChip(label: "Day Streak", value: stats.streakLabel)
                    StatChip(label: "This Week", value: stats.thisWeekLabel)
                    StatChip(label: "PRs", value: stats.prCountLabel, valueColor: Color.heftAmber)
                }

                // ── Routines ───────────────────────────────────────────
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    SectionHeader(title: "Routines")

                    if sortedRoutines.isEmpty {
                        EmptyRoutinesPrompt {
                            routineBuilderRequest = RoutineBuilderRequest(routine: nil)
                        }
                    } else {
                        ForEach(sortedRoutines) { routine in
                            RoutineListRow(
                                routine: routine,
                                avgMinutes: routineAvgMinutes[routine.id],
                                onTap: {
                                    appState.workout.startWorkout(routineID: routine.id, modelContext: modelContext)
                                },
                                onEdit: {
                                    routineBuilderRequest = RoutineBuilderRequest(routine: routine)
                                }
                            )
                        }

                        NewRoutineCard {
                            routineBuilderRequest = RoutineBuilderRequest(routine: nil)
                        }
                    }

                    Button {
                        appState.workout.startWorkout(routineID: nil, sessionID: nil, modelContext: modelContext)
                    } label: {
                        Text("or start empty workout")
                            .font(Typography.caption)
                            .foregroundStyle(Color.textFaint)
                            .padding(.horizontal, Spacing.md)
                            .padding(.vertical, Spacing.xs)
                    }
                    .buttonStyle(.plain)
                }

                // ── Recent Workouts ────────────────────────────────────
                if !recentSessions.isEmpty {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        SectionHeader(title: "Recent")
                        ForEach(recentSessions) { session in
                            RecentWorkoutListRow(session: session) {
                                appState.workout.startWorkout(routineID: nil, sessionID: session.id, modelContext: modelContext)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.lg)
        }
        .themedBackground()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    routineBuilderRequest = RoutineBuilderRequest(routine: nil)
                } label: {
                    Image(systemName: "plus")
                        .fontWeight(.semibold)
                }
                .accessibilityLabel("New routine")
            }
        }
        .sheet(item: $routineBuilderRequest) { request in
            RoutineBuilderView(existingRoutine: request.routine) { routineID in
                appState.workout.startWorkout(routineID: routineID, modelContext: modelContext)
            }
        }
        .onChange(of: sessions, initial: true) {
            stats.update(container: modelContext.container)
        }
    }
}

// MARK: - Routine Builder Request

/// Wraps an optional RoutineTemplate in an Identifiable so sheet(item:) always
/// receives the correct routine at the moment the user taps "Edit" or "New".
private struct RoutineBuilderRequest: Identifiable {
    let id = UUID()
    let routine: RoutineTemplate?
}

// MARK: - Section Header

private struct SectionHeader: View {
    let title: String
    var detail: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(Typography.caption)
                .fontWeight(.semibold)
                .foregroundStyle(Color.textFaint)
                .textCase(.uppercase)
                .tracking(0.8)
            Spacer()
            if let detail {
                Text(detail)
                    .font(Typography.caption)
                    .foregroundStyle(Color.textFaint)
            }
        }
    }
}

// MARK: - Stat Chip

private struct StatChip: View {
    let label: String
    let value: String
    var valueColor: Color = Color.textPrimary

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(Typography.title)
                .fontWeight(.semibold)
                .foregroundStyle(valueColor)
                .monospacedDigit()
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.textFaint)
                .textCase(.uppercase)
                .tracking(0.5)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
    }
}

// MARK: - Routine List Row

private struct RoutineListRow: View {
    let routine: RoutineTemplate
    let avgMinutes: Int?
    let onTap: () -> Void
    let onEdit: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(routine.name)
                        .font(Typography.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.textPrimary)
                    if !muscleGroupSummary.isEmpty {
                        Text(muscleGroupSummary)
                            .font(Typography.caption)
                            .foregroundStyle(Color.textMuted)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: Spacing.xs) {
                    Text("\(routine.entries.count) exercises")
                        .font(Typography.caption)
                        .foregroundStyle(Color.textMuted)
                    Text(avgMinutes.map { "\($0) min avg" } ?? "— min avg")
                        .font(Typography.caption)
                        .foregroundStyle(Color.textFaint)
                }
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button { onEdit() } label: {
                Label("Edit Routine", systemImage: "pencil")
            }
        }
    }

    /// Unique muscle groups from this routine's exercise definitions, up to 3.
    private var muscleGroupSummary: String {
        var seen = Set<String>()
        var ordered: [String] = []
        for entry in routine.entries {
            for group in (entry.exerciseDefinition?.muscleGroups ?? []) {
                if seen.insert(group).inserted { ordered.append(group) }
            }
        }
        return ordered.prefix(3).joined(separator: " · ")
    }
}

// MARK: - New Routine Card

private struct NewRoutineCard: View {
    let action: () -> Void
    @Environment(\.heftTheme) private var theme

    var body: some View {
        Button(action: action) {
            Label("New Routine", systemImage: "plus.circle.fill")
                .font(Typography.body.weight(.medium))
                .foregroundStyle(theme.accentColor)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Recent Workout Row

private struct RecentWorkoutListRow: View {
    let session: WorkoutSession
    let onRepeat: () -> Void

    var body: some View {
        Button(action: onRepeat) {
            HStack {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(dateLabel)
                        .font(Typography.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.textPrimary)
                    if let summary = exerciseSummary {
                        Text(summary)
                            .font(Typography.caption)
                            .foregroundStyle(Color.textMuted)
                            .lineLimit(1)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: Spacing.xs) {
                    if let d = durationLabel {
                        Text(d)
                            .font(Typography.caption)
                            .foregroundStyle(Color.textMuted)
                    }
                    Text("Repeat →")
                        .font(Typography.caption)
                        .foregroundStyle(Color.textFaint)
                }
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var dateLabel: String {
        let date = session.completedAt ?? session.startedAt ?? .now
        return date.formatted(.dateTime.month(.abbreviated).day().year())
    }

    private var durationLabel: String? {
        guard let start = session.startedAt, let end = session.completedAt else { return nil }
        let minutes = Int(end.timeIntervalSince(start) / 60)
        return "\(minutes) min"
    }

    private var exerciseSummary: String? {
        let names = session.exercises
            .sorted { $0.order < $1.order }
            .prefix(3)
            .map { $0.exerciseName }
        return names.isEmpty ? nil : names.joined(separator: " · ")
    }
}

// MARK: - Empty State

private struct EmptyRoutinesPrompt: View {
    let onTap: () -> Void
    @Environment(\.heftTheme) private var theme

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: Spacing.sm) {
                Image(systemName: "list.bullet.clipboard")
                    .font(.system(size: DesignTokens.Icon.placeholder * 0.75))
                    .foregroundStyle(theme.accentColor)
                Text("Create your first routine")
                    .font(Typography.body)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.textPrimary)
                Text("Tap here to build a routine and launch sessions faster.")
                    .font(Typography.caption)
                    .foregroundStyle(Color.textMuted)
                    .multilineTextAlignment(.center)
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "plus.circle.fill")
                    Text("New Routine")
                        .fontWeight(.semibold)
                }
                .font(Typography.caption)
                .foregroundStyle(theme.accentColor)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.xs)
                .background(theme.accentColor.opacity(0.12), in: Capsule())
                .padding(.top, Spacing.xs)
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                    .strokeBorder(theme.accentColor.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}


#Preview {
    NavigationStack {
        HomeRootView()
    }
    .environment(AppState())
    .modelContainer(PersistenceController.previewContainer)
}
