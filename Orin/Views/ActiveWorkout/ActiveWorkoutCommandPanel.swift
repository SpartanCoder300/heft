// iOS 26+ only. No #available guards.

import SwiftData
import SwiftUI

// MARK: - Command Panel

struct ActiveWorkoutCommandPanel: View {
    let vm: ActiveWorkoutViewModel
    let theme: AccentTheme
    let onComplete: (WorkoutSession) -> Void
    let onDismiss: () -> Void

    @AppStorage("hasUsedSwipeControl") private var hasUsedSwipeControl: Bool = false
    @State private var isKeyboardVisible = false

    private let horizontalInset: CGFloat = Spacing.lg

    var body: some View {
        if vm.isAllSetsLogged {
            // ── Complete Workout ───────────────────────────────────────────────
            Button {
                if let session = vm.endWorkout() {
                    onComplete(session)
                } else {
                    onDismiss()
                }
            } label: {
                Label("Complete Workout", systemImage: "checkmark.circle.fill")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.OrinGreen)
                    .padding(.vertical, Spacing.md)
                    .padding(.horizontal, Spacing.xl)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: Radius.sheet, style: .continuous))
            .modifier(CommandPanelElevation(cornerRadius: Radius.sheet))
            .padding(.horizontal, horizontalInset)
            .padding(.bottom, Spacing.md)

        } else if let focus = vm.currentFocus,
                  vm.draftExercises.indices.contains(focus.exerciseIndex),
                  vm.draftExercises[focus.exerciseIndex].sets.indices.contains(focus.setIndex) {
            // ── Set editing card ───────────────────────────────────────────────
            let exercise = vm.draftExercises[focus.exerciseIndex]

            VStack(spacing: 0) {
                // Drag handle — visible only when keyboard is up, swipe down dismisses
                if isKeyboardVisible {
                    ZStack {
                        Color.clear.frame(height: 24)
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(Color.white.opacity(0.25))
                            .frame(width: 36, height: 4)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 10)
                            .onEnded { value in
                                guard value.translation.height > 20,
                                      abs(value.translation.height) > abs(value.translation.width) else { return }
                                UIApplication.shared.sendAction(
                                    #selector(UIResponder.resignFirstResponder),
                                    to: nil, from: nil, for: nil
                                )
                            }
                    )
                }

                // Row 1: Weight | Reps (or Duration for timed exercises)
                HStack(spacing: 0) {
                    if exercise.tracksWeight {
                        SwipeValueControl(
                            text: Binding(
                                get: {
                                    guard vm.draftExercises.indices.contains(focus.exerciseIndex),
                                          vm.draftExercises[focus.exerciseIndex].sets.indices.contains(focus.setIndex)
                                    else { return "" }
                                    return vm.draftExercises[focus.exerciseIndex].sets[focus.setIndex].weightText
                                },
                                set: {
                                    guard vm.draftExercises.indices.contains(focus.exerciseIndex),
                                          vm.draftExercises[focus.exerciseIndex].sets.indices.contains(focus.setIndex)
                                    else { return }
                                    vm.draftExercises[focus.exerciseIndex].sets[focus.setIndex].weightText = $0
                                }
                            ),
                            unit: "lbs",
                            step: exercise.weightIncrement,
                            minValue: 0,
                            maxValue: 999,
                            isInteger: false,
                            firstTapDefault: exercise.startingWeight,
                            milestones: weightMilestones(for: exercise.equipmentType),
                            onInteractionStart: { vm.requestRevealCurrentFocus(); hasUsedSwipeControl = true }
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                        Divider()
                    }

                    if exercise.isTimed {
                        SwipeValueControl(
                            text: Binding(
                                get: {
                                    guard vm.draftExercises.indices.contains(focus.exerciseIndex),
                                          vm.draftExercises[focus.exerciseIndex].sets.indices.contains(focus.setIndex)
                                    else { return "" }
                                    return vm.draftExercises[focus.exerciseIndex].sets[focus.setIndex].durationText
                                },
                                set: {
                                    guard vm.draftExercises.indices.contains(focus.exerciseIndex),
                                          vm.draftExercises[focus.exerciseIndex].sets.indices.contains(focus.setIndex)
                                    else { return }
                                    vm.draftExercises[focus.exerciseIndex].sets[focus.setIndex].durationText = $0
                                }
                            ),
                            unit: "sec",
                            step: 5,
                            minValue: 5,
                            maxValue: 600,
                            isInteger: true,
                            firstTapDefault: 30,
                            onInteractionStart: { vm.requestRevealCurrentFocus(); hasUsedSwipeControl = true }
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        SwipeValueControl(
                            text: Binding(
                                get: {
                                    guard vm.draftExercises.indices.contains(focus.exerciseIndex),
                                          vm.draftExercises[focus.exerciseIndex].sets.indices.contains(focus.setIndex)
                                    else { return "" }
                                    return vm.draftExercises[focus.exerciseIndex].sets[focus.setIndex].repsText
                                },
                                set: {
                                    guard vm.draftExercises.indices.contains(focus.exerciseIndex),
                                          vm.draftExercises[focus.exerciseIndex].sets.indices.contains(focus.setIndex)
                                    else { return }
                                    vm.draftExercises[focus.exerciseIndex].sets[focus.setIndex].repsText = $0
                                }
                            ),
                            unit: "reps",
                            step: 1,
                            minValue: 0,
                            maxValue: 50,
                            isInteger: true,
                            firstTapDefault: 5,
                            onInteractionStart: { vm.requestRevealCurrentFocus(); hasUsedSwipeControl = true }
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(height: 72)

                if !hasUsedSwipeControl {
                    Text("Swipe to adjust · Tap to type")
                        .font(.caption2)
                        .foregroundStyle(Color.textFaint.opacity(0.55))
                        .padding(.vertical, Spacing.xs)
                        .transition(.opacity)
                }

                Divider()

                Button {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil, from: nil, for: nil
                    )
                    vm.logFocusedSet()
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 15, weight: .bold))
                        Text("Log Set")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundStyle(theme.accentColor)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(height: 52)
            }
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
            .modifier(CommandPanelElevation(cornerRadius: Radius.large))
            .padding(.horizontal, horizontalInset)
            .padding(.bottom, Spacing.md)
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                withAnimation(.easeInOut(duration: 0.2)) { isKeyboardVisible = true }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                withAnimation(.easeInOut(duration: 0.2)) { isKeyboardVisible = false }
            }

        } else if !vm.draftExercises.isEmpty {
            // ── No focus — prompt user ─────────────────────────────────────────
            Text("Tap a set to edit")
                .font(.subheadline)
                .foregroundStyle(Color.textFaint)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.sm)
                .padding(.bottom, Spacing.md)
        }
    }
}

// MARK: - Helpers

private struct CommandPanelElevation: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.regularMaterial.opacity(0.22))
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.20),
                                Color.white.opacity(0.07)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            }
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.24),
                                Color.white.opacity(0.00)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1.5
                    )
                    .blur(radius: 0.2)
                    .mask(alignment: .top) {
                        Rectangle()
                            .frame(height: 18)
                    }
            }
            .shadow(color: Color.black.opacity(0.44), radius: 28, y: 18)
            .shadow(color: Color.black.opacity(0.30), radius: 9, y: 4)
    }
}

// MARK: - Previews

#Preview("Editing panel") {
    {
        let vm = ActiveWorkoutViewModel(
            modelContext: PersistenceController.previewContainer.mainContext,
            pendingRoutineID: nil
        )
        vm.addExercise(named: "Bench Press")
        vm.draftExercises[0].sets[0].weightText = "185"
        vm.draftExercises[0].sets[0].repsText = "5"
        return ActiveWorkoutCommandPanel(vm: vm, theme: .midnight, onComplete: { _ in }, onDismiss: {})
            .environment(\.OrinTheme, .midnight)
            .preferredColorScheme(.dark)
    }()
}

#Preview("Complete Workout") {
    {
        let vm = ActiveWorkoutViewModel(
            modelContext: PersistenceController.previewContainer.mainContext,
            pendingRoutineID: nil
        )
        vm.addExercise(named: "Bench Press")
        vm.draftExercises[0].sets[0].weightText = "185"
        vm.draftExercises[0].sets[0].repsText = "5"
        vm.draftExercises[0].sets[0].isLogged = true
        return ActiveWorkoutCommandPanel(vm: vm, theme: .midnight, onComplete: { _ in }, onDismiss: {})
            .environment(\.OrinTheme, .midnight)
            .preferredColorScheme(.dark)
    }()
}

#Preview("No focus") {
    {
        let vm = ActiveWorkoutViewModel(
            modelContext: PersistenceController.previewContainer.mainContext,
            pendingRoutineID: nil
        )
        // No exercises added — currentFocus is naturally nil
        return ActiveWorkoutCommandPanel(vm: vm, theme: .midnight, onComplete: { _ in }, onDismiss: {})
            .environment(\.OrinTheme, .midnight)
            .preferredColorScheme(.dark)
    }()
}

private func weightMilestones(for equipmentType: String) -> Set<Double>? {
    switch equipmentType {
    case "Barbell":
        // Standard plate combinations on a 45 lb bar
        return [45, 95, 135, 185, 225, 275, 315, 365, 405]
    case "Dumbbell":
        // Common dumbbell rack weights every 10 lbs
        return Set(stride(from: 10.0, through: 150.0, by: 10.0))
    case "Cable":
        // Cable stack landmarks every 20 lbs
        return Set(stride(from: 20.0, through: 300.0, by: 20.0))
    case "Machine":
        // Machine stack landmarks every 25 lbs
        return Set(stride(from: 25.0, through: 400.0, by: 25.0))
    case "Kettlebell":
        // Nearest multiples of 4 (the step size) to standard bell weights
        return [16, 28, 36, 44, 52, 60, 72, 88]
    default:
        return nil
    }
}
