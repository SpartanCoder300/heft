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
    @State private var selectedExercises: [ExerciseDefinition] = []
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {

                    // ── Selected strip ──────────────────────────────────────
                    if !dismissesOnSelection && !selectedExercises.isEmpty {
                        selectedStrip
                            .padding(.top, Spacing.xs)
                        Divider()
                    }

                    // ── Results ────────────────────────────────────────────
                    let recents = vm.recentExercises(from: allExercises, filters: vm.selectedFilters)
                    if vm.searchText.isEmpty && !recents.isEmpty {
                        sectionHeader("Recents")
                        ForEach(recents) { exercise in
                            exerciseRow(exercise, matchRanges: [])
                            Divider().padding(.leading, Spacing.md)
                        }
                    }

                    let library = vm.libraryExercises(from: allExercises)
                    sectionHeader(vm.searchText.isEmpty && vm.selectedFilters.isEmpty
                                  ? "All Exercises"
                                  : "Results (\(library.count))")
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
                            Divider().padding(.leading, Spacing.md)
                        }
                    }
                }
                .padding(.bottom, Spacing.lg)
            }
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if !dismissesOnSelection {
                        let count = selectedExercises.count
                        Button(count == 0 ? "Done" : "Done (\(count))") {
                            selectedExercises.forEach { onSelect($0) }
                            dismiss()
                        }
                        .fontWeight(.semibold)
                        .disabled(count == 0)
                    }
                }

                // Spacer() between items causes iOS 26 to render each as a
                // separate Liquid Glass pill: [filter] [··· search ···] [create]
                ToolbarItemGroup(placement: .bottomBar) {
                    Menu {
                        Section("Muscle") {
                            ForEach(allMuscleGroups, id: \.self) { name in
                                let filter = PickerFilter.muscleGroup(name)
                                Button { vm.toggleFilter(filter) } label: {
                                    if vm.selectedFilters.contains(filter) {
                                        Label(name, systemImage: "checkmark")
                                    } else {
                                        Text(name)
                                    }
                                }
                            }
                        }
                        Section("Equipment") {
                            ForEach(allEquipmentTypes, id: \.self) { name in
                                let filter = PickerFilter.equipment(name)
                                Button { vm.toggleFilter(filter) } label: {
                                    if vm.selectedFilters.contains(filter) {
                                        Label(name, systemImage: "checkmark")
                                    } else {
                                        Text(name)
                                    }
                                }
                            }
                            let custom = PickerFilter.custom
                            Button { vm.toggleFilter(custom) } label: {
                                if vm.selectedFilters.contains(custom) {
                                    Label("Custom", systemImage: "checkmark")
                                } else {
                                    Text("Custom")
                                }
                            }
                        }
                        if !vm.selectedFilters.isEmpty {
                            Button(role: .destructive) {
                                vm.selectedFilters.removeAll()
                            } label: {
                                Label("Clear Filters", systemImage: "xmark")
                            }
                        }
                    } label: {
                        Image(systemName: vm.selectedFilters.isEmpty
                              ? "line.3.horizontal.decrease"
                              : "line.3.horizontal.decrease.circle.fill")
                            .font(.system(size: 20))
                    }
                    .tint(vm.selectedFilters.isEmpty ? Color.primary : theme.accentColor)

                    Spacer()

                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                        TextField("Search exercises", text: $vm.searchText)
                            .focused($isSearchFocused)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .submitLabel(.search)
                            .onSubmit { isSearchFocused = false }
                        if !vm.searchText.isEmpty {
                            Button { vm.searchText = "" } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 15))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Spacer()

                    Button {
                        editorTarget = .new
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 20))
                    }
                    .tint(theme.accentColor)
                }
            }
            .sheet(item: $editorTarget) { target in
                ExerciseEditorView(exercise: target.exercise) { newExercise in
                    if case .new = target { handleNewExercise(newExercise) }
                }
            }
        }
        .onAppear {
            vm.load(container: modelContext.container)
        }
        .task {
            // Brief delay so the sheet presentation animation finishes before
            // the keyboard appears — prevents layout jump on open.
            try? await Task.sleep(for: .milliseconds(50))
            isSearchFocused = true
        }
    }

    // MARK: - Selected strip

    private var selectedStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.xs) {
                ForEach(selectedExercises) { exercise in
                    Button {
                        deselect(exercise)
                    } label: {
                        HStack(spacing: 4) {
                            Text(exercise.name)
                                .font(.system(size: 13, weight: .medium))
                                .lineLimit(1)
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundStyle(theme.accentColor)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, 6)
                        .background(theme.accentColor.opacity(0.15), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.xs)
        }
        .scrollClipDisabled()
    }

    // MARK: - Section header

    private func sectionHeader(_ label: String) -> some View {
        Text(label)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.textMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.xs)
            .background(.background)
    }

    // MARK: - Helpers

    private func handleNewExercise(_ exercise: ExerciseDefinition) {
        if dismissesOnSelection {
            onSelect(exercise)
            dismiss()
        } else {
            guard !selectedExercises.contains(where: { $0.id == exercise.id }) else { return }
            selectedExercises.append(exercise)
            vm.sessionAddedIDs.insert(exercise.id)
        }
    }

    private func select(_ exercise: ExerciseDefinition) {
        isSearchFocused = false
        if dismissesOnSelection {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            onSelect(exercise)
            dismiss()
        } else {
            toggleSelection(exercise)
        }
    }

    private func toggleSelection(_ exercise: ExerciseDefinition) {
        if let idx = selectedExercises.firstIndex(where: { $0.id == exercise.id }) {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            selectedExercises.remove(at: idx)
            vm.sessionAddedIDs.remove(exercise.id)
        } else {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            selectedExercises.append(exercise)
            vm.sessionAddedIDs.insert(exercise.id)
        }
    }

    private func deselect(_ exercise: ExerciseDefinition) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        selectedExercises.removeAll { $0.id == exercise.id }
        vm.sessionAddedIDs.remove(exercise.id)
    }

    // MARK: - View builders

    @ViewBuilder
    private func exerciseRow(_ exercise: ExerciseDefinition, matchRanges: [Range<String.Index>]) -> some View {
        let isSelected = selectedExercises.contains(where: { $0.id == exercise.id })
        let inUseCount = existingExerciseCounts[exercise.name] ?? 0
        LibraryRow(
            exercise: exercise,
            matchRanges: matchRanges,
            accentColor: theme.accentColor,
            addedCount: isSelected ? 1 : 0,
            inUseCount: inUseCount,
            onTap: { select(exercise) },
            onEdit: { editorTarget = .edit(exercise) }
        )
    }
}

// MARK: - Editor Target

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
