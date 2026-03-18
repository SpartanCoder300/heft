// iOS 26+ only. No #available guards.

import SwiftUI
import SwiftData

struct ActiveWorkoutView: View {
    @State private var vm: ActiveWorkoutViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.heftTheme) private var theme

    init(modelContext: ModelContext, pendingRoutineID: UUID?) {
        _vm = State(initialValue: ActiveWorkoutViewModel(
            modelContext: modelContext,
            pendingRoutineID: pendingRoutineID
        ))
    }

    var body: some View {
        @Bindable var vm = vm

        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: Spacing.md) {
                        if vm.draftExercises.isEmpty {
                            EmptyWorkoutPrompt(accentColor: theme.accentColor) {
                                vm.isShowingExercisePicker = true
                            }
                        } else {
                            ActiveExerciseCard(vm: vm, exerciseIndex: vm.activeExerciseIndex, theme: theme)
                                .id("active")

                            if vm.draftExercises.count > 1 {
                                OtherExercisesSection(vm: vm, theme: theme)
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.lg)
                    .padding(.bottom, 88)
                }
                .onChange(of: vm.activeExerciseIndex) { _, _ in
                    withAnimation(Motion.standardSpring) {
                        proxy.scrollTo("active", anchor: .top)
                    }
                }
            }
            .themedBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("End") { vm.isShowingEndConfirm = true }
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.heftRed)
                }
                ToolbarItem(placement: .principal) {
                    TimelineView(.periodic(from: vm.openedAt, by: 1.0)) { ctx in
                        Text(vm.elapsedLabel(at: ctx.date))
                            .font(.system(size: 17, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Color.textPrimary)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button { vm.isShowingExercisePicker = true } label: {
                    Label("Add Exercise", systemImage: "plus")
                        .font(Typography.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(theme.accentColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.md)
                        .background(theme.accentColor.opacity(0.12), in: Capsule())
                        .overlay(Capsule().strokeBorder(theme.accentColor.opacity(0.3), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(.ultraThinMaterial)
            }
            .confirmationDialog(
                "End Workout?",
                isPresented: $vm.isShowingEndConfirm,
                titleVisibility: .visible
            ) {
                Button("End Workout", role: .destructive) {
                    vm.endWorkout()
                    dismiss()
                }
            } message: {
                Text(vm.isSessionStarted
                     ? "Your logged sets have been saved."
                     : "No sets logged — this session won't be saved.")
            }
            .sheet(isPresented: $vm.isShowingExercisePicker) {
                ExercisePicker { exercise in
                    vm.addExercise(named: exercise.name)
                }
            }
            .sheet(isPresented: $vm.isShowingRestTimer) {
                RestTimerSheet(restTimer: vm.restTimer, vm: vm)
                    .presentationDetents([.fraction(0.92)])
                    .presentationDragIndicator(.hidden)
                    .presentationCornerRadius(Radius.large)
                    .presentationBackground(.clear)
            }
            .onChange(of: vm.restTimer.isActive) { _, isActive in
                if isActive {
                    vm.isShowingRestTimer = true
                } else {
                    vm.isShowingRestTimer = false
                }
            }
        }
        .task { vm.setup() }
    }
}

// MARK: - Active Exercise Card

private struct ActiveExerciseCard: View {
    let vm: ActiveWorkoutViewModel
    let exerciseIndex: Int
    let theme: AccentTheme

    private var exercise: ActiveWorkoutViewModel.DraftExercise {
        vm.draftExercises[exerciseIndex]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Header ────────────────────────────────────────────────
            HStack(alignment: .center) {
                Text(exercise.exerciseName)
                    .font(Typography.heading)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                Menu {
                    Button("Remove Exercise", role: .destructive) {
                        vm.removeExercise(at: exerciseIndex)
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.textMuted)
                        .frame(width: 44, height: 36)
                        .contentShape(Rectangle())
                }
            }

            // ── Previous performance ───────────────────────────────────
            if !exercise.previousSets.isEmpty {
                Text("Last: \(previousLabel)")
                    .font(Typography.caption)
                    .foregroundStyle(Color.textFaint)
                    .padding(.top, 2)
            }

            // ── Column headers ────────────────────────────────────────
            HStack(spacing: Spacing.sm) {
                Text("SET").frame(width: 20, alignment: .center)
                Text("TYPE").frame(width: 30, alignment: .center)
                Text("WEIGHT").frame(maxWidth: .infinity)
                Text("REPS").frame(maxWidth: .infinity)
                Text("").frame(width: 36)
            }
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(Color.textFaint)
            .textCase(.uppercase)
            .tracking(0.5)
            .padding(.top, Spacing.md)

            // ── Set type legend ───────────────────────────────────────
            HStack(spacing: 0) {
                Spacer().frame(width: 20 + Spacing.sm)
                HStack(spacing: 5) {
                    Text("W").foregroundStyle(Color.heftAmber)
                    Text("warmup").foregroundStyle(Color.textFaint)
                    Text("·").foregroundStyle(Color.textFaint.opacity(0.4))
                    Text("N").foregroundStyle(Color.textFaint)
                    Text("normal").foregroundStyle(Color.textFaint)
                    Text("·").foregroundStyle(Color.textFaint.opacity(0.4))
                    Text("D").foregroundStyle(Color.heftAccentAbyss)
                    Text("drop").foregroundStyle(Color.textFaint)
                }
                .font(.system(size: 9, weight: .medium))
                Spacer()
            }
            .padding(.top, 3)
            .padding(.bottom, Spacing.xs)

            Divider().overlay(Color.white.opacity(0.08))

            // ── Set rows ──────────────────────────────────────────────
            ForEach(exercise.sets.indices, id: \.self) { sIdx in
                let isDropset = exercise.sets[sIdx].setType == .dropset
                let nextIsDropset = sIdx + 1 < exercise.sets.count
                    && exercise.sets[sIdx + 1].setType == .dropset

                SetRow(
                    setNumber: sIdx + 1,
                    weightText: Binding(
                        get: { vm.draftExercises[exerciseIndex].sets[sIdx].weightText },
                        set: { vm.draftExercises[exerciseIndex].sets[sIdx].weightText = $0 }
                    ),
                    repsText: Binding(
                        get: { vm.draftExercises[exerciseIndex].sets[sIdx].repsText },
                        set: { vm.draftExercises[exerciseIndex].sets[sIdx].repsText = $0 }
                    ),
                    setType: exercise.sets[sIdx].setType,
                    isDropset: isDropset,
                    isLogged: exercise.sets[sIdx].isLogged,
                    accentColor: theme.accentColor,
                    onCycleType: { vm.cycleSetType(exerciseIndex: exerciseIndex, setIndex: sIdx) },
                    onLog: { vm.logSet(exerciseIndex: exerciseIndex, setIndex: sIdx) }
                )

                // Suppress divider between a set and its chained dropset
                if sIdx < exercise.sets.count - 1 && !nextIsDropset {
                    Divider().overlay(Color.white.opacity(0.05))
                }
            }

            // ── Add Set ───────────────────────────────────────────────
            Button { vm.addSet(toExerciseAt: exerciseIndex) } label: {
                Label("Add Set", systemImage: "plus")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(theme.accentColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.sm)
            }
            .buttonStyle(.plain)
            .padding(.top, Spacing.xs)
        }
        .padding(Spacing.md)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
    }

    private var previousLabel: String {
        exercise.previousSets
            .map { "\(vm.formatWeight($0.weight))×\($0.reps)" }
            .joined(separator: "  ")
    }
}

// MARK: - Set Row

private struct SetRow: View {
    let setNumber: Int
    @Binding var weightText: String
    @Binding var repsText: String
    let setType: SetType
    let isDropset: Bool
    let isLogged: Bool
    let accentColor: Color
    let onCycleType: () -> Void
    let onLog: () -> Void

    var body: some View {
        HStack(spacing: Spacing.sm) {
            // Set number — dropsets show a chain indicator instead
            Text(isDropset ? "↳" : "\(setNumber)")
                .font(.system(size: isDropset ? 14 : 13, weight: .medium, design: .rounded))
                .foregroundStyle(isDropset ? Color.heftAccentAbyss.opacity(0.7) : Color.textFaint)
                .frame(width: 20, alignment: .center)

            // Set type chip
            SetTypeChip(setType: setType, onTap: isLogged ? nil : onCycleType)
                .frame(width: 30)

            // Weight adjuster
            FieldAdjuster(text: $weightText, step: 1, minValue: 0, maxValue: 999, isInteger: false, isLogged: isLogged)
                .frame(maxWidth: .infinity)

            // Reps adjuster
            FieldAdjuster(text: $repsText, step: 1, minValue: 0, maxValue: 50, isInteger: true, isLogged: isLogged)
                .frame(maxWidth: .infinity)

            // Log checkmark
            Button(action: onLog) {
                Image(systemName: isLogged ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isLogged ? Color.heftGreen : Color.textFaint)
            }
            .buttonStyle(.plain)
            .frame(width: 36)
            .disabled(isLogged)
        }
        .padding(.vertical, Spacing.sm)
        .padding(.leading, isDropset ? 10 : 0)
        .opacity(isLogged ? 0.55 : 1.0)
        .animation(Motion.standardSpring, value: isLogged)
    }
}

// MARK: - Field Adjuster (wheel + ± tappers)

private struct FieldAdjuster: View {
    @Binding var text: String
    let step: Double
    let minValue: Double
    let maxValue: Double
    let isInteger: Bool
    var isLogged: Bool = false

    @State private var showingWheel = false
    @State private var wheelValue: Double = 0

    private var current: Double { Double(text) ?? minValue }

    private var wheelValues: [Double] {
        stride(from: minValue, through: maxValue + 0.001, by: step).map { $0 }
    }

    private func snapped(_ v: Double) -> Double {
        let steps = ((v - minValue) / step).rounded()
        return Swift.min(maxValue, Swift.max(minValue, minValue + steps * step))
    }

    private func formatted(_ v: Double) -> String {
        if isInteger { return "\(Int(v.rounded()))" }
        let r = (v * 10).rounded() / 10
        return r.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(r))" : String(format: "%.1f", r)
    }

    var body: some View {
        VStack(spacing: 4) {
            // Value — tap to open wheel
            Button {
                guard !isLogged else { return }
                wheelValue = snapped(current)
                showingWheel = true
            } label: {
                Text(text.isEmpty ? "—" : formatted(current))
                    .font(.system(size: 19, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(isLogged ? Color.textFaint : Color.textPrimary)
                    .frame(minWidth: 54, minHeight: 28, alignment: .center)
            }
            .buttonStyle(.plain)

            // ± tappers
            if !isLogged {
                HStack(spacing: 0) {
                    Button {
                        text = formatted(snapped(current - step))
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.textMuted)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Button {
                        text = formatted(snapped(current + step))
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.textMuted)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .sheet(isPresented: $showingWheel) {
            WheelPickerSheet(
                value: $wheelValue,
                values: wheelValues,
                format: formatted,
                onDone: {
                    text = formatted(wheelValue)
                    showingWheel = false
                    UISelectionFeedbackGenerator().selectionChanged()
                },
                onCancel: { showingWheel = false }
            )
            .presentationDetents([.height(260)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(Radius.large)
        }
    }
}

// MARK: - Wheel Picker Sheet

private struct WheelPickerSheet: View {
    @Binding var value: Double
    let values: [Double]
    let format: (Double) -> String
    let onDone: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancel", action: onCancel)
                    .foregroundStyle(Color.textMuted)
                Spacer()
                Button("Done", action: onDone)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.xs)

            Picker("", selection: $value) {
                ForEach(values, id: \.self) { v in
                    Text(format(v)).tag(v)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 180)
        }
    }
}

// MARK: - Set Type Chip

private struct SetTypeChip: View {
    let setType: SetType
    var onTap: (() -> Void)?

    var body: some View {
        Button {
            onTap?()
        } label: {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(chipColor)
                .frame(width: 26, height: 22)
                .background(chipColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(onTap == nil)
        .sensoryFeedback(.selection, trigger: setType)
    }

    private var label: String {
        switch setType {
        case .normal:  "N"
        case .warmup:  "W"
        case .dropset: "D"
        }
    }

    private var chipColor: Color {
        switch setType {
        case .normal:  Color.textFaint
        case .warmup:  Color.heftAmber
        case .dropset: Color.heftAccentAbyss
        }
    }
}

// MARK: - Other Exercises Section

private struct OtherExercisesSection: View {
    let vm: ActiveWorkoutViewModel
    let theme: AccentTheme

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Exercises")
                .font(Typography.caption)
                .fontWeight(.semibold)
                .foregroundStyle(Color.textFaint)
                .textCase(.uppercase)
                .tracking(0.8)

            ForEach(vm.draftExercises.indices, id: \.self) { idx in
                if idx != vm.activeExerciseIndex {
                    ExerciseListRow(
                        exercise: vm.draftExercises[idx],
                        accentColor: theme.accentColor,
                        onTap: { vm.activeExerciseIndex = idx }
                    )
                }
            }
        }
    }
}

// MARK: - Exercise List Row

private struct ExerciseListRow: View {
    let exercise: ActiveWorkoutViewModel.DraftExercise
    let accentColor: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.exerciseName)
                        .font(Typography.body)
                        .foregroundStyle(Color.textPrimary)
                    Text(setsSummary)
                        .font(Typography.caption)
                        .foregroundStyle(Color.textFaint)
                }
                Spacer()
                // §11 exercise context menu — placeholder
                Menu {
                    Text("§11 — coming next")
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.textMuted)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var setsSummary: String {
        let total = exercise.sets.count
        let logged = exercise.sets.filter { $0.isLogged }.count
        return "\(total) sets · \(logged) logged"
    }
}

// MARK: - Empty Workout Prompt

private struct EmptyWorkoutPrompt: View {
    let accentColor: Color
    let onAddExercise: () -> Void

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: DesignTokens.Icon.placeholder))
                .foregroundStyle(accentColor)
            VStack(spacing: Spacing.xs) {
                Text("Ready when you are")
                    .font(Typography.title)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.textPrimary)
                Text("Add your first exercise to start logging.")
                    .font(Typography.caption)
                    .foregroundStyle(Color.textMuted)
                    .multilineTextAlignment(.center)
            }
            Button(action: onAddExercise) {
                Label("Add Exercise", systemImage: "plus")
                    .font(Typography.body)
                    .fontWeight(.semibold)
                    .foregroundStyle(accentColor)
                    .padding(.horizontal, Spacing.xl)
                    .padding(.vertical, Spacing.md)
                    .background(accentColor.opacity(0.12), in: Capsule())
                    .overlay(Capsule().strokeBorder(accentColor.opacity(0.3), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.xl)
        .padding(.top, Spacing.xxl)
    }
}

#Preview("Empty workout") {
    ActiveWorkoutView(
        modelContext: PersistenceController.previewContainer.mainContext,
        pendingRoutineID: nil
    )
    .environment(AppState())
    .modelContainer(PersistenceController.previewContainer)
}
