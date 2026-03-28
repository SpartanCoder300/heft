// iOS 26+ only. No #available guards.

import SwiftUI
import SwiftData

struct WorkoutSummaryView: View {
    let onDone: () -> Void

    @State private var vm: WorkoutSummaryViewModel
    @State private var appeared = false
    @State private var historyExerciseName: String? = nil
    @Environment(\.ryftCardMaterial) private var cardMaterial

    init(session: WorkoutSession, onDone: @escaping () -> Void) {
        _vm = State(initialValue: WorkoutSummaryViewModel(session: session))
        self.onDone = onDone
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {

                // ── Hero header ────────────────────────────────────────
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Done.")
                        .font(.system(size: 52, weight: .bold))
                        .foregroundStyle(.primary)
                    Text(vm.dateLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, Spacing.lg)
                .scaleEffect(appeared ? 1.0 : 0.85, anchor: .leading)
                .opacity(appeared ? 1.0 : 0.0)
                .animation(.spring(response: 0.35, dampingFraction: 0.7), value: appeared)

                // ── Stat chips ─────────────────────────────────────────
                HStack(spacing: Spacing.sm) {
                    SummaryStatChip(value: vm.durationLabel, label: "Duration")
                    SummaryStatChip(value: "\(vm.totalSets)", label: "Sets")
                    SummaryStatChip(value: vm.totalVolumeLabel, label: "Volume")
                }
                .offset(y: appeared ? 0 : 18)
                .opacity(appeared ? 1.0 : 0.0)
                .animation(.spring(response: 0.4, dampingFraction: 0.75).delay(0.08), value: appeared)

                // ── Exercise cards ─────────────────────────────────────
                if !vm.exerciseRows.isEmpty {
                    VStack(spacing: Spacing.sm) {
                        ForEach(Array(vm.exerciseRows.enumerated()), id: \.element.id) { index, row in
                            SummaryExerciseCard(
                                row: row,
                                formatWeight: vm.formatWeight,
                                cardIndex: index,
                                onNameTap: { historyExerciseName = row.name }
                            )
                                .offset(y: appeared ? 0 : 18)
                                .opacity(appeared ? 1.0 : 0.0)
                                .animation(
                                    .spring(response: 0.4, dampingFraction: 0.75)
                                    .delay(0.16 + Double(index) * 0.06),
                                    value: appeared
                                )
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.bottom, Spacing.xl)
        }
        .safeAreaInset(edge: .bottom) {
            Button(action: onDone) {
                Text("Done")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
                    .proGlass(cornerRadius: Radius.large)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.bottom, Spacing.md)
        }
        .themedBackground()
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { appeared = true }
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

    let snap2 = ExerciseSnapshot(exerciseName: "Arnold Press", order: 1, workoutSession: session)
    context.insert(snap2)
    session.exercises.append(snap2)
    let s5 = SetRecord(weight: 65, reps: 10, setType: .normal, exerciseSnapshot: snap2)
    let s6 = SetRecord(weight: 65, reps: 10, setType: .normal, exerciseSnapshot: snap2)
    let s7 = SetRecord(weight: 65, reps: 9,  setType: .normal, exerciseSnapshot: snap2)
    context.insert(s5); context.insert(s6); context.insert(s7)
    snap2.sets = [s5, s6, s7]

    return NavigationStack {
        WorkoutSummaryView(session: session, onDone: {})
    }
    .environment(AppState())
    .environment(MeshEngine())
    .modelContainer(container)
}
