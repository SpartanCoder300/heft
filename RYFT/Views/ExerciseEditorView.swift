// iOS 26+ only. No #available guards.

import SwiftUI
import SwiftData

private let editorEquipmentTypes = ["Barbell", "Dumbbell", "Cable", "Machine", "Kettlebell", "Bodyweight", "Band"]
private let editorMuscleGroups   = ["Chest", "Back", "Shoulders", "Biceps", "Triceps", "Forearms", "Legs", "Core"]

struct ExerciseEditorView: View {
    /// Pass an existing exercise to edit, or nil to create a new custom one.
    let exercise: ExerciseDefinition?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.ryftTheme) private var theme

    @State private var name = ""
    @State private var equipmentType = "Barbell"
    @State private var selectedGroups: Set<String> = []
    @State private var loadTrackingMode: LoadTrackingMode = .externalWeight
    @State private var isTimed = false
    @State private var weightIncrementText = ""
    @State private var startingWeightText = ""

    private var isNew: Bool { exercise == nil }
    private var isSaveEnabled: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {

                // ── Name ──────────────────────────────────────────────
                Section {
                    TextField("Exercise name", text: $name)
                        .autocorrectionDisabled()
                        .disabled(!(exercise?.isCustom ?? true))
                } header: {
                    Text("Name")
                } footer: {
                    if let ex = exercise, !ex.isCustom {
                        Text("Name cannot be changed for built-in exercises.")
                    }
                }

                // ── Equipment ─────────────────────────────────────────
                Section("Equipment") {
                    chipGrid(items: editorEquipmentTypes, selected: { equipmentType == $0 }) {
                        equipmentType = $0
                    }
                }

                // ── Muscle Groups ─────────────────────────────────────
                Section("Muscle Groups") {
                    chipGrid(
                        items: editorMuscleGroups,
                        selected: { selectedGroups.contains($0) }
                    ) { group in
                        if selectedGroups.contains(group) {
                            selectedGroups.remove(group)
                        } else {
                            selectedGroups.insert(group)
                        }
                    }
                }

                Section {
                    Picker("Load Tracking", selection: $loadTrackingMode) {
                        Text("No Weight").tag(LoadTrackingMode.none)
                        Text("External Weight").tag(LoadTrackingMode.externalWeight)
                        Text("Bodyweight + Load").tag(LoadTrackingMode.bodyweightPlusLoad)
                    }
                    .pickerStyle(.menu)
                } header: {
                    Text("Load Tracking")
                } footer: {
                    Text(loadTrackingFooter)
                }

                // ── Type ──────────────────────────────────────────────
                Section {
                    Toggle("Timed (holds / isometric)", isOn: $isTimed)
                }

                // ── Weight Increment ──────────────────────────────────
                if loadTrackingMode != .none {
                    let defaultIncrement = ExerciseDefinition.defaultIncrement(for: equipmentType)
                    let defaultStartingWeight = ExerciseDefinition.defaultStartingWeight(for: equipmentType)
                    Section {
                        TextField(
                            "Default: \(formatIncrement(defaultIncrement)) lbs",
                            text: $weightIncrementText
                        )
                        .keyboardType(.decimalPad)
                    } header: {
                        Text("Weight Increment (lbs)")
                    } footer: {
                        Text("Leave blank to use the equipment default (\(formatIncrement(defaultIncrement)) lbs).")
                    }

                    Section {
                        TextField(
                            "Default: \(formatIncrement(defaultStartingWeight)) lbs",
                            text: $startingWeightText
                        )
                        .keyboardType(.decimalPad)
                    } header: {
                        Text("Starting Weight (lbs)")
                    } footer: {
                        Text("Used when a blank set gets its first weight value. Leave blank to use the equipment default (\(formatIncrement(defaultStartingWeight)) lbs).")
                    }
                }

                // ── Reset to Default ──────────────────────────────────
                if let ex = exercise, ex.isEdited, !ex.isCustom {
                    Section {
                        Button(role: .destructive) {
                            resetToDefault(ex)
                        } label: {
                            Label("Reset to Default", systemImage: "arrow.uturn.backward")
                        }
                    } footer: {
                        Text("Restores the original muscle groups, equipment, load tracking, type, increment, and starting weight.")
                    }
                }
            }
            .navigationTitle(isNew ? "New Exercise" : "Edit Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save(); dismiss() }
                        .fontWeight(.semibold)
                        .disabled(!isSaveEnabled)
                }
            }
        }
        .onAppear { populateDraft() }
    }

    // MARK: - Chip grid

    @ViewBuilder
    private func chipGrid(
        items: [String],
        selected: @escaping (String) -> Bool,
        onTap: @escaping (String) -> Void
    ) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: Spacing.xs), count: 4)
        LazyVGrid(columns: columns, spacing: Spacing.xs) {
            ForEach(items, id: \.self) { item in
                let isSelected = selected(item)
                Button { onTap(item) } label: {
                    Text(item)
                        .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? theme.accentColor : Color.textMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: Capsule())
            }
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: Spacing.sm, leading: Spacing.md, bottom: Spacing.sm, trailing: Spacing.md))
    }

    // MARK: - Helpers

    private func populateDraft() {
        guard let ex = exercise else { return }
        name = ex.name
        equipmentType = ex.equipmentType.isEmpty ? "Barbell" : ex.equipmentType
        selectedGroups = Set(ex.muscleGroups)
        loadTrackingMode = ex.loadTrackingMode
        isTimed = ex.isTimed
        weightIncrementText = ex.weightIncrement.map { formatIncrement($0) } ?? ""
        startingWeightText = ex.startingWeight.map { formatIncrement($0) } ?? ""
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let orderedGroups = editorMuscleGroups.filter { selectedGroups.contains($0) }
        let increment = loadTrackingMode == .none ? nil : Double(weightIncrementText)
        let startingWeight = loadTrackingMode == .none ? nil : Double(startingWeightText)

        if let ex = exercise {
            if ex.isCustom { ex.name = trimmedName }
            ex.equipmentType = equipmentType
            ex.muscleGroups = orderedGroups
            ex.loadTrackingMode = loadTrackingMode
            ex.isTimed = isTimed
            ex.weightIncrement = increment
            ex.startingWeight = startingWeight
            // Mark edited if values differ from the seed
            if !ex.isCustom {
                let original = ExerciseSeeder.defaultDefinition(named: ex.name)
                let matchesDefault = original.map {
                    $0.equipmentType == equipmentType &&
                    Set($0.muscleGroups) == selectedGroups &&
                    $0.loadTrackingMode == loadTrackingMode &&
                    $0.isTimed == isTimed &&
                    increment == $0.weightIncrement &&
                    startingWeight == $0.startingWeight
                } ?? false
                ex.isEdited = !matchesDefault
            }
        } else {
            let newEx = ExerciseDefinition(
                name: trimmedName,
                muscleGroups: orderedGroups,
                equipmentType: equipmentType,
                isCustom: true,
                weightIncrement: increment,
                startingWeight: startingWeight,
                loadTrackingMode: loadTrackingMode,
                isTimed: isTimed
            )
            modelContext.insert(newEx)
        }
        try? modelContext.save()
    }

    private func resetToDefault(_ ex: ExerciseDefinition) {
        guard let original = ExerciseSeeder.defaultDefinition(named: ex.name) else { return }
        if !ex.isCustom { ex.name = original.name }
        ex.equipmentType = original.equipmentType
        ex.muscleGroups = original.muscleGroups
        ex.loadTrackingMode = original.loadTrackingMode
        ex.isTimed = original.isTimed
        ex.weightIncrement = original.weightIncrement
        ex.startingWeight = original.startingWeight
        ex.isEdited = false
        try? modelContext.save()
        // Refresh draft to reflect restored values
        equipmentType = original.equipmentType
        selectedGroups = Set(original.muscleGroups)
        loadTrackingMode = original.loadTrackingMode
        isTimed = original.isTimed
        weightIncrementText = original.weightIncrement.map { formatIncrement($0) } ?? ""
        startingWeightText = original.startingWeight.map { formatIncrement($0) } ?? ""
    }

    private func formatIncrement(_ v: Double) -> String {
        v.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(v))" : String(format: "%.1f", v)
    }

    private var loadTrackingFooter: String {
        switch loadTrackingMode {
        case .none:
            return "Use this for plain bodyweight or duration-only movements that should not show weight controls."
        case .externalWeight:
            return "Tracks only the external load, like barbells, dumbbells, cables, and machines."
        case .bodyweightPlusLoad:
            return "Tracks added load on top of bodyweight, like weighted dips or weighted pull-ups."
        }
    }
}

#Preview("Edit existing") {
    let ex = ExerciseDefinition(name: "Barbell Bench Press", muscleGroups: ["Chest", "Triceps"], equipmentType: "Barbell")
    ExerciseEditorView(exercise: ex)
        .environment(AppState())
        .modelContainer(PersistenceController.previewContainer)
}

#Preview("New exercise") {
    ExerciseEditorView(exercise: nil)
        .environment(AppState())
        .modelContainer(PersistenceController.previewContainer)
}
