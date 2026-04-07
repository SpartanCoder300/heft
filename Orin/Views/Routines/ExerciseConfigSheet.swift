// iOS 26+ only. No #available guards.

import SwiftUI
import SwiftData

// MARK: - Exercise Config Sheet

struct ExerciseConfigSheet: View {
    @Binding var entry: RoutineBuilderViewModel.DraftEntry
    let onRemove: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private let restOptions = [30, 45, 60, 90, 120, 150, 180, 240, 300]
    private let incrementOptions: [(value: Double, label: String)] = [
        (1.0,  "1 lb"),
        (1.25, "1.25 lbs"),
        (2.0,  "2 lbs"),
        (2.5,  "2.5 lbs"),
        (5.0,  "5 lbs"),
        (10.0, "10 lbs"),
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Sets") {
                    Stepper(
                        "\(entry.targetSets) set\(entry.targetSets == 1 ? "" : "s")",
                        value: $entry.targetSets,
                        in: 1...10
                    )
                }

                Section("Reps") {
                    Stepper("Min  \(entry.targetRepsMin)", value: $entry.targetRepsMin, in: 1...99)
                        .onChange(of: entry.targetRepsMin) { _, v in
                            if v > entry.targetRepsMax { entry.targetRepsMax = v }
                        }
                    Stepper("Max  \(entry.targetRepsMax)", value: $entry.targetRepsMax, in: 1...99)
                        .onChange(of: entry.targetRepsMax) { _, v in
                            if v < entry.targetRepsMin { entry.targetRepsMin = v }
                        }
                }

                Section("Rest") {
                    Picker("Rest time", selection: $entry.restSeconds) {
                        ForEach(restOptions, id: \.self) { s in
                            Text(restLabel(s)).tag(s)
                        }
                    }
                }

                if entry.exercise.tracksWeight {
                    Section("Weight Increment") {
                        let incrementBinding = Binding<Double>(
                            get: { entry.exercise.resolvedWeightIncrement },
                            set: { entry.exercise.weightIncrement = $0 }
                        )
                        Picker("Increment", selection: incrementBinding) {
                            ForEach(incrementOptions, id: \.value) { option in
                                Text(option.label).tag(option.value)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                Section {
                    Button("Remove from Routine", role: .destructive) {
                        onRemove()
                        dismiss()
                    }
                }
            }
            .navigationTitle(entry.exercise.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        try? modelContext.save()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func restLabel(_ seconds: Int) -> String {
        if seconds < 60 { return "\(seconds)s" }
        let m = seconds / 60
        let s = seconds % 60
        return s == 0 ? "\(m) min" : "\(m):\(String(format: "%02d", s))"
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var entry = RoutineBuilderViewModel.DraftEntry(
        exercise: ExerciseDefinition(
            name: "Bench Press",
            muscleGroups: ["Chest", "Triceps"],
            equipmentType: "Barbell",
            weightIncrement: 2.5,
            isTimed: false
        )
    )
    ExerciseConfigSheet(entry: $entry, onRemove: {})
        .modelContainer(PersistenceController.previewContainer)
        .preferredColorScheme(.dark)
}
