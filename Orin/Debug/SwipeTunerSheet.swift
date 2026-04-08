// iOS 26+ only. No #available guards.
// Hidden developer tuning panel — not user-facing.

import SwiftUI

struct SwipeTunerSheet: View {
    private let tuner = SwipeTuningManager.shared

    var body: some View {
        NavigationStack {
            Form {
                Section("Drag Feel") {
                    LabeledSlider(
                        label: "Weight pts/step",
                        value: Binding(get: { tuner.config.weightPointsPerStep },
                                       set: { v in tuner.update { $0.weightPointsPerStep = v } }),
                        range: 4...40, format: "%.0f"
                    )
                    LabeledSlider(
                        label: "Reps pts/step",
                        value: Binding(get: { tuner.config.repsPointsPerStep },
                                       set: { v in tuner.update { $0.repsPointsPerStep = v } }),
                        range: 4...40, format: "%.0f"
                    )
                    LabeledSlider(
                        label: "Activation threshold",
                        value: Binding(get: { tuner.config.dragActivationThreshold },
                                       set: { v in tuner.update { $0.dragActivationThreshold = v } }),
                        range: 1...20, format: "%.0f"
                    )
                    LabeledSlider(
                        label: "Lift amount",
                        value: Binding(get: { tuner.config.activeLiftAmount },
                                       set: { v in tuner.update { $0.activeLiftAmount = v } }),
                        range: 0...80, format: "%.0f"
                    )
                }

                Section("Momentum") {
                    Toggle(
                        "Enabled",
                        isOn: Binding(get: { tuner.config.momentumEnabled },
                                      set: { v in tuner.update { $0.momentumEnabled = v } })
                    )
                    LabeledSlider(
                        label: "Velocity threshold (pt/s)",
                        value: Binding(get: { tuner.config.momentumVelocityThreshold },
                                       set: { v in tuner.update { $0.momentumVelocityThreshold = v } }),
                        range: 200...2000, format: "%.0f"
                    )
                    LabeledIntStepper(
                        label: "Weight max steps",
                        value: Binding(get: { tuner.config.weightMaxMomentumSteps },
                                       set: { v in tuner.update { $0.weightMaxMomentumSteps = v } }),
                        range: 1...12
                    )
                    LabeledIntStepper(
                        label: "Reps max steps",
                        value: Binding(get: { tuner.config.repsMaxMomentumSteps },
                                       set: { v in tuner.update { $0.repsMaxMomentumSteps = v } }),
                        range: 1...12
                    )
                    LabeledSlider(
                        label: "Duration (s)",
                        value: Binding(get: { CGFloat(tuner.config.momentumDuration) },
                                       set: { v in tuner.update { $0.momentumDuration = Double(v) } }),
                        range: 0.05...0.5, format: "%.2f"
                    )
                }

                Section {
                    Button(role: .destructive) {
                        tuner.reset()
                    } label: {
                        Label("Reset to Defaults", systemImage: "arrow.uturn.backward")
                    }
                }
            }
            .navigationTitle("Swipe Tuner")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Helpers

private struct LabeledSlider: View {
    let label: String
    @Binding var value: CGFloat
    let range: ClosedRange<CGFloat>
    let format: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.subheadline)
                Spacer()
                Text(String(format: format, value))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(value: $value, in: range)
        }
        .padding(.vertical, 2)
    }
}

private struct LabeledIntStepper: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        Stepper("\(label): \(value)", value: $value, in: range)
    }
}
