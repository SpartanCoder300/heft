// iOS 26+ only. No #available guards.

import SwiftUI
import SwiftData

struct WorkoutDetailView: View {
    let session: WorkoutSession
    @Environment(\.ryftTheme) private var theme
    @State private var historyExerciseName: String? = nil

    private var sortedExercises: [ExerciseSnapshot] {
        session.exercises.sorted { $0.order < $1.order }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {

                // ── Stat chips ─────────────────────────────────────────
                HStack(spacing: Spacing.sm) {
                    DetailStatChip(label: "Duration", value: durationLabel ?? "—")
                    DetailStatChip(label: "Volume",   value: volumeLabel)
                    DetailStatChip(label: "Sets",     value: "\(totalSets)")
                }

                // ── Exercises ──────────────────────────────────────────
                VStack(spacing: Spacing.sm) {
                    ForEach(sortedExercises) { snapshot in
                        ExerciseDetailCard(snapshot: snapshot, onNameTap: {
                            historyExerciseName = snapshot.exerciseName
                        })
                    }
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.lg)
        }
        .themedBackground()
        .navigationTitle(navTitle)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: Binding(
            get: { historyExerciseName != nil },
            set: { if !$0 { historyExerciseName = nil } }
        )) {
            if let name = historyExerciseName {
                ExerciseHistoryView(exerciseName: name)
                    .environment(\.ryftCardMaterial, .regularMaterial)
            }
        }
    }

    // MARK: - Computed

    private var navTitle: String {
        guard let date = session.completedAt else { return "Workout" }
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        let sameYear = cal.component(.year, from: date) == cal.component(.year, from: .now)
        return sameYear
            ? date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
            : date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().year())
    }

    private var durationLabel: String? {
        guard let start = session.startedAt, let end = session.completedAt else { return nil }
        let total = Int(end.timeIntervalSince(start) / 60)
        if total < 60 { return "\(total) min" }
        return "\(total / 60)h \(total % 60)m"
    }

    private var totalSets: Int {
        session.exercises.reduce(0) { $0 + $1.sets.count }
    }

    private var totalVolume: Double {
        session.exercises.flatMap { $0.sets }.reduce(0) { $0 + $1.weight * Double($1.reps) }
    }

    private var volumeLabel: String {
        let v = totalVolume
        if v >= 1_000 { return String(format: "%.1fk lbs", v / 1_000) }
        return "\(Int(v)) lbs"
    }
}

// MARK: - Preview

#Preview {
    return NavigationStack {
        WorkoutDetailView(session: HistoryRootPreviewData.detailPreviewSession)
    }
    .environment(AppState())
    .environment(MeshEngine())
    .modelContainer(HistoryRootPreviewData.populatedContainer)
}
