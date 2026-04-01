// iOS 26+ only. No #available guards.

import SwiftUI
import SwiftData

private let allMuscleGroups = ["Chest", "Back", "Shoulders", "Biceps", "Triceps", "Forearms", "Legs", "Core"]
private let allEquipmentTypes = ["Barbell", "Dumbbell", "Cable", "Machine", "Kettlebell", "Bodyweight", "Band"]

struct ExercisePicker: View {
    let onSelect: (ExerciseDefinition) -> Void
    var dismissesOnSelection: Bool = true
    var existingExerciseCounts: [String: Int] = [:]
    var removableExerciseCounts: [String: Int] = [:]
    var onRemoveExisting: ((ExerciseDefinition) -> Void)? = nil
    var title: String = "Add Exercise"

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.OrinTheme) private var theme

    @Query(sort: \ExerciseDefinition.name) private var allExercises: [ExerciseDefinition]

    @State private var vm = ExercisePickerViewModel()
    @State private var editorTarget: ExerciseEditorTarget? = nil

    private let muscleFilters    = allMuscleGroups.map    { PickerFilter.muscleGroup($0) }
    private let equipmentFilters = allEquipmentTypes.map  { PickerFilter.equipment($0)  }
    private let specialFilters: [PickerFilter] = [.custom]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // ── Filter chips ───────────────────────────────────────────
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    // Row 1: muscle groups
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Spacing.xs) {
                            filterChip("All", isSelected: vm.selectedFilters.isEmpty) {
                                vm.selectedFilters.removeAll()
                            }
                            filterSeparator
                            ForEach(muscleFilters, id: \.self) { option in
                                let on = vm.selectedFilters.contains(option)
                                filterChip(option.label, isSelected: on) { toggle(option) }
                            }
                        }
                        .padding(.horizontal, Spacing.xs)
                        .padding(.vertical, Spacing.xs)
                    }
                    .scrollClipDisabled()
                    // Row 2: equipment + custom
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Spacing.xs) {
                            ForEach(equipmentFilters, id: \.self) { option in
                                let on = vm.selectedFilters.contains(option)
                                filterChip(option.label, isSelected: on) { toggle(option) }
                            }
                            filterSeparator
                            ForEach(specialFilters, id: \.self) { option in
                                let on = vm.selectedFilters.contains(option)
                                filterChip(option.label, isSelected: on) { toggle(option) }
                            }
                        }
                        .padding(.horizontal, Spacing.xs)
                        .padding(.vertical, Spacing.xs)
                    }
                    .scrollClipDisabled()
                }
                .padding(.vertical, Spacing.xs)
                Divider()

                // ── Exercise List ──────────────────────────────────────────
                List {
                    let recents = vm.recentExercises(from: allExercises, filters: vm.selectedFilters)
                    if vm.searchText.isEmpty && !recents.isEmpty {
                        Section("Recents") {
                            ForEach(recents) { exercise in
                                exerciseRow(exercise, matchRanges: [])
                            }
                        }
                    }

                    let library = vm.libraryExercises(from: allExercises)
                    Section(vm.searchText.isEmpty && vm.selectedFilters.isEmpty
                            ? "All Exercises"
                            : "Results (\(library.count))") {
                        if library.isEmpty {
                            Text("No exercises found")
                                .font(Typography.caption)
                                .foregroundStyle(Color.textFaint)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, Spacing.lg)
                        } else {
                            ForEach(library) { exercise in
                                exerciseRow(exercise,
                                            matchRanges: vm.matchRanges(query: vm.searchText, in: exercise.name))
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $vm.searchText,
                        placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Search exercises")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(dismissButtonTitle) { dismiss() }
                        .fontWeight(.semibold)
                }
                ToolbarItem(placement: .bottomBar) {
                    Button { editorTarget = .new } label: {
                        Label("New Exercise", systemImage: "plus.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .tint(theme.accentColor)
                }
            }
            .sheet(item: $editorTarget) { target in
                ExerciseEditorView(exercise: target.exercise)
            }
        }
        .onAppear {
            vm.load(container: modelContext.container)
        }
    }

    // MARK: - Helpers

    private func toggle(_ filter: PickerFilter) {
        if vm.selectedFilters.contains(filter) {
            vm.selectedFilters.remove(filter)
        } else {
            vm.selectedFilters.insert(filter)
        }
    }

    private var dismissButtonTitle: String {
        dismissesOnSelection ? "Cancel" : "Done"
    }

    private func select(_ exercise: ExerciseDefinition) {
        let isAlreadyAdded = (removableExerciseCounts[exercise.name] ?? 0) > 0
        if isAlreadyAdded {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            vm.sessionAddedIDs.remove(exercise.id)
            remove(exercise)
        } else {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            vm.sessionAddedIDs.insert(exercise.id)
            onSelect(exercise)
            if dismissesOnSelection {
                dismiss()
            }
        }
    }

    private func addAgain(_ exercise: ExerciseDefinition) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        onSelect(exercise)
    }

    private func remove(_ exercise: ExerciseDefinition) {
        onRemoveExisting?(exercise)
    }

    // MARK: - View builders

    @ViewBuilder
    private func exerciseRow(_ exercise: ExerciseDefinition, matchRanges: [Range<String.Index>]) -> some View {
        let removable = removableExerciseCounts[exercise.name] ?? 0
        let total = existingExerciseCounts[exercise.name] ?? 0
        LibraryRow(
            exercise: exercise,
            matchRanges: matchRanges,
            accentColor: theme.accentColor,
            addedCount: removable,
            inUseCount: max(0, total - removable),
            onTap: { select(exercise) },
            onEdit: { editorTarget = .edit(exercise) },
            onAddAgain: removable > 0 ? { addAgain(exercise) } : nil
        )
        .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
    }

    @ViewBuilder
    private func filterChip(_ label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? theme.accentColor : Color.textMuted)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: Capsule())
    }

    private var filterSeparator: some View {
        Rectangle()
            .fill(Color.white.opacity(0.15))
            .frame(width: 1, height: 18)
            .padding(.horizontal, 2)
    }


}

// MARK: - Editor Target

/// Drives the sheet presented from the picker — new exercise or edit existing.
private enum ExerciseEditorTarget: Identifiable {
    case new
    case edit(ExerciseDefinition)

    var id: String {
        switch self {
        case .new:          return "new"
        case .edit(let ex): return ex.id.uuidString
        }
    }

    var exercise: ExerciseDefinition? {
        switch self {
        case .new:          return nil
        case .edit(let ex): return ex
        }
    }
}

#Preview {
    ExercisePicker(
        onSelect: { _ in },
        dismissesOnSelection: false,
        existingExerciseCounts: ["Bench Press": 1, "Squat": 2, "Deadlift": 1],
        removableExerciseCounts: ["Bench Press": 1, "Squat": 2]
    )
        .environment(AppState())
        .modelContainer(PersistenceController.previewContainer)
}
