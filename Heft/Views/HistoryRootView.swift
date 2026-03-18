// iOS 26+ only. No #available guards.

import SwiftUI
import SwiftData

struct HistoryRootView: View {
    @Query(sort: \WorkoutSession.completedAt, order: .reverse)
    private var allSessions: [WorkoutSession]

    @Query private var routineTemplates: [RoutineTemplate]

    @Environment(\.heftTheme) private var theme

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
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0, pinnedViews: .sectionHeaders) {
                        ForEach(grouped, id: \.section) { group in
                            Section {
                                VStack(spacing: 10) {
                                    ForEach(group.sessions) { session in
                                        NavigationLink(value: session) {
                                            if group.section == "This Week" {
                                                ExpandedSessionCard(
                                                    session: session,
                                                    title: sessionTitle(session),
                                                    accentColor: theme.accentColor
                                                )
                                            } else {
                                                CompactSessionCard(
                                                    session: session,
                                                    title: sessionTitle(session)
                                                )
                                            }
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.bottom, 28)
                            } header: {
                                Text(group.section)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .textCase(.uppercase)
                                    .tracking(1)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 16)
                                    .padding(.top, 20)
                                    .padding(.bottom, 10)
                            }
                        }
                    }
                }
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
}

// MARK: - Expanded Card (This Week)

private struct ExpandedSessionCard: View {
    let session: WorkoutSession
    let title: String
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Header ─────────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(timestampLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Inline stats
                HStack(spacing: 4) {
                    if let d = durationLabel {
                        Text(d)
                        statDot
                    }
                    Text("\(totalSets) sets")
                    statDot
                    Text(volumeLabel)
                    if prCount > 0 {
                        statDot
                        Text("\(prCount) PR 🏆")
                            .foregroundStyle(Color.heftAmber)
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 14)

            // ── Divider ────────────────────────────────────────────────
            if !exerciseNames.isEmpty {
                Divider().opacity(0.3)

                // Exercise pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(visibleNames.enumerated()), id: \.offset) { idx, name in
                            ExercisePill(name: name, isFirst: idx == 0, accentColor: accentColor)
                        }
                        if overflow > 0 {
                            ExercisePill(name: "+\(overflow) more", isFirst: false, accentColor: accentColor)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.vertical, 12)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var statDot: some View {
        Text("·").foregroundStyle(.tertiary)
    }

    private var timestampLabel: String {
        let date = session.completedAt!
        let cal = Calendar.current
        let time = date.formatted(.dateTime.hour().minute())
        if cal.isDateInToday(date) { return "Today · \(time)" }
        if cal.isDateInYesterday(date) { return "Yesterday · \(time)" }
        return date.formatted(.dateTime.weekday(.abbreviated)) + " · " + time
    }

    private var durationLabel: String? {
        guard let s = session.startedAt, let e = session.completedAt else { return nil }
        return "\(Int(e.timeIntervalSince(s) / 60)) min"
    }

    private var totalSets: Int {
        session.exercises.reduce(0) { $0 + $1.sets.count }
    }

    private var totalVolume: Double {
        session.exercises.flatMap { $0.sets }.reduce(0) { $0 + $1.weight * Double($1.reps) }
    }

    private var volumeLabel: String {
        let v = totalVolume
        return v >= 1_000
            ? String(format: "%.1fk lbs vol", v / 1_000)
            : "\(Int(v)) lbs vol"
    }

    private var prCount: Int {
        session.exercises.flatMap { $0.sets }.filter { $0.isPersonalRecord }.count
    }

    private var exerciseNames: [String] {
        session.exercises.sorted { $0.order < $1.order }.map { $0.exerciseName }
    }

    private var visibleNames: [String] { Array(exerciseNames.prefix(3)) }
    private var overflow: Int { max(0, exerciseNames.count - 3) }
}

// MARK: - Compact Card (Last Week + older)

private struct CompactSessionCard: View {
    let session: WorkoutSession
    let title: String

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var subtitle: String {
        var parts: [String] = []
        let date = session.completedAt!
        let cal = Calendar.current
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

// MARK: - Exercise Pill

private struct ExercisePill: View {
    let name: String
    let isFirst: Bool
    let accentColor: Color

    var body: some View {
        Text(name)
            .font(.caption.weight(.medium))
            .foregroundStyle(isFirst ? accentColor : Color.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                isFirst ? accentColor.opacity(0.15) : Color.primary.opacity(0.08),
                in: Capsule()
            )
    }
}

// MARK: - Empty State

private struct HistoryEmptyState: View {
    @Environment(\.heftTheme) private var theme

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

#Preview {
    NavigationStack {
        HistoryRootView()
    }
    .environment(AppState())
    .modelContainer(PersistenceController.previewContainer)
}
