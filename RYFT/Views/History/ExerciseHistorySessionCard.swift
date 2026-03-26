// iOS 26+ only. No #available guards.

import SwiftUI
import SwiftData

struct ExerciseHistorySessionCard: View {
    let snapshot: ExerciseSnapshot
    @Environment(\.ryftCardMaterial) private var cardMaterial

    private var sortedSets: [SetRecord] {
        snapshot.sets.sorted { $0.loggedAt < $1.loggedAt }
    }

    private var hasPR: Bool {
        sortedSets.contains { $0.isPersonalRecord }
    }

    private var dateLabel: String {
        guard let date = snapshot.workoutSession?.completedAt else { return "Unknown Date" }
        let cal = Calendar.current
        if cal.isDateInToday(date)     { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        let sameYear = cal.component(.year, from: date) == cal.component(.year, from: .now)
        return sameYear
            ? date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
            : date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().year())
    }

    private var bestSetLabel: String? {
        let working = sortedSets.filter { $0.setType != .warmup && $0.weight > 0 }
        guard let top = working.max(by: { $0.weight < $1.weight }) else { return nil }
        let w = top.weight.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(top.weight))" : String(format: "%.1f", top.weight)
        return "\(w) lbs × \(top.reps)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Header ─────────────────────────────────────────────────
            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: Spacing.xs) {
                    Text(dateLabel)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    if hasPR {
                        Text("PR")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Color.ryftAmber)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.ryftAmber.opacity(0.15), in: Capsule())
                    }
                }
                Spacer(minLength: Spacing.sm)
                if let best = bestSetLabel {
                    Text(best)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm + 2)

            Divider().opacity(0.3)

            // ── Set rows ───────────────────────────────────────────────
            ForEach(Array(sortedSets.enumerated()), id: \.element.id) { idx, record in
                SetDetailRow(setNumber: idx + 1, record: record)
                if idx < sortedSets.count - 1 {
                    Divider()
                        .opacity(0.15)
                        .padding(.leading, Spacing.md)
                }
            }
        }
        .background(cardMaterial, in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
        .proGlass()
    }
}

// MARK: - Preview

#Preview {
    {
        let snapshot = HistoryRootPreviewData.exerciseHistorySnapshots.first!
        return ExerciseHistorySessionCard(snapshot: snapshot)
            .padding()
            .environment(\.ryftCardMaterial, .regularMaterial)
            .modelContainer(HistoryRootPreviewData.exerciseHistoryContainer)
            .preferredColorScheme(.dark)
    }()
}
