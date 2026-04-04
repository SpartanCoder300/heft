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

    private var currentSessionNumber: Int {
        guard let rid = appState.workout.viewModel?.session?.routineTemplateId else { return 0 }
        return sessions.filter { $0.routineTemplateId == rid && $0.completedAt != nil }.count + 1
    }

    /// Returns the featured suggestion to show. Falls back to the first available
    /// routine (e.g. a starter) when the stats algorithm hasn't enough history yet.
    private var effectiveFeatured: FeaturedRoutineSuggestion? {
        if let f = stats.featuredRoutine { return f }
        guard let first = sortedRoutines.first else { return nil }
        return FeaturedRoutineSuggestion(
            routineID: first.id,
            routineName: first.name,
            exerciseCount: first.entries.count,
            daysSinceLast: 0,
            avgIntervalDays: 1
        )
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
                if appState.workout.hasActiveWorkout, let vm = appState.workout.viewModel {
                    HomeActiveWorkoutDashboard(vm: vm, sessionNumber: currentSessionNumber) {
                        appState.workout.isShowingFullWorkout = true
                    }
                    HomePreviousBestsCard(vm: vm)
                } else {
                    HomeGreetingView()

                    // Dominant featured card — sits above stats so it's the first decision
                    if let featured = effectiveFeatured,
                       let featuredRoutine = sortedRoutines.first(where: { $0.id == featured.routineID }) {
                        FeaturedRoutineCard(
                            routine: featuredRoutine,
                            suggestion: featured,
                            avgMinutes: routineAvgMinutes[featured.routineID],
                            onTap: {
                                appState.workout.startWorkout(routineID: featured.routineID, modelContext: modelContext)
                            },
                            onEdit: {
                                routineBuilderRequest = RoutineBuilderRequest(routine: featuredRoutine)
                            }
                        )
                    }

                    // Stats recede — they're context, not the primary action
                    HomeStatChipsRow(stats: stats)
                        .opacity(0.58)

                    HomeRoutinesSection(
                        routines: sortedRoutines,
                        avgMinutes: routineAvgMinutes,
                        featured: effectiveFeatured,
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
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.lg)
            .animation(.easeInOut(duration: 0.35), value: appState.workout.hasActiveWorkout)
        }
        .themedBackground()
        .toolbar(appState.workout.hasActiveWorkout ? .hidden : .visible, for: .navigationBar)
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

#Preview("Active Workout") {
    let container = HomePreviewData.featuredRootContainer
    let appState = HomeRootPreviewFactory.makeActiveWorkoutAppState(container: container)
    return NavigationStack {
        HomeRootView()
    }
    .environment(appState)
    .modelContainer(container)
    .preferredColorScheme(.dark)
}

#Preview("Featured") {
    NavigationStack {
        HomeRootView()
    }
    .environment(AppState())
    .modelContainer(HomePreviewData.featuredRootContainer)
    .preferredColorScheme(.dark)
}

#Preview("No Featured") {
    NavigationStack {
        HomeRootView()
    }
    .environment(AppState())
    .modelContainer(HomePreviewData.routinesOnlyRootContainer)
    .preferredColorScheme(.dark)
}

#Preview("No Routines") {
    NavigationStack {
        HomeRootView()
    }
    .environment(AppState())
    .modelContainer(HomePreviewData.emptyRootContainer)
    .preferredColorScheme(.dark)
}

private enum HomeRootPreviewFactory {
    static func makeActiveWorkoutAppState(container: ModelContainer) -> AppState {
        let appState = AppState()
        appState.workout.startWorkout(routineID: nil, modelContext: container.mainContext)
        if let vm = appState.workout.viewModel {
            vm.addExercise(named: "Bench Press")
            vm.addExercise(named: "Squat")
            vm.addExercise(named: "Romanian Deadlift")
            vm.addSet(toExerciseAt: 0)
            vm.addSet(toExerciseAt: 0)
            vm.draftExercises[0].sets[0].isLogged = true
            vm.draftExercises[0].sets[1].isLogged = true
            vm.draftExercises[1].sets[0].isLogged = true
        }
        return appState
    }
}
