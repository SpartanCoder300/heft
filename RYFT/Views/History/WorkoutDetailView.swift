// iOS 26+ only. No #available guards.

import SwiftUI
import SwiftData

struct WorkoutDetailView: View {
    let session: WorkoutSession
    var routineName: String? = nil
    @Environment(\.ryftTheme) private var theme
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var historyTarget: (name: String, lineageID: UUID?)? = nil
    @State private var showDeleteAlert = false

    private var sortedExercises: [ExerciseSnapshot] {
        session.exercises.sorted { $0.order < $1.order }
    }

    private var prCount: Int {
        session.exercises.flatMap { $0.sets }.filter { $0.isPersonalRecord }.count
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

                // ── PR banner ──────────────────────────────────────────
                if prCount > 0 {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "trophy.fill")
                            .font(.caption.weight(.semibold))
                        Text(prCount == 1 ? "1 Personal Record" : "\(prCount) Personal Records")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(Color.ryftAmber)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.sm + 2)
                    .background(Color.ryftAmber.opacity(0.12),
                                in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
                }

                // ── Exercises ──────────────────────────────────────────
                VStack(spacing: Spacing.sm) {
                    ForEach(sortedExercises) { snapshot in
                        ExerciseDetailCard(snapshot: snapshot, onNameTap: { snapshot in
                            historyTarget = (snapshot.exerciseName, snapshot.exerciseLineageID)
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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    showDeleteAlert = true
                } label: {
                    Image(systemName: "trash")
                }
                .tint(.red)
            }
        }
        .alert("Delete Workout?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                modelContext.delete(session)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This workout and all its data will be permanently removed.")
        }
        .sheet(isPresented: Binding(
            get: { historyTarget != nil },
            set: { if !$0 { historyTarget = nil } }
        )) {
            if let target = historyTarget {
                ExerciseHistoryView(exerciseName: target.name, exerciseLineageID: target.lineageID)
                    .environment(\.ryftCardMaterial, .regularMaterial)
            }
        }
    }

    // MARK: - Computed

    private var navTitle: String {
        if let name = routineName { return name }
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
        if total < 1 { return "< 1 min" }
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
