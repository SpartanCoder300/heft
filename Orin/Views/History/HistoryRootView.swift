// iOS 26+ only. No #available guards.

import SwiftUI
import SwiftData

struct HistoryRootView: View {
    @Environment(\.OrinCardMaterial) private var cardMaterial
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \WorkoutSession.completedAt, order: .reverse)
    private var allSessions: [WorkoutSession]

    @Query private var routineTemplates: [RoutineTemplate]

    private var completed: [WorkoutSession] {
        allSessions.filter { $0.completedAt != nil }
    }

    private var routineNameMap: [UUID: String] {
        Dictionary(uniqueKeysWithValues: routineTemplates.map { ($0.id, $0.name) })
    }

    private var grouped: [(section: String, sessions: [WorkoutSession])] {
        var order: [String] = []
        var map: [String: [WorkoutSession]] = [:]
        for session in completed {
            let key = sectionKey(for: session.completedAt!)
            if map[key] == nil { order.append(key) }
            map[key, default: []].append(session)
        }
        return order.map { (section: $0, sessions: map[$0]!) }
    }

    var body: some View {
        Group {
            if completed.isEmpty {
                HistoryEmptyState()
            } else {
                List {
                    ForEach(grouped, id: \.section) { group in
                        Section(group.section) {
                            ForEach(group.sessions) { session in
                                NavigationLink(value: session) {
                                    VStack(alignment: .leading, spacing: 3) {
                                        HStack(spacing: Spacing.xs) {
                                            Text(sessionTitle(session))
                                                .font(.headline)
                                                .foregroundStyle(.primary)
                                            if sessionHasPR(session) {
                                                Text("PR")
                                                    .font(.caption2.weight(.bold))
                                                    .foregroundStyle(Color.OrinAmber)
                                                    .padding(.horizontal, 5)
                                                    .padding(.vertical, 2)
                                                    .background(Color.OrinAmber.opacity(0.15), in: Capsule())
                                            }
                                        }
                                        Text(sessionSubtitle(session))
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                        if let exercises = exerciseSummary(session) {
                                            Text(exercises)
                                                .font(.caption)
                                                .foregroundStyle(.tertiary)
                                                .lineLimit(1)
                                        }
                                    }
                                    .padding(.vertical, 6)
                                }
                                .listRowBackground(Rectangle().fill(cardMaterial))
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        let id = session.persistentModelID
                                        let container = modelContext.container
                                        Task.detached {
                                            await SessionService(modelContainer: container).deleteSession(id)
                                        }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .navigationDestination(for: WorkoutSession.self) { session in
                    WorkoutDetailView(
                        session: session,
                        routineName: session.routineTemplateId.flatMap { routineNameMap[$0] }
                    )
                }
            }
        }
        .navigationTitle("Progress")
        .themedBackground()
    }

    // MARK: - Helpers

    private func sessionHasPR(_ session: WorkoutSession) -> Bool {
        session.exercises.flatMap { $0.sets }.contains { $0.isPersonalRecord }
    }

    private func exerciseSummary(_ session: WorkoutSession) -> String? {
        let names = session.exercises
            .sorted { $0.order < $1.order }
            .prefix(3)
            .map { $0.exerciseName }
        return names.isEmpty ? nil : names.joined(separator: " · ")
    }

    private func sectionKey(for date: Date) -> String {
        let cal = Calendar.current
        if cal.isDate(date, equalTo: .now, toGranularity: .weekOfYear) { return "This Week" }
        if let lastWeek = cal.date(byAdding: .weekOfYear, value: -1, to: .now),
           cal.isDate(date, equalTo: lastWeek, toGranularity: .weekOfYear) { return "Last Week" }
        return date.formatted(.dateTime.month(.wide).year())
    }

    private func sessionTitle(_ session: WorkoutSession) -> String {
        if let rid = session.routineTemplateId,
           let name = routineNameMap[rid] { return name }
        let date = session.completedAt!
        if Calendar.current.isDateInToday(date) { return "Open Workout" }
        return date.formatted(.dateTime.weekday(.wide))
    }

    private func sessionSubtitle(_ session: WorkoutSession) -> String {
        let date = session.completedAt!
        let cal = Calendar.current
        var parts: [String] = []
        if cal.isDateInYesterday(date) {
            parts.append("Yesterday")
        } else if !cal.isDateInToday(date) {
            parts.append(date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
        }
        if let s = session.startedAt, let e = session.completedAt {
            let minutes = Int(e.timeIntervalSince(s) / 60)
            parts.append(minutes < 1 ? "< 1 min" : "\(minutes) min")
        }
        let sets = session.exercises.reduce(0) { $0 + $1.sets.count }
        parts.append("\(sets) sets")
        return parts.joined(separator: " · ")
    }
}

// MARK: - Empty State

private struct HistoryEmptyState: View {
    @Environment(\.OrinTheme) private var theme

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(theme.accentColor.opacity(0.6))
            VStack(spacing: 4) {
                Text("No workouts yet")
                    .font(.headline)
                Text("Start your first one.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview("Empty") {
    NavigationStack {
        HistoryRootView()
    }
    .environment(AppState())
    .modelContainer(HistoryRootPreviewData.emptyContainer)
}

#Preview("With History") {
    NavigationStack {
        HistoryRootView()
    }
    .environment(AppState())
    .modelContainer(HistoryRootPreviewData.populatedContainer)
}
