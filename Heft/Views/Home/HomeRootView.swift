// iOS 26+ only. No #available guards.

import SwiftUI
import SwiftData

struct HomeRootView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \RoutineTemplate.createdAt, order: .reverse)
    private var routines: [RoutineTemplate]

    @Query(sort: \WorkoutSession.startedAt, order: .reverse)
    private var sessions: [WorkoutSession]

    @State private var stats = HomeStatsViewModel()
    @State private var routineBuilderRequest: RoutineBuilderRequest? = nil

    private var sortedRoutines: [RoutineTemplate] {
        routines.sorted {
            ($0.lastUsedAt ?? $0.createdAt) > ($1.lastUsedAt ?? $1.createdAt)
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
                HomeGreetingView()

                HomeStatChipsRow(stats: stats)

                HomeRoutinesSection(
                    routines: sortedRoutines,
                    avgMinutes: routineAvgMinutes,
                    onStart: { id in
                        appState.workout.startWorkout(routineID: id, modelContext: modelContext)
                    },
                    onEdit: { routine in
                        routineBuilderRequest = RoutineBuilderRequest(routine: routine)
                    },
                    onNew: {
                        routineBuilderRequest = RoutineBuilderRequest(routine: nil)
                    },
                    onStartEmpty: {
                        appState.workout.startWorkout(routineID: nil, sessionID: nil, modelContext: modelContext)
                    }
                )

                HomeRecentSection(sessions: recentSessions) { session in
                    appState.workout.startWorkout(routineID: nil, sessionID: session.id, modelContext: modelContext)
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
                    Image(systemName: "plus").fontWeight(.semibold)
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

private struct RoutineBuilderRequest: Identifiable {
    let id = UUID()
    let routine: RoutineTemplate?
}

#Preview {
    NavigationStack {
        HomeRootView()
    }
    .environment(AppState())
    .modelContainer(PersistenceController.previewContainer)
}
