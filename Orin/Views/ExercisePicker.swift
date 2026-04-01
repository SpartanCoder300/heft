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
    var removableExerciseNames: Set<String> = []
    var onRemoveExisting: ((ExerciseDefinition) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.OrinTheme) private var theme
    @AppStorage("Orin.exercisePickerSwipeHintSeen") private var hasSeenSwipeHint = false

    @Query(sort: \ExerciseDefinition.name) private var allExercises: [ExerciseDefinition]

    @State private var vm = ExercisePickerViewModel()
    @State private var editorTarget: ExerciseEditorTarget? = nil
    @State private var isShowingSwipeHint = false

    private let muscleFilters    = allMuscleGroups.map    { PickerFilter.muscleGroup($0) }
    private let equipmentFilters = allEquipmentTypes.map  { PickerFilter.equipment($0)  }
    private let specialFilters: [PickerFilter] = [.custom]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {

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

                    // ── Recents ────────────────────────────────────────────────
                    let recents = vm.recentExercises(from: allExercises, filters: vm.selectedFilters)
                    if vm.searchText.isEmpty && !recents.isEmpty {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            pickerSectionLabel("Recents")

                            exerciseCard(recents) { exercise in
                                LibraryRow(
                                    exercise: exercise,
                                    matchRanges: [],
                                    accentColor: theme.accentColor,
                                    statusText: statusText(for: exercise),
                                    secondaryActionTitle: removableExerciseNames.contains(exercise.name) ? "Undo" : nil,
                                    secondaryAction: removableExerciseNames.contains(exercise.name) ? { remove(exercise) } : nil,
                                    onTap: { select(exercise) },
                                    onEdit: { editorTarget = .edit(exercise) }
                                )
                            }
                        }
                    }

                    // ── Full Library ───────────────────────────────────────────
                    let library = vm.libraryExercises(from: allExercises)
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        pickerSectionLabel(vm.searchText.isEmpty && vm.selectedFilters.isEmpty
                                           ? "All Exercises"
                                           : "Results (\(library.count))")

                        if library.isEmpty {
                            Text("No exercises found")
                                .font(Typography.caption)
                                .foregroundStyle(Color.textFaint)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Spacing.lg)
                        } else {
                            exerciseCard(library) { exercise in
                                LibraryRow(
                                    exercise: exercise,
                                    matchRanges: vm.matchRanges(query: vm.searchText, in: exercise.name),
                                    accentColor: theme.accentColor,
                                    statusText: statusText(for: exercise),
                                    secondaryActionTitle: removableExerciseNames.contains(exercise.name) ? "Undo" : nil,
                                    secondaryAction: removableExerciseNames.contains(exercise.name) ? { remove(exercise) } : nil,
                                    onTap: { select(exercise) },
                                    onEdit: { editorTarget = .edit(exercise) }
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.lg)
            }
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $vm.searchText,
                        placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Search exercises")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(dismissesOnSelection ? "Cancel" : "Done") { dismiss() }
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
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if isShowingSwipeHint {
                    undoHintBanner
                        .padding(.horizontal, Spacing.md)
                        .padding(.bottom, Spacing.sm)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .onAppear {
            vm.load(container: modelContext.container)
        }
        .animation(Motion.standardSpring, value: isShowingSwipeHint)
    }

    // MARK: - Helpers

    private func toggle(_ filter: PickerFilter) {
        if vm.selectedFilters.contains(filter) {
            vm.selectedFilters.remove(filter)
        } else {
            vm.selectedFilters.insert(filter)
        }
    }

    private func select(_ exercise: ExerciseDefinition) {
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        onSelect(exercise)
        maybeShowSwipeHint()
        if dismissesOnSelection {
            dismiss()
        }
    }

    private func statusText(for exercise: ExerciseDefinition) -> String? {
        let totalCount = existingExerciseCounts[exercise.name] ?? 0
        let removableCount = removableExerciseCounts[exercise.name] ?? 0

        if removableCount > 0 {
            return removableCount == 1 ? "Added" : "\(removableCount)x Added"
        }
        guard totalCount > 0 else { return nil }
        return totalCount == 1 ? "In Use" : "\(totalCount)x In Use"
    }

    private func maybeShowSwipeHint() {
        guard !dismissesOnSelection,
              onRemoveExisting != nil,
              !hasSeenSwipeHint else { return }

        hasSeenSwipeHint = true
        isShowingSwipeHint = true

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(4.5))
            guard isShowingSwipeHint else { return }
            withAnimation(Motion.standardSpring) {
                isShowingSwipeHint = false
            }
        }
    }

    private func remove(_ exercise: ExerciseDefinition) {
        onRemoveExisting?(exercise)
    }

    // MARK: - View builders

    /// Renders a list of exercises in a grouped card with inset dividers.
    @ViewBuilder
    private func exerciseCard(_ exercises: [ExerciseDefinition],
                               row: @escaping (ExerciseDefinition) -> LibraryRow) -> some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(exercises.enumerated()), id: \.element.id) { idx, exercise in
                row(exercise)
                if idx < exercises.count - 1 {
                    Divider()
                        .padding(.leading, Spacing.md)
                }
            }
        }
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        }
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

    private var undoHintBanner: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "arrow.uturn.backward.circle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(theme.accentColor)

            Text("Added. Tap Undo on a row to remove the last one.")
                .font(Typography.caption)
                .foregroundStyle(Color.textPrimary)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        }
    }

    @ViewBuilder
    private func pickerSectionLabel(_ title: String) -> some View {
        Text(title)
            .font(Typography.caption)
            .fontWeight(.semibold)
            .foregroundStyle(Color.textFaint)
            .textCase(.uppercase)
            .tracking(0.8)
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
