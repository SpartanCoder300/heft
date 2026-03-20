// iOS 26+ only. No #available guards.

import SwiftUI
import SwiftData
import UIKit

struct RoutineBuilderView: View {
    @State private var vm: RoutineBuilderViewModel
    @State private var isShowingExercisePicker = false
    @State private var configEntryID: UUID? = nil
    @State private var isShowingDeleteConfirm = false
    @State private var isShowingDiscardConfirm = false
    @State private var isShowingStartAlert = false
    @State private var savedNewRoutineID: UUID? = nil

    /// Called only when a brand-new routine is saved. Lets the caller start a workout immediately.
    var onStartWorkout: ((UUID) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    init(existingRoutine: RoutineTemplate? = nil, onStartWorkout: ((UUID) -> Void)? = nil) {
        _vm = State(initialValue: RoutineBuilderViewModel(existingRoutine: existingRoutine))
        self.onStartWorkout = onStartWorkout
    }

    private var configSheetIsPresented: Binding<Bool> {
        Binding(
            get: { configEntryID != nil },
            set: { if !$0 { configEntryID = nil } }
        )
    }

    var body: some View {
        @Bindable var vm = vm

        NavigationStack {
            List {
                // ── Routine Name ──────────────────────────────────────
                Section {
                    TextField("Routine Name", text: $vm.routineName)
                        .font(.title3.weight(.semibold))
                        .autocorrectionDisabled()
                }

                // ── Exercises ─────────────────────────────────────────
                Section {
                    if vm.entries.isEmpty {
                        Text("Add exercises to build your routine.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, Spacing.md)
                            .listRowBackground(Color.clear)
                    } else {
                        ForEach(vm.entries) { entry in
                            Button { configEntryID = entry.id } label: {
                                ExerciseEntryRow(entry: entry)
                            }
                            .tint(.primary)
                        }
                        .onMove { vm.move(from: $0, to: $1) }
                        .onDelete { vm.removeEntries(at: $0) }
                    }
                } header: {
                    if !vm.entries.isEmpty {
                        Text("Exercises (\(vm.entries.count))")
                    }
                }

                // ── Add Exercise ──────────────────────────────────────
                Section {
                    Button {
                        isShowingExercisePicker = true
                    } label: {
                        Label("Add Exercise", systemImage: "plus.circle.fill")
                    }
                    .tint(.accentColor)
                }
            }
            .scrollContentBackground(.hidden)
            .themedBackground()
            .environment(\.editMode, .constant(vm.entries.isEmpty ? .inactive : .active))
            .navigationTitle(vm.isEditingExisting ? "Edit Routine" : "New Routine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        if vm.hasUnsavedChanges {
                            isShowingDiscardConfirm = true
                        } else {
                            dismiss()
                        }
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if vm.isEditingExisting {
                        Menu {
                            Button("Delete Routine", role: .destructive) {
                                isShowingDeleteConfirm = true
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                            .accessibilityLabel("Routine options")
                        }
                    }
                    Button("Save") {
                        let newID = vm.save(in: modelContext)
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        if let id = newID {
                            savedNewRoutineID = id
                            isShowingStartAlert = true
                        } else {
                            dismiss()
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(!vm.canSave)
                    .alert("Start \"\(vm.routineName)\"?", isPresented: $isShowingStartAlert) {
                        Button("Start Workout") {
                            if let id = savedNewRoutineID { onStartWorkout?(id) }
                            dismiss()
                        }
                        Button("Not Now", role: .cancel) { dismiss() }
                    }
                }
            }
            .sheet(isPresented: $isShowingExercisePicker) {
                ExercisePicker { exercise in
                    vm.addExercise(exercise)
                }
            }
            .sheet(isPresented: configSheetIsPresented) {
                if let id = configEntryID,
                   let idx = vm.entries.firstIndex(where: { $0.id == id }) {
                    ExerciseConfigSheet(
                        entry: Binding(
                            get: { vm.entries[idx] },
                            set: { vm.entries[idx] = $0 }
                        ),
                        onRemove: {
                            vm.removeEntry(withID: id)
                            configEntryID = nil
                        }
                    )
                }
            }
            .confirmationDialog(
                "Discard Changes?",
                isPresented: $isShowingDiscardConfirm,
                titleVisibility: .visible
            ) {
                Button("Discard", role: .destructive) { dismiss() }
            }
            .confirmationDialog(
                "Delete \"\(vm.routineName)\"?",
                isPresented: $isShowingDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete Routine", role: .destructive) {
                    vm.deleteRoutine(from: modelContext)
                    dismiss()
                }
            } message: {
                Text("Your workout history won't be affected.")
            }
        }
    }
}

// MARK: - Exercise Entry Row

private struct ExerciseEntryRow: View {
    let entry: RoutineBuilderViewModel.DraftEntry

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: entry.exercise.iconName)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.exercise.name)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private var subtitle: String {
        var parts = ["\(entry.targetSets) sets · \(entry.targetRepsMin)–\(entry.targetRepsMax) reps"]
        parts.append(restLabel(entry.restSeconds))
        if let groups = entry.exercise.muscleGroups.prefix(2).joined(separator: ", ").nilIfEmpty {
            parts.append(groups)
        }
        return parts.joined(separator: " · ")
    }

    private func restLabel(_ seconds: Int) -> String {
        if seconds < 60 { return "\(seconds)s rest" }
        let m = seconds / 60
        let s = seconds % 60
        return s == 0 ? "\(m) min rest" : "\(m):\(String(format: "%02d", s)) rest"
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

// MARK: - Exercise Config Sheet

private struct ExerciseConfigSheet: View {
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

#Preview("New Routine") {
    RoutineBuilderView()
        .environment(AppState())
        .modelContainer(PersistenceController.previewContainer)
}
