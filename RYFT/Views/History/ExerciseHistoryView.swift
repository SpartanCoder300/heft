// iOS 26+ only. No #available guards.

import SwiftUI
import SwiftData

struct ExerciseHistoryView: View {
    let exerciseName: String
    let exerciseLineageID: UUID?

    @Query private var snapshots: [ExerciseSnapshot]
    @Environment(\.dismiss) private var dismiss

    /// Cached all-time best set — computed once on appear and when session count changes,
    /// not on every render. Prevents faulting all SetRecord objects each frame.
    @State private var cachedBest: SetRecord? = nil
    /// How many session cards to show. Expanded by the "Show more" button.
    @State private var displayLimit: Int = 50

    init(exerciseName: String, exerciseLineageID: UUID? = nil) {
        self.exerciseName = exerciseName
        self.exerciseLineageID = exerciseLineageID
        if let lineageID = exerciseLineageID {
            let name = exerciseName
            _snapshots = Query(filter: #Predicate<ExerciseSnapshot> {
                $0.exerciseLineageID == lineageID || ($0.exerciseLineageID == nil && $0.exerciseName == name)
            })
        } else {
            let name = exerciseName
            _snapshots = Query(filter: #Predicate<ExerciseSnapshot> { $0.exerciseName == name })
        }
    }

    // Sorted newest-first; only completed sessions.
    // Sort runs in-memory — SwiftData can't sort by relationship keypath in @Query.
    private var sessions: [ExerciseSnapshot] {
        snapshots
            .filter { $0.workoutSession?.completedAt != nil }
            .sorted { $0.workoutSession!.completedAt! > $1.workoutSession!.completedAt! }
    }

    private var allTimeBestE1RM: Double {
        guard let best = cachedBest else { return 0 }
        return ExerciseDefinition.estimatedOneRepMax(weight: best.weight, reps: best.reps)
    }

    private var bestDate: Date? {
        cachedBest?.exerciseSnapshot?.workoutSession?.completedAt
    }

    private func recomputeBest() {
        cachedBest = sessions
            .flatMap { $0.sets }
            .filter { $0.setType != .warmup && $0.weight > 0 && $0.reps > 0 }
            .max(by: {
                ExerciseDefinition.estimatedOneRepMax(weight: $0.weight, reps: $0.reps) <
                ExerciseDefinition.estimatedOneRepMax(weight: $1.weight, reps: $1.reps)
            })
    }

    private func e1rmForSnapshot(_ snapshot: ExerciseSnapshot) -> Double? {
        let working = snapshot.sets.filter { $0.setType != .warmup && $0.weight > 0 && $0.reps > 0 }
        guard let top = working.max(by: {
            ExerciseDefinition.estimatedOneRepMax(weight: $0.weight, reps: $0.reps) <
            ExerciseDefinition.estimatedOneRepMax(weight: $1.weight, reps: $1.reps)
        }) else { return nil }
        let e1rm = ExerciseDefinition.estimatedOneRepMax(weight: top.weight, reps: top.reps)
        return e1rm > 0 ? e1rm : nil
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    header
                        .padding(.horizontal, Spacing.md)

                    if sessions.isEmpty {
                        emptyState
                    } else {
                        // ── Stats + chart ───────────────────────────────
                        VStack(alignment: .leading, spacing: Spacing.md) {
                            if cachedBest != nil {
                                bestBanner()
                            }
                            if sessions.count >= 2 {
                                ExerciseHistoryChart(snapshots: sessions)
                            }
                        }
                        .padding(.horizontal, Spacing.md)

                        // ── Session cards (capped for performance) ──────
                        let displayed = Array(sessions.prefix(displayLimit))
                        LazyVStack(spacing: Spacing.sm) {
                            ForEach(Array(displayed.enumerated()), id: \.element.id) { index, snapshot in
                                ExerciseHistorySessionCard(
                                    snapshot: snapshot,
                                    previousE1RM: index + 1 < displayed.count
                                        ? e1rmForSnapshot(displayed[index + 1]) : nil
                                )
                            }
                            if sessions.count > displayLimit {
                                Button {
                                    displayLimit += 50
                                } label: {
                                    Text("Show \(min(50, sessions.count - displayLimit)) more")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.secondary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, Spacing.sm)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, Spacing.md)
                    }
                }
                .padding(.vertical, Spacing.lg)
            }
            .themedBackground()
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .task { recomputeBest() }
            .onChange(of: snapshots.count) { recomputeBest() }
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
    private var header: some View {
        Text(exerciseName)
            .font(.title.weight(.bold))
            .foregroundStyle(.primary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private func bestBanner() -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("All-Time Best")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.tertiary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(formattedE1RM(allTimeBestE1RM))
                        .font(.title2.weight(.bold).monospacedDigit())
                    Text("BEST")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.15), in: Capsule())
                }
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
        .proGlass(specular: false)
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

    private func formattedE1RM(_ value: Double) -> String {
        let v = value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value))" : String(format: "%.1f", value)
        return "\(v) lbs e1RM"
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
