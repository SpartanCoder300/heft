// iOS 26+ only. No #available guards.

import SwiftUI
import SwiftData

struct WorkoutSummaryView: View {
    let onDone: () -> Void

    @State private var vm: WorkoutSummaryViewModel

    init(session: WorkoutSession, onDone: @escaping () -> Void) {
        _vm = State(initialValue: WorkoutSummaryViewModel(session: session))
        self.onDone = onDone
    }

    var body: some View {
        List {
            Section {
                LabeledContent("Duration", value: vm.durationLabel)
                LabeledContent("Volume", value: vm.totalVolumeLabel)
                LabeledContent("Sets", value: "\(vm.totalSets)")
            }

            if !vm.exerciseRows.isEmpty {
                Section("Exercises") {
                    ForEach(vm.exerciseRows) { row in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.name)
                                Text(subtitleFor(row))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if let prWeight = row.prWeight, let prReps = row.prReps {
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("PR")
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(Color.heftGreen)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.heftGreen.opacity(0.15), in: Capsule())
                                    Text("\(vm.formatWeight(prWeight)) × \(prReps)")
                                        .font(.caption2)
                                        .foregroundStyle(Color.heftGreen.opacity(0.8))
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .navigationTitle("Summary")
        .navigationBarTitleDisplayMode(.large)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done", action: onDone)
                    .fontWeight(.semibold)
            }
        }
    }

    private func subtitleFor(_ row: WorkoutSummaryViewModel.ExerciseRow) -> String {
        let sets = "\(row.setCount) \(row.setCount == 1 ? "set" : "sets")"
        guard row.maxWeight > 0 else { return sets }
        return "\(sets) · \(vm.formatWeight(row.maxWeight)) lbs max"
    }
}

// MARK: - Preview

#Preview {
    // Build a mock session with data for preview
    let container = PersistenceController.previewContainer
    let context = container.mainContext

    let session = WorkoutSession(startedAt: Date().addingTimeInterval(-2700), completedAt: .now)
    context.insert(session)

    let snap1 = ExerciseSnapshot(exerciseName: "Bench Press", order: 0, workoutSession: session)
    context.insert(snap1)
    session.exercises.append(snap1)
    let s1 = SetRecord(weight: 135, reps: 8, setType: .normal, isPersonalRecord: true, exerciseSnapshot: snap1)
    let s2 = SetRecord(weight: 135, reps: 8, setType: .normal, exerciseSnapshot: snap1)
    let s3 = SetRecord(weight: 135, reps: 7, setType: .normal, exerciseSnapshot: snap1)
    context.insert(s1); context.insert(s2); context.insert(s3)
    snap1.sets = [s1, s2, s3]

    let snap2 = ExerciseSnapshot(exerciseName: "Squat", order: 1, workoutSession: session)
    context.insert(snap2)
    session.exercises.append(snap2)
    let s4 = SetRecord(weight: 225, reps: 5, setType: .normal, exerciseSnapshot: snap2)
    let s5 = SetRecord(weight: 225, reps: 5, setType: .normal, exerciseSnapshot: snap2)
    context.insert(s4); context.insert(s5)
    snap2.sets = [s4, s5]

    return NavigationStack {
        WorkoutSummaryView(session: session, onDone: {})
    }
    .modelContainer(container)
}
