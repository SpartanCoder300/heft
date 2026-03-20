// iOS 26+ only. No #available guards.

import SwiftUI

/// Horizontal inline stepper: [−] value [+] with wheel-picker on value tap.
struct CompactStepper: View {
    @Binding var text: String
    let unit: String
    let step: Double
    let minValue: Double
    let maxValue: Double
    let isInteger: Bool
    var isLogged: Bool = false
    /// When set, the first + tap on a blank field jumps here instead of minValue + step.
    var firstTapDefault: Double? = nil

    @State private var showingWheel = false
    @State private var wheelValue: Double = 0

    private var current: Double { Double(text) ?? minValue }

    /// Wheel always offers 1-unit increments for fine control.
    private var wheelValues: [Double] {
        stride(from: minValue, through: maxValue, by: step).map { $0 }
    }

    private func snapped(_ v: Double) -> Double {
        let steps = ((v - minValue) / step).rounded()
        return Swift.min(maxValue, Swift.max(minValue, minValue + steps * step))
    }

    func formatted(_ v: Double) -> String {
        if isInteger { return "\(Int(v.rounded()))" }
        let r = (v * 10).rounded() / 10
        return r.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(r))" : String(format: "%.1f", r)
    }

    var body: some View {
        HStack(spacing: 0) {
            // Minus
            Button {
                text = formatted(snapped(current - step))
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.textMuted)
                    .frame(width: 44, height: 52)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isLogged)

            // Value — tap to open wheel
            Button {
                wheelValue = snapped(current)
                showingWheel = true
            } label: {
                VStack(spacing: 2) {
                    Text(text.isEmpty ? "—" : formatted(current))
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                        .contentTransition(.numericText())
                        .animation(Motion.standardSpring, value: text)
                    Text(unit)
                        .font(.system(size: 11, weight: .medium))
                        .textCase(.uppercase)
                        .tracking(0.4)
                        .opacity(0.5)
                }
                .foregroundStyle(Color.textPrimary)
                .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(.plain)
            .disabled(isLogged)

            // Plus
            Button {
                if text.isEmpty, let jumpTo = firstTapDefault {
                    text = formatted(jumpTo)
                } else {
                    text = formatted(snapped(current + step))
                }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.textMuted)
                    .frame(width: 44, height: 52)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isLogged)
        }
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .opacity(isLogged ? 0.4 : 1.0)
        .sheet(isPresented: $showingWheel) {
            VStack(spacing: 0) {
                // Drag indicator
                Capsule()
                    .fill(Color.primary.opacity(0.2))
                    .frame(width: 36, height: 4)
                    .padding(.top, 8)

                Picker(unit, selection: $wheelValue) {
                    ForEach(wheelValues, id: \.self) { v in
                        Text(formatted(v)).tag(v)
                    }
                }
                .pickerStyle(.wheel)
                .onChange(of: wheelValue) { _, v in
                    text = formatted(v)
                    UISelectionFeedbackGenerator().selectionChanged()
                }
            }
            .presentationDetents([.height(220)])
            .presentationDragIndicator(.hidden)
            .presentationCornerRadius(Radius.large)
            .presentationBackground(.regularMaterial)
        }
    }
}

// MARK: - Previews

#Preview("Weight stepper") {
    @Previewable @State var weight = "135"
    CompactStepper(text: $weight, unit: "lbs", step: 2.5, minValue: 0, maxValue: 999, isInteger: false)
        .padding()
}

#Preview("Reps stepper") {
    @Previewable @State var reps = "8"
    CompactStepper(text: $reps, unit: "reps", step: 1, minValue: 0, maxValue: 50, isInteger: true)
        .padding()
}

#Preview("Logged state") {
    @Previewable @State var weight = "135"
    CompactStepper(text: $weight, unit: "lbs", step: 2.5, minValue: 0, maxValue: 999, isInteger: false, isLogged: true)
        .padding()
}
