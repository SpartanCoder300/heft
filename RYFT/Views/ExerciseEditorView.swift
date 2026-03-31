// iOS 26+ only. No #available guards.

import SwiftUI
import SwiftData

private let editorEquipmentTypes = ["Barbell", "Dumbbell", "Cable", "Machine", "Kettlebell", "Bodyweight", "Band"]
private let editorMuscleGroups   = ["Chest", "Back", "Shoulders", "Biceps", "Triceps", "Forearms", "Legs", "Core"]

struct ExerciseEditorView: View {
    /// Pass an existing exercise to edit, or nil to create a new custom one.
    let exercise: ExerciseDefinition?
    var allowsLifecycleActions: Bool = true

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.ryftTheme) private var theme

    @Query(sort: \ExerciseDefinition.name) private var allExercises: [ExerciseDefinition]

    @State private var name = ""
    @State private var equipmentType = "Barbell"
    @State private var selectedGroups: Set<String> = []
    @State private var loadTrackingMode: LoadTrackingMode = .externalWeight
    @State private var isTimed = false
    @State private var weightIncrementText = ""
    @State private var startingWeightText = ""
    @State private var saveErrorMessage: String? = nil
    @State private var showingArchiveConfirmation = false
    @State private var showingPermanentDeleteConfirmation = false

    private var isNew: Bool { exercise == nil }
    private var canEditName: Bool { exercise?.isCustom ?? true }
    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var nameError: String? {
        guard canEditName else { return nil }
        guard !trimmedName.isEmpty else { return "Enter an exercise name." }
        guard !hasActiveDuplicateName else { return "An exercise with this name already exists." }
        if !isNew, archivedMatch != nil {
            return "An archived exercise already uses this name. Restore it instead."
        }
        return nil
    }
    private var weightIncrementError: String? {
        guard loadTrackingMode != .none else { return nil }
        guard !weightIncrementText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        guard parsedNumber(from: weightIncrementText) != nil else { return "Enter a valid number." }
        return nil
    }
    private var startingWeightError: String? {
        guard loadTrackingMode != .none else { return nil }
        guard !startingWeightText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        guard parsedNumber(from: startingWeightText) != nil else { return "Enter a valid number." }
        return nil
    }
    private var formErrorMessage: String? { nameError ?? weightIncrementError ?? startingWeightError }
    private var isSaveEnabled: Bool { formErrorMessage == nil }
    private var activeMatch: ExerciseDefinition? {
        guard canEditName else { return nil }
        return allExercises.first { existing in
            guard existing.persistentModelID != exercise?.persistentModelID else { return false }
            guard !existing.isArchived else { return false }
            return existing.name.compare(trimmedName, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }
    }
    private var archivedMatch: ExerciseDefinition? {
        guard canEditName else { return nil }
        return allExercises.first { existing in
            guard existing.persistentModelID != exercise?.persistentModelID else { return false }
            guard existing.isArchived else { return false }
            return existing.name.compare(trimmedName, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }
    }
    private var hasActiveDuplicateName: Bool { activeMatch != nil }
    private var canManageLifecycle: Bool { allowsLifecycleActions && (exercise?.isCustom ?? false) }

    var body: some View {
        NavigationStack {
            Form {

                // ── Name ──────────────────────────────────────────────
                Section {
                    TextField("Exercise name", text: $name)
                        .autocorrectionDisabled()
                        .disabled(!canEditName)
                } header: {
                    Text("Name")
                } footer: {
                    if let error = nameError, canEditName {
                        Text(error)
                    } else if isNew, archivedMatch != nil {
                        Text("Saving will restore the archived exercise and keep its history.")
                    } else if let ex = exercise, !ex.isCustom {
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

                if canManageLifecycle {
                    Section {
                        Button(role: .destructive) {
                            showingArchiveConfirmation = true
                        } label: {
                            Label("Archive Exercise", systemImage: "archivebox")
                        }
                    } footer: {
                        Text("Removes this exercise from your library and picker, but keeps its history and lets you restore it later by reusing the same name.")
                    }

                    Section {
                        Button(role: .destructive) {
                            showingPermanentDeleteConfirmation = true
                        } label: {
                            Label("Delete Exercise and History", systemImage: "trash")
                        }
                    } footer: {
                        Text("Permanently deletes this exercise, its history, and any routine references. This cannot be undone.")
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
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(!isSaveEnabled)
                }
            }
        }
        .onAppear { populateDraft() }
        .alert("Couldn’t Save Exercise", isPresented: saveErrorIsPresented) {
            Button("OK", role: .cancel) {
                saveErrorMessage = nil
            }
        } message: {
            Text(saveErrorMessage ?? "Please review your changes and try again.")
        }
        .alert("Archive Exercise?", isPresented: $showingArchiveConfirmation) {
            Button("Archive", role: .destructive) {
                archiveExercise()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the exercise from your library without deleting any workout history.")
        }
        .alert("Delete Exercise and History?", isPresented: $showingPermanentDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                permanentlyDeleteExercise()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes the exercise definition, its workout history, and any routine references.")
        }
    }

    // MARK: - Chip grid

    @ViewBuilder
    private func chipGrid(
        items: [String],
        selected: @escaping (String) -> Bool,
        onTap: @escaping (String) -> Void
    ) -> some View {
        let columns = [GridItem(.adaptive(minimum: 92), spacing: Spacing.xs)]
        LazyVGrid(columns: columns, spacing: Spacing.xs) {
            ForEach(items, id: \.self) { item in
                let isSelected = selected(item)
                Button { onTap(item) } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .imageScale(.small)
                            .foregroundStyle(isSelected ? theme.accentColor : Color.textFaint)
                        Text(item)
                            .font(.footnote.weight(isSelected ? .semibold : .regular))
                            .foregroundStyle(Color.textPrimary)
                            .multilineTextAlignment(.center)
                    }
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 36)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: Capsule())
                .overlay {
                    Capsule()
                        .strokeBorder(isSelected ? theme.accentColor.opacity(0.45) : Color.white.opacity(0.08), lineWidth: 1)
                }
                .accessibilityLabel(item)
                .accessibilityValue(isSelected ? "Selected" : "Not selected")
                .accessibilityAddTraits(isSelected ? .isSelected : [])
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
        guard nameError == nil else {
            saveErrorMessage = nameError
            return
        }
        let increment = validatedOptionalNumber(from: weightIncrementText, fieldName: "Weight Increment")
        let startingWeight = validatedOptionalNumber(from: startingWeightText, fieldName: "Starting Weight")
        guard increment.isValid, startingWeight.isValid else {
            return
        }
        let orderedGroups = editorMuscleGroups.filter { selectedGroups.contains($0) }

        if let ex = exercise {
            let previousName = ex.name
            if ex.isCustom {
                ex.name = trimmedName
                attachHistory(to: ex, matchingLegacyName: previousName)
            }
            ex.equipmentType = equipmentType
            ex.muscleGroups = orderedGroups
            ex.loadTrackingMode = loadTrackingMode
            ex.isTimed = isTimed
            ex.weightIncrement = increment.value
            ex.startingWeight = startingWeight.value
            ex.archivedAt = nil
            // Mark edited if values differ from the seed
            if !ex.isCustom {
                let original = ExerciseSeeder.defaultDefinition(named: ex.name)
                let matchesDefault = original.map {
                    $0.equipmentType == equipmentType &&
                    Set($0.muscleGroups) == selectedGroups &&
                    $0.loadTrackingMode == loadTrackingMode &&
                    $0.isTimed == isTimed &&
                    increment.value == $0.weightIncrement &&
                    startingWeight.value == $0.startingWeight
                } ?? false
                ex.isEdited = !matchesDefault
            }
        } else {
            if let archived = archivedMatch {
                archived.name = trimmedName
                archived.archivedAt = nil
                archived.equipmentType = equipmentType
                archived.muscleGroups = orderedGroups
                archived.loadTrackingMode = loadTrackingMode
                archived.isTimed = isTimed
                archived.weightIncrement = increment.value
                archived.startingWeight = startingWeight.value
                attachHistory(to: archived, matchingLegacyName: trimmedName)
            } else {
                let newEx = ExerciseDefinition(
                    name: trimmedName,
                    muscleGroups: orderedGroups,
                    equipmentType: equipmentType,
                    isCustom: true,
                    weightIncrement: increment.value,
                    startingWeight: startingWeight.value,
                    loadTrackingMode: loadTrackingMode,
                    isTimed: isTimed
                )
                modelContext.insert(newEx)
            }
        }
        do {
            try modelContext.save()
            dismiss()
        } catch {
            saveErrorMessage = "Your changes couldn’t be saved. Please try again."
        }
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

    private func attachHistory(to exercise: ExerciseDefinition, matchingLegacyName legacyName: String? = nil) {
        let snapshots = (try? modelContext.fetch(FetchDescriptor<ExerciseSnapshot>())) ?? []
        let names = Set([exercise.name, legacyName].compactMap { $0 })
        for snapshot in snapshots {
            if snapshot.exerciseLineageID == exercise.id || (snapshot.exerciseLineageID == nil && names.contains(snapshot.exerciseName)) {
                snapshot.exerciseLineageID = exercise.id
            }
        }
    }

    private func archiveExercise() {
        guard let exercise, canManageLifecycle else { return }
        exercise.archivedAt = .now
        do {
            try modelContext.save()
            dismiss()
        } catch {
            saveErrorMessage = "This exercise couldn’t be archived. Please try again."
        }
    }

    private func permanentlyDeleteExercise() {
        guard let exercise, canManageLifecycle else { return }
        let snapshots = (try? modelContext.fetch(FetchDescriptor<ExerciseSnapshot>())) ?? []
        for snapshot in snapshots where snapshot.exerciseLineageID == exercise.id
            || (snapshot.exerciseLineageID == nil && snapshot.exerciseName == exercise.name) {
            modelContext.delete(snapshot)
        }

        let routineEntries = (try? modelContext.fetch(FetchDescriptor<RoutineEntry>())) ?? []
        for entry in routineEntries where entry.exerciseDefinition?.id == exercise.id {
            modelContext.delete(entry)
        }

        modelContext.delete(exercise)

        do {
            try modelContext.save()
            dismiss()
        } catch {
            saveErrorMessage = "This exercise couldn’t be deleted. Please try again."
        }
    }

    private func parsedNumber(from text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let decimal = Decimal(string: trimmed, locale: .current) else { return nil }
        return NSDecimalNumber(decimal: decimal).doubleValue
    }

    private func validatedOptionalNumber(from text: String, fieldName: String) -> (isValid: Bool, value: Double?) {
        guard loadTrackingMode != .none else { return (true, nil) }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return (true, nil) }
        guard let value = parsedNumber(from: trimmed) else {
            saveErrorMessage = "\(fieldName) must be a valid number."
            return (false, nil)
        }
        return (true, value)
    }

    private var saveErrorIsPresented: Binding<Bool> {
        Binding(
            get: { saveErrorMessage != nil },
            set: { isPresented in
                if !isPresented { saveErrorMessage = nil }
            }
        )
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
