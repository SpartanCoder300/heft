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

    @State private var showingWheel = false
    @State private var wheelValue: Double = 0

    private var current: Double { Double(text) ?? minValue }

    /// Wheel always offers 1-unit increments for fine control.
    private var wheelValues: [Double] {
        stride(from: minValue, through: maxValue, by: 1).map { $0 }
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
                    .frame(width: 38, height: 52)
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
                        .contentTransition(.numericText())
                        .animation(Motion.standardSpring, value: text)
                    Text(unit)
                        .font(.system(size: 9, weight: .medium))
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
                text = formatted(snapped(current + step))
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.textMuted)
                    .frame(width: 38, height: 52)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isLogged)
        }
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
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
