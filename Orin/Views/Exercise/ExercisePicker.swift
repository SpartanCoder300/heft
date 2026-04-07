// iOS 26+ only. No #available guards.

import SwiftUI
import SwiftData

private let allMuscleGroups = ["Chest", "Back", "Shoulders", "Biceps", "Triceps", "Forearms", "Legs", "Core"]
private let allEquipmentTypes = ["Barbell", "Dumbbell", "Cable", "Machine", "Kettlebell", "Bodyweight", "Band"]
private let exercisePickerRaisedSurface = Color.white.opacity(0.055)

struct ExercisePicker: View {
    let onSelect: (ExerciseDefinition) -> Void
    var dismissesOnSelection: Bool = true
    var embedsInNavigationStack: Bool = true
    var showsCancelButton: Bool = true
    var existingExerciseCounts: [String: Int] = [:]
    var title: String = "Add Exercise"

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.OrinTheme) private var theme

    @Query(sort: \ExerciseDefinition.name) private var allExercises: [ExerciseDefinition]

    @State private var vm = ExercisePickerViewModel()
    @State private var editorTarget: ExerciseEditorTarget? = nil
    @State private var selectedExercises: [ExerciseDefinition] = []
    @State private var selectionFeedbackTrigger = 0
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        navigationContainer {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    let selectedIDs = Set(selectedExercises.map(\.id))

                    // ── Filter chips ────────────────────────────────────────
                    filterChips
                    Divider()

                    // ── Selected section ────────────────────────────────────
                    if !dismissesOnSelection && !selectedExercises.isEmpty {
                        VStack(spacing: 4) {
                            sectionHeader("Selected (\(selectedExercises.count))", prominence: .primary)
                            ForEach(selectedExercises) { exercise in
                                exerciseRow(exercise, matchRanges: [], placement: .selected)
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        .padding(.bottom, Spacing.xs)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // ── Results ────────────────────────────────────────────
                    let recents = vm.recentExercises(from: allExercises, filters: vm.selectedFilters)
                        .filter { !selectedIDs.contains($0.id) }
                    if vm.searchText.isEmpty && !recents.isEmpty {
                        sectionHeader("Recents", prominence: .secondary)
                        ForEach(recents) { exercise in
                            exerciseRow(exercise, matchRanges: [], placement: .recent)
                            Divider().padding(.leading, Spacing.md)
                        }
                    }

                    let library = vm.libraryExercises(from: allExercises)
                        .filter { !selectedIDs.contains($0.id) }
                    let hasActiveFilters = !vm.searchText.isEmpty || !vm.selectedFilters.isEmpty
                    sectionHeader(
                        hasActiveFilters ? "Results (\(library.count))" : "All Exercises",
                        prominence: .tertiary,
                        clearAction: hasActiveFilters ? {
                            vm.searchText = ""
                            vm.selectedFilters = []
                        } : nil
                    )
                    if library.isEmpty {
                        Text("No exercises found")
                            .font(Typography.caption)
                            .foregroundStyle(Color.textFaint)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, Spacing.lg)
                    } else {
                        ForEach(library) { exercise in
                            exerciseRow(exercise,
                                        matchRanges: vm.matchRanges(query: vm.searchText, in: exercise.name),
                                        placement: .library)
                            Divider().padding(.leading, Spacing.md)
                        }
                    }
                }
                .padding(.bottom, Spacing.lg)
            }
            .background(Color.OrinWorkflowBackground)
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if showsCancelButton {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") { dismiss() }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if !dismissesOnSelection {
                        let count = selectedExercises.count
                        Button(count == 0 ? "Add" : "Add (\(count))") {
                            selectedExercises.forEach { onSelect($0) }
                            dismiss()
                        }
                        .fontWeight(.semibold)
                        .disabled(count == 0)
                    }
                }

                ToolbarItemGroup(placement: .bottomBar) {
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
            .navigationDestination(item: $editorTarget) { target in
                ExerciseEditorView(
                    exercise: target.exercise,
                    embedsInNavigationStack: false,
                    showsCancelButton: embedsInNavigationStack
                ) { newExercise in
                    if case .new = target { handleNewExercise(newExercise) }
                }
            }
        }
        .modifier(ExercisePickerPresentationBackground(enabled: embedsInNavigationStack))
        .onAppear {
            vm.load(container: modelContext.container)
        }
        .sensoryFeedback(.selection, trigger: selectionFeedbackTrigger)
        .task {
            // Brief delay so the sheet presentation animation finishes before
            // the keyboard appears — prevents layout jump on open.
            try? await Task.sleep(for: .milliseconds(50))
            isSearchFocused = true
        }
    }

    @ViewBuilder
    private func navigationContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if embedsInNavigationStack {
            NavigationStack {
                content()
            }
        } else {
            content()
        }
    }

    // MARK: - Filter chips

    private var filterChips: some View {
        let muscleFilters = allMuscleGroups.map { PickerFilter.muscleGroup($0) }
        let equipmentFilters = allEquipmentTypes.map { PickerFilter.equipment($0) } + [PickerFilter.custom]
        return VStack(alignment: .leading, spacing: 0) {
            filterRow(label: "Muscle", filters: muscleFilters)
            filterRow(label: "Equipment", filters: equipmentFilters)
        }
    }

    private func filterRow(label: String, filters: [PickerFilter]) -> some View {
        let anyActive = filters.contains { vm.selectedFilters.contains($0) }
        return HStack(spacing: 0) {
            // Reduced label dominance: smaller, lower opacity
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.secondary.opacity(0.6))
                .frame(width: 76, alignment: .leading)
                .padding(.leading, Spacing.md)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.xs) {
                    chip(label: "All", active: !anyActive) {
                        filters.forEach { vm.selectedFilters.remove($0) }
                    }
                    ForEach(filters, id: \.self) { filter in
                        chip(label: filter.label, active: vm.selectedFilters.contains(filter)) {
                            vm.toggleFilter(filter)
                        }
                    }
                }
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)  // tighter vertical
            }
            .scrollClipDisabled()
        }
    }

    private func chip(label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            Text(label)
                .font(.system(size: 13, weight: active ? .semibold : .regular))
                .foregroundStyle(active ? Color.black : Color.secondary.opacity(0.7))
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, 5)
                // Active: solid accent — high contrast. Inactive: very subtle, recedes.
                .background(Capsule().fill(active ? theme.accentColor : exercisePickerRaisedSurface))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Section header

    private func sectionHeader(
        _ label: String,
        prominence: SectionHeaderProminence = .secondary,
        clearAction: (() -> Void)? = nil
    ) -> some View {
        HStack {
            Text(label)
                .font(.system(size: prominence.fontSize, weight: prominence.fontWeight))
                .foregroundStyle(prominence.foregroundColor)
            Spacer()
            if let clearAction {
                Button("Clear", action: clearAction)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.textFaint)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.md)
        .padding(.top, prominence.topPadding)
        .padding(.bottom, Spacing.xs)
        .background(Color.OrinWorkflowBackground)
    }

    // MARK: - Helpers

    private func handleNewExercise(_ exercise: ExerciseDefinition) {
        if dismissesOnSelection {
            onSelect(exercise)
            dismiss()
        } else {
            guard !selectedExercises.contains(where: { $0.id == exercise.id }) else { return }
            withAnimation(.smooth(duration: 0.32)) {
                selectedExercises.append(exercise)
                vm.sessionAddedIDs.insert(exercise.id)
            }
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
            withAnimation(.smooth(duration: 0.32)) {
                selectedExercises.remove(at: idx)
                vm.sessionAddedIDs.remove(exercise.id)
                selectionFeedbackTrigger += 1
            }
        } else {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            withAnimation(.smooth(duration: 0.32)) {
                selectedExercises.append(exercise)
                vm.sessionAddedIDs.insert(exercise.id)
                selectionFeedbackTrigger += 1
            }
        }
    }

    // MARK: - View builders

    @ViewBuilder
    private func exerciseRow(
        _ exercise: ExerciseDefinition,
        matchRanges: [Range<String.Index>],
        placement: ExerciseRowPlacement
    ) -> some View {
        let isSelected = selectedExercises.contains(where: { $0.id == exercise.id })
        let inUseCount = existingExerciseCounts[exercise.name] ?? 0
        let addedCount = vm.sessionAddedIDs.contains(exercise.id) ? 1 : 0
        LibraryRow(
            exercise: exercise,
            matchRanges: matchRanges,
            accentColor: theme.accentColor,
            isSelected: isSelected,
            isPinnedSelection: placement == .selected,
            addedCount: addedCount,
            inUseCount: inUseCount,
            onTap: { select(exercise) },
            onEdit: { editorTarget = .edit(exercise) }
        )
    }
}

// MARK: - Editor Target

private enum ExerciseEditorTarget: Identifiable, Hashable {
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

    static func == (lhs: ExerciseEditorTarget, rhs: ExerciseEditorTarget) -> Bool {
        switch (lhs, rhs) {
        case (.new, .new):
            return true
        case (.edit(let left), .edit(let right)):
            return left.id == right.id
        default:
            return false
        }
    }

    func hash(into hasher: inout Hasher) {
        switch self {
        case .new:
            hasher.combine("new")
        case .edit(let exercise):
            hasher.combine(exercise.id)
        }
    }
}

private enum ExerciseRowPlacement {
    case selected
    case recent
    case library
}

private enum SectionHeaderProminence {
    case primary
    case secondary
    case tertiary

    var fontSize: CGFloat {
        switch self {
        case .primary: return 14
        case .secondary, .tertiary: return 13
        }
    }

    var fontWeight: Font.Weight {
        switch self {
        case .primary: return .semibold
        case .secondary: return .semibold
        case .tertiary: return .medium
        }
    }

    var foregroundColor: Color {
        switch self {
        case .primary: return Color.primary.opacity(0.96)
        case .secondary: return Color.primary.opacity(0.82)
        case .tertiary: return Color.textMuted.opacity(0.62)
        }
    }

    var topPadding: CGFloat {
        switch self {
        case .primary: return Spacing.xl
        case .secondary: return Spacing.lg + 2
        case .tertiary: return Spacing.xl + 2
        }
    }
}

#Preview {
    ExercisePicker(
        onSelect: { _ in },
        dismissesOnSelection: false,
        existingExerciseCounts: ["Bench Press": 1, "Squat": 2, "Deadlift": 1]
    )
        .environment(AppState())
        .modelContainer(PersistenceController.previewContainer)
}

private struct ExercisePickerPresentationBackground: ViewModifier {
    let enabled: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if enabled {
            content.presentationBackground(Color.OrinWorkflowBackground)
        } else {
            content
        }
    }
}
