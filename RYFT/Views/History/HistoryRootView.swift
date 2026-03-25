// iOS 26+ only. No #available guards.

import SwiftUI
import SwiftData

struct HistoryRootView: View {
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
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(sessionTitle(session))
                                            .font(.headline)
                                            .foregroundStyle(.primary)
                                        Text(sessionSubtitle(session))
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.vertical, 6)
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .navigationDestination(for: WorkoutSession.self) { session in
                    WorkoutDetailView(session: session)
                }
            }
        }
        .navigationTitle("History")
        .themedBackground()
    }

    // MARK: - Helpers

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
        // Ad-hoc workout — fall back to day name
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
        } else {
            parts.append(date.formatted(.dateTime.weekday(.abbreviated)))
        }
        if let s = session.startedAt, let e = session.completedAt {
            parts.append("\(Int(e.timeIntervalSince(s) / 60)) min")
        }
        let sets = session.exercises.reduce(0) { $0 + $1.sets.count }
        parts.append("\(sets) sets")
        return parts.joined(separator: " · ")
    }
}

// MARK: - Empty State

private struct HistoryEmptyState: View {
    @Environment(\.ryftTheme) private var theme

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
    .environment(MeshEngine())
    .modelContainer(HistoryRootPreviewData.emptyContainer)
}

#Preview("With History") {
    NavigationStack {
        HistoryRootView()
    }
    .environment(AppState())
    .environment(MeshEngine())
    .modelContainer(HistoryRootPreviewData.populatedContainer)
}
