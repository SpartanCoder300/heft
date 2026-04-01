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
    @Environment(\.OrinTheme) private var theme
    @Environment(\.OrinCardMaterial) private var cardMaterial

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

    private var pickerExistingExerciseCounts: [String: Int] {
        vm.entries.reduce(into: [:]) { counts, entry in
            counts[entry.exercise.name, default: 0] += 1
        }
    }

    private var pickerRemovableExerciseCounts: [String: Int] {
        pickerExistingExerciseCounts
    }

    private var pickerRemovableExerciseNames: Set<String> {
        Set(vm.entries.map(\.exercise.name))
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
                        .listRowBackground(Rectangle().fill(cardMaterial))
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
                            .listRowBackground(Rectangle().fill(cardMaterial))
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
                    .listRowBackground(Rectangle().fill(cardMaterial))
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
                ExercisePicker(
                    onSelect: { exercise in
                        vm.addExercise(exercise)
                    },
                    dismissesOnSelection: false,
                    existingExerciseCounts: pickerExistingExerciseCounts,
                    removableExerciseCounts: pickerRemovableExerciseCounts,
                    removableExerciseNames: pickerRemovableExerciseNames,
                    onRemoveExisting: { exercise in
                        _ = vm.removeMostRecentExercise(named: exercise.name)
                    }
                )
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
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
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

// MARK: - Preview

#Preview("New Routine") {
    RoutineBuilderView()
        .environment(AppState())
        .modelContainer(PersistenceController.previewContainer)
}
