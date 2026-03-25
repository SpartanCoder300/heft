// iOS 26+ only. No #available guards.

import SwiftUI
import SwiftData

struct WorkoutDetailView: View {
    let session: WorkoutSession
    @Environment(\.ryftTheme) private var theme

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
                        ExerciseDetailCard(snapshot: snapshot)
                    }
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.lg)
        }
        .themedBackground()
        .navigationTitle(navTitle)
        .navigationBarTitleDisplayMode(.inline)
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

// MARK: - Stat Chip

private struct DetailStatChip: View {
    let label: String
    let value: String
    @Environment(\.ryftCardMaterial) private var cardMaterial

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
                .lineLimit(1)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardMaterial, in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
        .proGlass()
    }
}

// MARK: - Exercise Detail Card

private struct ExerciseDetailCard: View {
    let snapshot: ExerciseSnapshot
    @Environment(\.ryftTheme) private var theme
    @Environment(\.ryftCardMaterial) private var cardMaterial

    private var sortedSets: [SetRecord] {
        snapshot.sets.sorted { $0.loggedAt < $1.loggedAt }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Header ─────────────────────────────────────────────────
            HStack(alignment: .firstTextBaseline) {
                Text(snapshot.exerciseName)
                    .font(.headline)
                    .foregroundStyle(.primary)
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

    /// "185 lbs × 5" — heaviest working set, excluding warmups.
    private var bestSetLabel: String? {
        let working = sortedSets.filter { $0.setType != .warmup && $0.weight > 0 }
        guard let top = working.max(by: { $0.weight < $1.weight }) else { return nil }
        let w = top.weight.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(top.weight))" : String(format: "%.1f", top.weight)
        return "\(w) lbs × \(top.reps)"
    }
}

// MARK: - Set Detail Row

private struct SetDetailRow: View {
    let setNumber: Int
    let record: SetRecord

    var body: some View {
        HStack(spacing: Spacing.sm) {

            // Set number
            Text("\(setNumber)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.tertiary)
                .frame(width: 24, alignment: .center)

            // Non-normal type badge
            if record.setType != .normal {
                SetTypeLabel(setType: record.setType)
            }

            Spacer()

            // Weight × Reps
            HStack(spacing: 6) {
                if record.weight > 0 {
                    HStack(spacing: 2) {
                        Text(formattedWeight)
                            .foregroundStyle(record.isPersonalRecord ? Color.ryftAmber : Color.primary)
                        Text("lbs")
                            .foregroundStyle(.secondary)
                    }
                    .font(.body.monospacedDigit().weight(.medium))
                } else {
                    Text("Bodyweight")
                        .font(.body.monospacedDigit().weight(.medium))
                        .foregroundStyle(.secondary)
                }

                Text("×")
                    .font(.body)
                    .foregroundStyle(.tertiary)

                Text("\(record.reps)")
                    .font(.body.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.primary)
            }

            // PR badge + e1RM
            if record.isPersonalRecord {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("PR")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.ryftAmber)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.ryftAmber.opacity(0.15), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                    let e1rm = ExerciseDefinition.estimatedOneRepMax(weight: record.weight, reps: record.reps)
                    if e1rm > 0 {
                        Text("~\(formattedE1RM(e1rm)) e1RM")
                            .font(.caption)
                            .foregroundStyle(Color.ryftAmber.opacity(0.6))
                    }
                }
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, 11)
        .background(
            record.isPersonalRecord
                ? Rectangle().fill(Color.ryftAmber.opacity(0.05)) // Forces 90-degree corners
                : Rectangle().fill(.clear)
        )
    }

    private var formattedWeight: String {
        let w = record.weight
        return w.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(w))" : String(format: "%.1f", w)
    }

    private func formattedE1RM(_ v: Double) -> String {
        let rounded = v.rounded()
        return "\(Int(rounded))"
    }
}

// MARK: - Set Type Label

private struct SetTypeLabel: View {
    let setType: SetType

    var body: some View {
        Text(label)
            .font(.caption2.weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
    }

    private var label: String {
        switch setType {
        case .warmup:  "W"
        case .dropset: "D"
        case .normal:  ""
        }
    }

    private var color: Color {
        switch setType {
        case .warmup:  Color.ryftAmber
        case .dropset: Color.blue
        case .normal:  Color.textFaint
        }
    }
}

// MARK: - Preview

#Preview {
    let container = PersistenceController.previewContainer
    let context = container.mainContext

    let session = WorkoutSession(startedAt: Date().addingTimeInterval(-2700), completedAt: .now)
    context.insert(session)

    let snap1 = ExerciseSnapshot(exerciseName: "Barbell Bench Press", order: 0, workoutSession: session)
    context.insert(snap1)
    session.exercises.append(snap1)
    let s1 = SetRecord(weight: 135, reps: 8, setType: .warmup, exerciseSnapshot: snap1)
    let s2 = SetRecord(weight: 185, reps: 5, setType: .normal, isPersonalRecord: true, exerciseSnapshot: snap1)
    let s3 = SetRecord(weight: 185, reps: 5, setType: .normal, exerciseSnapshot: snap1)
    let s4 = SetRecord(weight: 185, reps: 4, setType: .normal, exerciseSnapshot: snap1)
    context.insert(s1); context.insert(s2); context.insert(s3); context.insert(s4)
    snap1.sets = [s1, s2, s3, s4]

    let snap2 = ExerciseSnapshot(exerciseName: "Barbell Back Squat", order: 1, workoutSession: session)
    context.insert(snap2)
    session.exercises.append(snap2)
    let s5 = SetRecord(weight: 225, reps: 5, setType: .normal, exerciseSnapshot: snap2)
    let s6 = SetRecord(weight: 225, reps: 5, setType: .normal, exerciseSnapshot: snap2)
    let s7 = SetRecord(weight: 225, reps: 4, setType: .normal, exerciseSnapshot: snap2)
    context.insert(s5); context.insert(s6); context.insert(s7)
    snap2.sets = [s5, s6, s7]

    return NavigationStack {
        WorkoutDetailView(session: session)
    }
    .environment(AppState())
    .modelContainer(container)
}
