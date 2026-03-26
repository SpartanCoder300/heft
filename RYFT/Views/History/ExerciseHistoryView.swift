// iOS 26+ only. No #available guards.

import SwiftUI
import SwiftData

struct ExerciseHistoryView: View {
    let exerciseName: String

    @Query private var snapshots: [ExerciseSnapshot]
    @Environment(\.dismiss) private var dismiss

    init(exerciseName: String) {
        self.exerciseName = exerciseName
        let name = exerciseName
        _snapshots = Query(filter: #Predicate<ExerciseSnapshot> { $0.exerciseName == name })
    }

    // Sorted newest-first; only sessions that are completed
    private var sessions: [ExerciseSnapshot] {
        snapshots
            .filter { $0.workoutSession?.completedAt != nil }
            .sorted { $0.workoutSession!.completedAt! > $1.workoutSession!.completedAt! }
    }

    private var allTimeBest: SetRecord? {
        sessions
            .flatMap { $0.sets }
            .filter { $0.setType != .warmup && $0.weight > 0 }
            .max(by: { $0.weight < $1.weight })
    }

    private var bestDate: Date? {
        allTimeBest?.exerciseSnapshot?.workoutSession?.completedAt
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    if sessions.isEmpty {
                        emptyState
                    } else {
                        // ── Stats + chart ───────────────────────────────
                        VStack(alignment: .leading, spacing: Spacing.md) {
                            if let best = allTimeBest {
                                bestBanner(best)
                            }
                            if sessions.count >= 2 {
                                ExerciseHistoryChart(snapshots: sessions)
                            }
                        }
                        .padding(.horizontal, Spacing.md)

                        // ── Session cards ───────────────────────────────
                        VStack(spacing: Spacing.sm) {
                            ForEach(sessions) { snapshot in
                                ExerciseHistorySessionCard(snapshot: snapshot)
                            }
                        }
                        .padding(.horizontal, Spacing.md)
                    }
                }
                .padding(.vertical, Spacing.lg)
            }
            .themedBackground()
            .navigationTitle(exerciseName)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func bestBanner(_ record: SetRecord) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("All-Time Best")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.tertiary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                Text(formattedRecord(record))
                    .font(.title2.weight(.bold).monospacedDigit())
                    .foregroundStyle(Color.ryftAmber)
            }
            Spacer()
            if let date = bestDate {
                Text(date.formatted(.dateTime.month(.abbreviated).day().year()))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 44))
                .foregroundStyle(.tertiary)
            Text("No history yet")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Complete a workout with \(exerciseName) to see your progress here.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
        .padding(.horizontal, Spacing.xl)
    }

    // MARK: - Helpers

    private func formattedRecord(_ record: SetRecord) -> String {
        let w = record.weight.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(record.weight))" : String(format: "%.1f", record.weight)
        return "\(w) lbs × \(record.reps)"
    }
}

// MARK: - Preview

#Preview("With history") {
    ExerciseHistoryView(exerciseName: "Bench Press")
        .modelContainer(HistoryRootPreviewData.exerciseHistoryContainer)
        .environment(\.ryftCardMaterial, .regularMaterial)
        .preferredColorScheme(.dark)
}

#Preview("Empty") {
    ExerciseHistoryView(exerciseName: "Deadlift")
        .modelContainer(HistoryRootPreviewData.exerciseHistoryContainer)
        .environment(\.ryftCardMaterial, .regularMaterial)
        .preferredColorScheme(.dark)
}
