// iOS 26+ only. No #available guards.

import SwiftUI

struct HomeActiveWorkoutDashboard: View {
    let vm: ActiveWorkoutViewModel
    let sessionNumber: Int
    let onResume: () -> Void

    @Environment(\.ryftTheme) private var theme
    @Environment(\.ryftCardMaterial) private var cardMaterial

    // MARK: - Computed

    private var totalSets: Int {
        vm.draftExercises.reduce(0) { $0 + $1.sets.count }
    }

    private var progress: Double {
        guard totalSets > 0 else { return 0 }
        return Double(vm.loggedSetCount) / Double(totalSets)
    }

    private var sessionVolume: Double {
        vm.draftExercises.flatMap { $0.sets }
            .compactMap { $0.loggedRecord }
            .reduce(0) { $0 + $1.weight * Double($1.reps) }
    }

    private var volumeLabel: String {
        let v = sessionVolume
        guard v > 0 else { return "No sets logged yet" }
        return v >= 1_000
            ? String(format: "%.1fk lbs", v / 1_000)
            : "\(Int(v)) lbs"
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            progressBar
            Divider().opacity(0.2)
            exerciseList
            Divider().opacity(0.2)
            footer
        }
        .background(cardMaterial, in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
        .proGlass()
        .onTapGesture { onResume() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(vm.routineName)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(sessionNumber > 0
                     ? "\(vm.loggedSetCount) of \(totalSets) sets  ·  Session \(sessionNumber)"
                     : "\(vm.loggedSetCount) of \(totalSets) sets")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            TimelineView(.periodic(from: .now, by: 1.0)) { ctx in
                let _ = vm.restTimer.tick(at: ctx.date)
                Group {
                    if vm.restTimer.isActive,
                       let label = vm.restTimer.remainingLabel(at: ctx.date) {
                        let nearDone = (vm.restTimer.progress(at: ctx.date) ?? 1) <= 0.2
                        Text("REST \(label)")
                            .foregroundStyle(nearDone ? theme.accentColor : .secondary)
                    } else {
                        Text(vm.elapsedLabel(at: ctx.date))
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.system(.title3, design: .monospaced).weight(.medium))
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.2), value: vm.restTimer.isActive)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm + 2)
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.white.opacity(0.06))
                Rectangle()
                    .fill(theme.accentColor.opacity(0.55))
                    .frame(width: geo.size.width * progress)
                    .animation(.easeInOut(duration: 0.4), value: progress)
            }
        }
        .frame(height: 2)
    }

    // MARK: - Exercise List

    private var exerciseList: some View {
        VStack(spacing: 0) {
            ForEach(Array(vm.draftExercises.enumerated()), id: \.element.id) { idx, exercise in
                exerciseRow(exercise: exercise, index: idx)
                if idx < vm.draftExercises.count - 1 {
                    Divider()
                        .opacity(0.08)
                        .padding(.leading, Spacing.md)
                }
            }
        }
    }

    @ViewBuilder
    private func exerciseRow(exercise: ActiveWorkoutViewModel.DraftExercise, index: Int) -> some View {
        let isCurrent = vm.currentFocus?.exerciseIndex == index
        let loggedCount = exercise.sets.filter { $0.isLogged }.count
        let isDone = loggedCount == exercise.sets.count && !exercise.sets.isEmpty
        let bestPrev = exercise.previousSets.filter { $0.weight > 0 }.max(by: { $0.weight < $1.weight })

        HStack(spacing: Spacing.sm) {
            // Current-exercise indicator
            Circle()
                .fill(isCurrent ? theme.accentColor : Color.clear)
                .frame(width: 6, height: 6)

            Text(exercise.exerciseName)
                .font(.subheadline.weight(isCurrent ? .semibold : .regular))
                .foregroundStyle(isCurrent ? .primary : isDone ? .tertiary : .secondary)
                .lineLimit(1)

            Spacer()

            if let best = bestPrev {
                Text(prevWeightLabel(best))
                    .font(.caption2)
                    .foregroundStyle(.quaternary)
            }

            // Set dots
            HStack(spacing: 4) {
                ForEach(Array(exercise.sets.enumerated()), id: \.offset) { _, set in
                    Circle()
                        .fill(set.isLogged ? theme.accentColor : Color.white.opacity(0.15))
                        .frame(width: 7, height: 7)
                }
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, 10)
    }

    private func prevWeightLabel(_ set: ActiveWorkoutViewModel.PreviousSet) -> String {
        set.weight.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(set.weight)) lbs"
            : String(format: "%.1f lbs", set.weight)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Text(volumeLabel)
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
            if vm.isAllSetsLogged {
                Text("All sets done · Finish workout →")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.accentColor)
            } else {
                Text("Open →")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
    }
}

// MARK: - Preview

#Preview {
    {
        let vm = ActiveWorkoutViewModel(
            modelContext: PersistenceController.previewContainer.mainContext,
            pendingRoutineID: nil
        )
        vm.addExercise(named: "Bench Press")
        vm.addExercise(named: "Squat")
        vm.addExercise(named: "Romanian Deadlift")
        vm.addSet(toExerciseAt: 0)
        vm.addSet(toExerciseAt: 0)
        vm.draftExercises[0].sets[0].isLogged = true
        vm.draftExercises[0].sets[1].isLogged = true
        vm.draftExercises[1].sets[0].isLogged = true
        return NavigationStack {
            ScrollView {
                HomeActiveWorkoutDashboard(vm: vm, sessionNumber: 3, onResume: {})
                    .padding(.horizontal, Spacing.md)
                    .padding(.top, Spacing.lg)
            }
        }
        .environment(\.ryftTheme, .midnight)
        .environment(\.ryftCardMaterial, .regularMaterial)
        .preferredColorScheme(.dark)
    }()
}
