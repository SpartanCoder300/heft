// iOS 26+ only. No #available guards.

import SwiftUI
import UIKit

// MARK: - Swipe Value Engine

/// Pure math: converts drag translation into a stepped, clamped value.
struct SwipeValueEngine {
    let step: Double
    let minValue: Double
    let maxValue: Double
    /// Points of horizontal drag required to change by one step.
    var pixelsPerStep: Double = 14
    func steppedValue(startValue: Double, translation: CGFloat) -> Double {
        let steps = stepCount(from: translation)
        let raw = startValue + Double(steps) * step
        return clamped(snapped(raw))
    }

    /// Uses `.rounded()` so the first step fires at half a step's travel (~7px default),
    /// not a full step. Makes short deliberate drags feel immediately responsive.
    func stepCount(from translation: CGFloat) -> Int {
        Int((Double(translation) / pixelsPerStep).rounded())
    }

    func isAtMin(_ v: Double) -> Bool { v <= minValue + step * 0.01 }
    func isAtMax(_ v: Double) -> Bool { v >= maxValue - step * 0.01 }

    func snappedValue(_ v: Double) -> Double {
        clamped(snapped(v))
    }

    private func snapped(_ v: Double) -> Double {
        let stepsFromMin = ((v - minValue) / step).rounded()
        return minValue + stepsFromMin * step
    }

    private func clamped(_ v: Double) -> Double {
        Swift.min(maxValue, Swift.max(minValue, v))
    }
}

// MARK: - Format helper

private func formatSteppedValue(_ v: Double, isInteger: Bool) -> String {
    if isInteger { return "\(Int(v.rounded()))" }
    // Always show one decimal place so whole numbers (185.0) and halves (182.5)
    // have the same text width — prevents the label from jumping left/right.
    return String(format: "%.1f", (v * 10).rounded() / 10)
}

// MARK: - Swipe Value Control

/// Swipe-based stepped value control.
///
/// Drag accumulates velocity-weighted deltas: slow drags are precise (1×), fast drags
/// cover more ground (up to 2× at 400 pt/s). Commits the live value on release with no
/// velocity bonus — what you see is what you get. Tap opens a numpad sheet for direct entry.
struct SwipeValueControl: View {
    @Binding var text: String
    let unit: String
    let step: Double
    let minValue: Double
    let maxValue: Double
    let isInteger: Bool
    /// Pre-fills the drag base and numpad sheet when the field is blank.
    var firstTapDefault: Double? = nil
    /// Points per step. Default 14 puts the first-step threshold at ~7px.
    var pixelsPerStep: Double = 14
    /// Specific values that trigger a stronger milestone haptic (e.g. plate combinations for barbell).
    var milestones: Set<Double>? = nil
    /// Called when the user starts interacting, either by tapping into manual entry
    /// or by beginning a horizontal swipe.
    var onInteractionStart: (() -> Void)? = nil
    /// Called when the control commits a value change after drag, direct entry, or accessibility adjustment.
    var onCommit: (() -> Void)? = nil
    /// Set to a new UUID to trigger the swipe hint animation. Nil means no hint.
    var hintToken: UUID? = nil

    // MARK: Gesture state

    /// @GestureState resets automatically on gesture end and system cancellation.
    @GestureState private var gestureActive: Bool = false
    /// True only after horizontal lock is confirmed — drives visual drag state.
    @State private var isDragging: Bool = false
    @State private var horizontalLocked: Bool = false
    @State private var dragStartValue: Double? = nil
    @State private var liveValue: Double? = nil
    @State private var lastRawSteps: Int = 0
    @State private var goingDown: Bool = false
    @State private var boundaryHapticFired: Bool = false
    /// Prevents double-fire from onEnded + onChange(gestureActive) both committing.
    @State private var didCommit: Bool = false
    /// Velocity-weighted pixel accumulator — slow drags are 1x, fast drags up to 2x.
    @State private var dragAccumulator: Double = 0
    @State private var previousTranslation: CGFloat = 0
    /// Visual rubber-band offset applied when dragging past min/max boundary.
    @State private var rubberOffset: CGFloat = 0

    @State private var hintOffset: CGFloat = 0

    // Haptic generators stored as @State so they survive SwiftUI re-renders during drag.
    // private let would recreate them every frame, wasting prepare() calls.
    @State private var selectionGen = UISelectionFeedbackGenerator()
    @State private var impactGen = UIImpactFeedbackGenerator(style: .rigid)
    @State private var milestoneGen = UIImpactFeedbackGenerator(style: .heavy)
    /// Briefly true when a milestone value is hit — drives the visual number pop.
    @State private var milestoneFlash: Bool = false

    // MARK: Inline edit

    @State private var isEditing: Bool = false
    @State private var editText: String = ""
    @State private var editCancelled: Bool = false
    @FocusState private var isEditFocused: Bool

    // MARK: Derived

    private var engine: SwipeValueEngine {
        SwipeValueEngine(step: step, minValue: minValue, maxValue: maxValue,
                         pixelsPerStep: pixelsPerStep)
    }

    /// Semantic "current" value: prefers text, then firstTapDefault, then minValue.
    private var current: Double {
        Double(text) ?? firstTapDefault ?? minValue
    }

    private var displayValue: Double { liveValue ?? current }

    private func formatted(_ v: Double) -> String {
        formatSteppedValue(v, isInteger: isInteger)
    }

    /// Strips trailing `.0` for whole numbers so committed values are clean (e.g. "185" not "185.0").
    /// The control re-applies `formatted()` when displaying, so consistent width is preserved.
    private func cleanFormatted(_ v: Double) -> String {
        if isInteger { return "\(Int(v.rounded()))" }
        return String(format: "%.1f", (v * 10).rounded() / 10)
    }

    /// Starting value for a drag. Blank field uses firstTapDefault so dragging from
    /// an empty weight cell starts at 45 lbs, not 0.
    private var dragBase: Double {
        let base = text.isEmpty ? (firstTapDefault ?? minValue) : current
        return engine.snappedValue(base)
    }

    // MARK: Body

    var body: some View {
        ZStack(alignment: .bottom) {
            HStack(spacing: isDragging ? 6 : 0) {
                Image(systemName: "chevron.left")
                    .font(.system(size: isDragging ? 10 : 11, weight: .semibold))
                    .foregroundStyle(Color.textFaint)
                    .opacity(isDragging ? (lastRawSteps <= 0 ? 0.9 : 0.2) : 0.52)
                    .scaleEffect(isDragging && lastRawSteps < 0
                        ? 1.0 + min(CGFloat(abs(lastRawSteps)) * 0.08, 0.7) : 1.0)
                    .animation(.spring(response: 0.1, dampingFraction: 0.7), value: lastRawSteps)
                    .frame(width: isDragging ? 14 : 24)

                VStack(spacing: 2) {
                    if isEditing {
                        TextField("", text: $editText)
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .multilineTextAlignment(.center)
                            .keyboardType(isInteger ? .numberPad : .decimalPad)
                            .focused($isEditFocused)
                            .onSubmit { commitEdit() }
                            .onAppear {
                                DispatchQueue.main.async {
                                    UIApplication.shared.sendAction(
                                        #selector(UITextField.selectAll(_:)),
                                        to: nil, from: nil, for: nil
                                    )
                                }
                            }
                            .transition(.opacity)
                    } else {
                        Text((text.isEmpty && liveValue == nil) ? "—" : formatted(displayValue))
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                            .contentTransition(.numericText(countsDown: goingDown))
                            .animation(.spring(response: 0.1, dampingFraction: 0.85), value: formatted(displayValue))
                            .transition(.opacity)
                    }

                    Text(unit.uppercased())
                        .font(.system(size: 11, weight: .medium))
                        .tracking(0.4)
                        .opacity(isDragging ? 0 : 0.5)
                }
                .foregroundStyle(Color.textPrimary)
                .scaleEffect(milestoneFlash ? 1.15 : 1.0)
                .animation(.spring(response: 0.12, dampingFraction: 0.5), value: milestoneFlash)
                .offset(x: hintOffset)
                .frame(minWidth: isDragging ? 72 : 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: isDragging ? 10 : 11, weight: .semibold))
                    .foregroundStyle(Color.textFaint)
                    .opacity(isDragging ? (lastRawSteps >= 0 ? 0.9 : 0.2) : 0.52)
                    .scaleEffect(isDragging && lastRawSteps > 0
                        ? 1.0 + min(CGFloat(abs(lastRawSteps)) * 0.08, 0.7) : 1.0)
                    .animation(.spring(response: 0.1, dampingFraction: 0.7), value: lastRawSteps)
                    .frame(width: isDragging ? 14 : 24)
            }
            // Glass pill — appears only when floating so the number reads clearly
            // over whatever is behind the card. Fades in with the same spring as the lift.
            .padding(.horizontal, isDragging ? Spacing.sm : 0)
            .padding(.vertical, isDragging ? Spacing.xs : 0)
            .fixedSize(horizontal: isDragging, vertical: false)
            .background {
                RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
                    .glassEffect(in: RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
                    .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
                    .opacity(isDragging ? 1 : 0)
            }
            // Float content up so thumb doesn't cover the number.
            // Track stays anchored at the bottom of the frame.
            .offset(x: rubberOffset, y: isDragging ? -56 : 0)
            .scaleEffect(isDragging ? 1.04 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.75), value: isDragging)
            .frame(maxWidth: .infinity)
        }
        .animation(.spring(response: 0.2, dampingFraction: 0.75), value: isDragging)
        .frame(maxWidth: .infinity, minHeight: 52, maxHeight: .infinity)
        .contentShape(Rectangle())
        .gesture(swipeGesture)
        .onChange(of: gestureActive) { _, active in
            if !active { commitAndReset() }
        }
        .onChange(of: hintToken) { _, token in
            guard token != nil else {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.85)) { hintOffset = 0 }
                return
            }
            Task { @MainActor in
                withAnimation(.spring(response: 0.28, dampingFraction: 0.76)) { hintOffset = -6 }
                try? await Task.sleep(for: .milliseconds(210))
                withAnimation(.spring(response: 0.28, dampingFraction: 0.76)) { hintOffset = 6 }
                try? await Task.sleep(for: .milliseconds(210))
                withAnimation(.spring(response: 0.30, dampingFraction: 0.82)) { hintOffset = 0 }
                UISelectionFeedbackGenerator().selectionChanged()
            }
        }
        .onTapGesture {
            guard !isEditing else { return }
            onInteractionStart?()
            editText = text.isEmpty ? (firstTapDefault.map { formatted($0) } ?? "") : text
            isEditing = true
            isEditFocused = true
        }
        .onChange(of: isEditFocused) { _, focused in
            if !focused { commitEdit() }
        }
        .accessibilityLabel(unit)
        .accessibilityValue(text.isEmpty ? "not set" : "\(formatted(current)) \(unit)")
        .accessibilityHint("Swipe left or right to adjust, or tap to enter a value")
        .accessibilityAdjustableAction { direction in
            let delta: Double = direction == .increment ? step : -step
            let raw = current + delta
            let stepsFromMin = ((raw - minValue) / step).rounded()
            let snapped = minValue + stepsFromMin * step
            let clamped = Swift.min(maxValue, Swift.max(minValue, snapped))
            text = formatted(clamped)
            onCommit?()
        }
    }

    // MARK: Gesture

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 5)
            .updating($gestureActive) { _, state, _ in state = true }
            .onChanged { value in
                guard !isEditing else { return }
                if !horizontalLocked {
                    guard abs(value.translation.width) > abs(value.translation.height) * 0.75 else { return }
                    horizontalLocked = true
                    dragStartValue = dragBase
                    previousTranslation = value.translation.width  // seed so first delta is zero
                    isDragging = true
                    onInteractionStart?()
                    didCommit = false
                    selectionGen.prepare()
                    impactGen.prepare()
                    milestoneGen.prepare()
                }

                guard let start = dragStartValue else { return }

                // Accumulate velocity-weighted deltas so slow drags stay precise
                // and fast drags cover more ground — like a physical dial with inertia.
                let rawTranslation = value.translation.width
                let delta = Double(rawTranslation - previousTranslation)
                previousTranslation = rawTranslation
                dragAccumulator += delta * velocityMultiplier(for: abs(value.velocity.width))

                let newSteps = Int((dragAccumulator / pixelsPerStep).rounded())
                let newValue = engine.steppedValue(
                    startValue: start,
                    translation: CGFloat(newSteps) * CGFloat(pixelsPerStep)
                )

                // Rubber-band: when value is clamped at a boundary, the raw accumulated
                // movement keeps going. Apply a fraction of that overshoot as a visual x-offset
                // with logarithmic decay so it feels like pressing against a physical wall.
                let rawValue = start + Double(newSteps) * step
                let overshootSteps = (rawValue - newValue) / step
                if abs(overshootSteps) > 0.01 {
                    let px = CGFloat(abs(overshootSteps))
                    let sign: CGFloat = overshootSteps > 0 ? 1 : -1
                    rubberOffset = sign * px * 6 / (1 + px * 0.4)
                } else {
                    rubberOffset = 0
                }

                if newSteps != lastRawSteps {
                    goingDown = newSteps < lastRawSteps
                    let atBoundary = engine.isAtMin(newValue) || engine.isAtMax(newValue)
                    if atBoundary {
                        if !boundaryHapticFired {
                            impactGen.impactOccurred()
                            boundaryHapticFired = true
                        }
                    } else {
                        boundaryHapticFired = false
                        if let milestones, milestones.contains(newValue) {
                            milestoneGen.impactOccurred()
                            milestoneFlash = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                milestoneFlash = false
                            }
                        } else {
                            selectionGen.selectionChanged()
                        }
                    }
                    lastRawSteps = newSteps
                }

                liveValue = newValue
                text = cleanFormatted(newValue)
            }
            .onEnded { _ in
                commitAndReset()
            }
    }

    // MARK: Helpers

    /// Smooth ramp: 1× at rest → 2× at 400 pt/s. Keeps slow drags precise
    /// while letting fast sweeps cover roughly double the range.
    private func velocityMultiplier(for speed: Double) -> Double {
        1.0 + min(speed / 400.0, 1.0)
    }

    private func commitAndReset() {
        guard !didCommit else { return }
        didCommit = true

        if let live = liveValue {
            text = cleanFormatted(live)
            onCommit?()
        }

        dragStartValue = nil
        dragAccumulator = 0
        previousTranslation = 0
        lastRawSteps = 0
        liveValue = nil
        isDragging = false
        horizontalLocked = false
        boundaryHapticFired = false
        goingDown = false
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            rubberOffset = 0
        }
    }

    private func commitEdit() {
        guard isEditing else { return }
        defer { isEditing = false; editCancelled = false }
        guard !editCancelled else { return }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = .current
        let raw = formatter.number(from: editText)?.doubleValue ?? Double(editText)
        guard let raw else { return }
        let sanitized = Swift.max(minValue, raw)
        text = cleanFormatted(sanitized)
        onCommit?()
        UISelectionFeedbackGenerator().selectionChanged()
    }
}

// MARK: - Previews

#Preview("Weight control") {
    @Previewable @State var weight = "185"
    SwipeValueControl(text: $weight, unit: "lbs", step: 5.0, minValue: 0, maxValue: 999,
                      isInteger: false, firstTapDefault: 45)
        .frame(height: 72)
        .padding()
        .preferredColorScheme(.dark)
}

#Preview("Reps control") {
    @Previewable @State var reps = "8"
    SwipeValueControl(text: $reps, unit: "reps", step: 1, minValue: 0, maxValue: 50,
                      isInteger: true)
        .frame(height: 72)
        .padding()
        .preferredColorScheme(.dark)
}

#Preview("Empty state") {
    @Previewable @State var weight = ""
    SwipeValueControl(text: $weight, unit: "lbs", step: 5.0, minValue: 0, maxValue: 999,
                      isInteger: false, firstTapDefault: 45)
        .frame(height: 72)
        .padding()
        .preferredColorScheme(.dark)
}
