// iOS 26+ only. No #available guards.

import SwiftUI
import SwiftData

private let allMuscleGroups = ["Chest", "Back", "Shoulders", "Biceps", "Triceps", "Forearms", "Legs", "Core"]

struct ExercisePicker: View {
    let onSelect: (ExerciseDefinition) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.heftTheme) private var theme

    @Query(sort: \ExerciseDefinition.name) private var allExercises: [ExerciseDefinition]

    @State private var vm = ExercisePickerViewModel()

    private let recentsColumns = Array(repeating: GridItem(.flexible(), spacing: Spacing.sm), count: 4)
    private let filterChips = ["All"] + allMuscleGroups

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {

                    // ── Muscle Group Filter ────────────────────────────────
                    let chipColumns = Array(repeating: GridItem(.flexible(), spacing: Spacing.xs), count: 4)
                    LazyVGrid(columns: chipColumns, spacing: Spacing.xs) {
                        ForEach(filterChips, id: \.self) { chip in
                            let isSelected = chip == "All"
                                ? vm.selectedMuscleGroup == nil
                                : vm.selectedMuscleGroup == chip
                            Button {
                                vm.selectedMuscleGroup = chip == "All" ? nil : chip
                            } label: {
                                Text(chip)
                                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                                    .foregroundStyle(isSelected ? theme.accentColor : Color.textMuted)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                            }
                            .buttonStyle(.plain)
                            .glassEffect(.regular.interactive(), in: Capsule())
                        }
                    }

                    // ── Recents Grid (hidden during search/filter) ──────────
                    let recents = vm.recentExercises(from: allExercises)
                    if vm.searchText.isEmpty && vm.selectedMuscleGroup == nil && !recents.isEmpty {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            pickerSectionLabel("Recent")
                            LazyVGrid(columns: recentsColumns, spacing: Spacing.sm) {
                                ForEach(recents) { exercise in
                                    RecentTile(exercise: exercise, accentColor: theme.accentColor) {
                                        select(exercise)
                                    }
                                }
                            }
                        }
                    }

                    // ── Full Library ────────────────────────────────────────
                    let library = vm.libraryExercises(from: allExercises)
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        pickerSectionLabel(vm.searchText.isEmpty && vm.selectedMuscleGroup == nil
                                           ? "All Exercises"
                                           : "Results (\(library.count))")

                        if library.isEmpty {
                            Text("No exercises found")
                                .font(Typography.caption)
                                .foregroundStyle(Color.textFaint)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Spacing.lg)
                        } else {
                            LazyVStack(spacing: 2) {
                                ForEach(library) { exercise in
                                    LibraryRow(
                                        exercise: exercise,
                                        matchRanges: vm.matchRanges(query: vm.searchText, in: exercise.name),
                                        accentColor: theme.accentColor
                                    ) {
                                        select(exercise)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.lg)
            }
            .themedBackground()
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $vm.searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search exercises")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .onAppear {
            vm.load(container: modelContext.container)
        }
    }

    // MARK: - Private

    private func select(_ exercise: ExerciseDefinition) {
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        onSelect(exercise)
        dismiss()
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

// MARK: - Recent Tile

private struct RecentTile: View {
    let exercise: ExerciseDefinition
    let accentColor: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Image(systemName: iconName)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(accentColor)
                Spacer(minLength: 0)
                Text(exercise.name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(Spacing.sm)
            .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var iconName: String {
        exercise.iconName
    }
}

// MARK: - Library Row

private struct LibraryRow: View {
    let exercise: ExerciseDefinition
    let matchRanges: [Range<String.Index>]
    let accentColor: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.md) {
                Image(systemName: iconName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(accentColor)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    HighlightedText(
                        text: exercise.name,
                        ranges: matchRanges,
                        highlightColor: accentColor
                    )
                    .font(Typography.body)

                    if !exercise.muscleGroups.isEmpty {
                        Text(exercise.muscleGroups.prefix(2).joined(separator: " · "))
                            .font(Typography.caption)
                            .foregroundStyle(Color.textFaint)
                    }
                }

                Spacer()

                if exercise.isCustom {
                    Text("Custom")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(accentColor)
                        .textCase(.uppercase)
                        .tracking(0.4)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(accentColor.opacity(0.12), in: Capsule())
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var iconName: String {
        exercise.iconName
    }
}

// MARK: - Highlighted Text

private struct HighlightedText: View {
    let text: String
    let ranges: [Range<String.Index>]
    let highlightColor: Color

    var body: some View {
        if ranges.isEmpty {
            Text(text).foregroundStyle(Color.textPrimary)
        } else {
            buildAttributed()
        }
    }

    private func buildAttributed() -> some View {
        var result = AttributedString(text)
        result.foregroundColor = UIColor(Color.textPrimary)
        for range in ranges {
            if let attrRange = Range(range, in: result) {
                result[attrRange].foregroundColor = UIColor(highlightColor)
                result[attrRange].font = .systemFont(ofSize: 17, weight: .semibold)
            }
        }
        return Text(result)
    }
}

#Preview {
    ExercisePicker { _ in }
        .environment(AppState())
        .modelContainer(PersistenceController.previewContainer)
}
