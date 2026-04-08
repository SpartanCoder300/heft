// iOS 26+ only. No #available guards.

import SwiftUI
import UIKit

private struct SelectAllTextField: UIViewRepresentable {
    @Binding var text: String
    let isInteger: Bool
    let isFocused: Bool
    let onFocusChange: (Bool) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onFocusChange: onFocusChange)
    }

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField(frame: .zero)
        field.delegate = context.coordinator
        field.addTarget(context.coordinator, action: #selector(Coordinator.editingChanged(_:)), for: .editingChanged)
        field.keyboardType = isInteger ? .numberPad : .decimalPad
        field.textAlignment = .center
        field.adjustsFontSizeToFitWidth = true
        field.minimumFontSize = 16
        field.textColor = .white
        field.tintColor = .white
        field.borderStyle = .none
        field.backgroundColor = .clear
        field.font = UIFont.monospacedDigitSystemFont(ofSize: 22, weight: .semibold)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return field
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        uiView.keyboardType = isInteger ? .numberPad : .decimalPad

        context.coordinator.isFocusedRequestActive = isFocused

        if isFocused {
            if !uiView.isFirstResponder {
                context.coordinator.shouldSelectAllOnBeginEditing = true
                DispatchQueue.main.async {
                    guard context.coordinator.isFocusedRequestActive else { return }
                    uiView.becomeFirstResponder()
                }
            }
        } else if uiView.isFirstResponder {
            uiView.resignFirstResponder()
        }
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        @Binding var text: String
        let onFocusChange: (Bool) -> Void
        var shouldSelectAllOnBeginEditing = false
        var isFocusedRequestActive = false

        init(text: Binding<String>, onFocusChange: @escaping (Bool) -> Void) {
            self._text = text
            self.onFocusChange = onFocusChange
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            onFocusChange(true)
            guard shouldSelectAllOnBeginEditing else { return }
            shouldSelectAllOnBeginEditing = false
            DispatchQueue.main.async {
                guard textField.isFirstResponder else { return }
                textField.selectAll(nil)
            }
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            text = textField.text ?? ""
            onFocusChange(false)
        }

        @objc
        func editingChanged(_ textField: UITextField) {
            text = textField.text ?? ""
        }
    }
}

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
/// Uses a rolling-anchor drag model: each committed step requires exactly `pixelsPerStep`
/// points of horizontal travel from the previous anchor. Values only update on committed
/// steps — never interpolated. Tap opens a numpad for direct entry.
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
    /// Minimum drag distance before the gesture locks in horizontally.
    var dragActivationThreshold: CGFloat = 5
    /// Points the control floats upward while dragging (so the thumb doesn't cover the value).
    var activeLiftAmount: CGFloat = 56
    /// Specific values that trigger a stronger milestone haptic (e.g. plate combinations for barbell).
    var milestones: Set<Double>? = nil
    /// Called when the user starts interacting, either by tapping into manual entry
    /// or by beginning a horizontal swipe.
    var onInteractionStart: (() -> Void)? = nil
    /// Called when the control commits a value change after drag, direct entry, or accessibility adjustment.
    var onCommit: (() -> Void)? = nil
    /// Set to a new UUID to trigger the swipe hint animation. Nil means no hint.
    var hintToken: UUID? = nil
    /// Max number of extra steps applied by a momentum flick. Weight = 4, reps = 2 by default.
    var maxMomentumSteps: Int = 3

    // MARK: Gesture state

    /// @GestureState resets automatically on gesture end and system cancellation.
    @GestureState private var gestureActive: Bool = false
    /// True only after horizontal lock is confirmed — drives visual drag state.
    @State private var isDragging: Bool = false
    @State private var horizontalLocked: Bool = false
    @State private var dragStartValue: Double? = nil
    @State private var liveValue: Double? = nil
    /// Net committed steps since drag start — drives chevron animations.
    @State private var committedStepCount: Int = 0
    @State private var goingDown: Bool = false
    @State private var boundaryHapticFired: Bool = false
    /// Prevents double-fire from onEnded + onChange(gestureActive) both committing.
    @State private var didCommit: Bool = false
    /// Rolling anchor: the translation.x at which the last step committed.
    @State private var lastCommittedDragX: CGFloat = 0
    /// In-flight momentum task — cancelled on next drag start.
    @State private var momentumTask: Task<Void, Never>? = nil
    /// Horizontal offset applied to the lifted pill so it subtly follows the finger.
    /// Capped so the value never drifts far from its lane.
    @State private var dragFollowOffset: CGFloat = 0

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
            // Anchor tether — 1pt gradient stem connecting the lifted pill to its origin.
            // Height stretches slightly with accumulated steps (tension feel).
            // Follow offset is spring-animated so it lags a frame behind the pill.
            let tetherHeight = max(0, activeLiftAmount - 16
                + min(CGFloat(abs(committedStepCount)) * 1.2, 7))
            RoundedRectangle(cornerRadius: 0.5)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.10), Color.white.opacity(0)],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .frame(width: 1, height: tetherHeight)
                .blur(radius: 1.2)
                .offset(x: dragFollowOffset)
                .opacity(isDragging ? 1 : 0)
                .animation(.spring(response: 0.25, dampingFraction: 0.82), value: dragFollowOffset)
                // Longer fade lets the spring snap-back finish before the tether disappears.
                .animation(.easeOut(duration: 0.28), value: isDragging)

            HStack(spacing: isDragging ? 6 : 0) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.textFaint)
                    // Resting: very subtle — affordance hint, not a tap target.
                    // Dragging: dim inactive side, highlight active side as direction cue only.
                    .opacity(isDragging ? (committedStepCount <= 0 ? 0.55 : 0.08) : 0.18)
                    .animation(.easeOut(duration: 0.1), value: isDragging)
                    .animation(.easeOut(duration: 0.08), value: committedStepCount)
                    .frame(width: isDragging ? 14 : 20)

                VStack(spacing: 2) {
                    if isEditing {
                        SelectAllTextField(
                            text: $editText,
                            isInteger: isInteger,
                            isFocused: isEditing,
                            onFocusChange: handleEditFocusChange
                        )
                            .frame(maxWidth: .infinity)
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
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.textFaint)
                    .opacity(isDragging ? (committedStepCount >= 0 ? 0.55 : 0.08) : 0.18)
                    .animation(.easeOut(duration: 0.1), value: isDragging)
                    .animation(.easeOut(duration: 0.08), value: committedStepCount)
                    .frame(width: isDragging ? 14 : 20)
            }
            // Glass pill — tighter padding keeps it precise rather than badge-like.
            // Opacity 0.85 lets more of the glass blur through (less solid, more material).
            .padding(.horizontal, isDragging ? Spacing.xs : 0)
            .padding(.vertical, isDragging ? 3 : 0)
            .fixedSize(horizontal: isDragging, vertical: false)
            .background {
                RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
                    .glassEffect(in: RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
                    .shadow(color: .black.opacity(0.14), radius: 10, y: 3)
                    .opacity(isDragging ? 0.85 : 0)
            }
            // Lift + horizontal follow. Follow is spring-animated in the gesture handler,
            // so the pill lags slightly behind the finger — feels tethered, not glued.
            .offset(x: isDragging ? dragFollowOffset : 0, y: isDragging ? -activeLiftAmount : 0)
            .scaleEffect(isDragging ? 1.02 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.78), value: isDragging)
            .frame(maxWidth: .infinity)
        }
        .animation(.spring(response: 0.2, dampingFraction: 0.75), value: isDragging)
        .frame(maxWidth: .infinity, minHeight: 52, maxHeight: .infinity)
        // Slight scale on the whole control surface when active — makes the pill feel
        // like it's rising from within rather than appearing on top.
        .scaleEffect(isDragging ? 1.015 : 1.0)
        .animation(.spring(response: 0.22, dampingFraction: 0.80), value: isDragging)
        // Radial center brightness — subtle depth cue (no edge glow, just center lift).
        .overlay {
            RadialGradient(
                colors: [Color.white.opacity(0.04), .clear],
                center: .center, startRadius: 0, endRadius: 52
            )
            .allowsHitTesting(false)
            .opacity(isDragging ? 1 : 0)
            .animation(.easeOut(duration: 0.14), value: isDragging)
        }
        // Background dim — very slight darkening of the inactive surface while dragging,
        // increasing perceived contrast on the lifted pill.
        .overlay {
            Color.black
                .opacity(isDragging ? 0.03 : 0)
                .allowsHitTesting(false)
                .animation(.easeOut(duration: 0.14), value: isDragging)
        }
        .contentShape(Rectangle())
        .gesture(swipeGesture)
        .onChange(of: gestureActive) { _, active in
            // Fires on system-cancelled gestures (e.g. notification pulldown). No velocity.
            if !active { commitAndReset(finalVelocity: 0) }
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
        DragGesture(minimumDistance: dragActivationThreshold)
            .updating($gestureActive) { _, state, _ in state = true }
            .onChanged { value in
                guard !isEditing else { return }

                // ── Lock-in ────────────────────────────────────────────────────
                if !horizontalLocked {
                    // Require clearly horizontal intent before locking.
                    guard abs(value.translation.width) > abs(value.translation.height) * 0.75 else { return }
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil, from: nil, for: nil
                    )
                    horizontalLocked = true
                    dragStartValue = dragBase
                    // Seed anchor at the lock-in point so the first step requires a full
                    // pixelsPerStep of travel from here, not from gesture origin.
                    lastCommittedDragX = value.translation.width
                    committedStepCount = 0
                    isDragging = true
                    didCommit = false
                    momentumTask?.cancel()
                    momentumTask = nil
                    onInteractionStart?()
                    selectionGen.prepare()
                    impactGen.prepare()
                    milestoneGen.prepare()
                }

                guard let start = dragStartValue else { return }

                // ── Horizontal follow ──────────────────────────────────────────
                // Spring-animated so the pill lags slightly behind the finger.
                // 18% of travel, ±22pt cap. At boundary the follow is compressed
                // further to convey physical resistance (see boundary block below).
                let targetFollow = min(22, max(-22, value.translation.width * 0.18))
                withAnimation(.spring(response: 0.2, dampingFraction: 0.88)) {
                    dragFollowOffset = targetFollow
                }

                // ── Rolling anchor ─────────────────────────────────────────────
                // deltaX measures travel since the last committed anchor.
                // Each full pixelsPerStep consumed advances the anchor and commits one step.
                // This gives exact 1:1 pixel-to-step mapping without any velocity weighting —
                // slow and fast drags produce the same number of steps per pixel traveled.
                let delta = Double(value.translation.width - lastCommittedDragX)
                let stepsToCommit = Int(delta / pixelsPerStep)   // truncate: full steps only

                guard stepsToCommit != 0 else { return }

                lastCommittedDragX += CGFloat(stepsToCommit) * CGFloat(pixelsPerStep)
                committedStepCount += stepsToCommit

                let rawValue = start + Double(committedStepCount) * step
                let newValue = engine.snappedValue(rawValue)   // snap + hard clamp
                let previous = liveValue ?? start

                // ── Boundary ───────────────────────────────────────────────────
                if newValue == previous {
                    if !boundaryHapticFired {
                        impactGen.impactOccurred()
                        boundaryHapticFired = true
                    }
                    // Elastic resistance: compress the follow offset sharply so the pill
                    // visually recoils from the wall instead of continuing to track.
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.65)) {
                        dragFollowOffset *= 0.2
                    }
                    return
                }

                boundaryHapticFired = false
                goingDown = newValue < previous
                liveValue = newValue
                text = cleanFormatted(newValue)
                fireStepHaptic(for: newValue)
            }
            .onEnded { value in
                commitAndReset(finalVelocity: value.velocity.width)
            }
    }

    // MARK: Helpers

    /// Fire the appropriate haptic the moment a step commits.
    /// Milestone values get a stronger impact; normal steps get selection feedback.
    private func fireStepHaptic(for value: Double) {
        if let milestones, milestones.contains(value) {
            milestoneGen.impactOccurred()
            milestoneFlash = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { milestoneFlash = false }
        } else {
            selectionGen.selectionChanged()
        }
    }

    private func commitAndReset(finalVelocity: CGFloat) {
        guard !didCommit else { return }
        didCommit = true

        // Commit whatever the rolling anchor landed on.
        let committedValue = liveValue ?? current
        text = cleanFormatted(committedValue)
        if liveValue != nil { onCommit?() }

        // Capture before clearing state.
        let momentumBase = committedValue

        dragStartValue = nil
        committedStepCount = 0
        lastCommittedDragX = 0
        liveValue = nil
        isDragging = false
        horizontalLocked = false
        boundaryHapticFired = false
        goingDown = false
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) { dragFollowOffset = 0 }

        applyMomentum(from: momentumBase, velocity: finalVelocity)
    }

    /// Applies a short burst of discrete extra steps after a fast flick.
    /// Each step is committed individually so haptics and persistence fire normally.
    private func applyMomentum(from startValue: Double, velocity: CGFloat) {
        let config = SwipeTuningManager.shared.config
        guard config.momentumEnabled,
              abs(velocity) > config.momentumVelocityThreshold else { return }

        let direction: Double = velocity > 0 ? 1 : -1
        let stepInterval = config.momentumDuration / Double(maxMomentumSteps)
        var base = startValue

        momentumTask = Task { @MainActor in
            for _ in 0..<maxMomentumSteps {
                try? await Task.sleep(for: .seconds(stepInterval))
                guard !Task.isCancelled else { return }

                let candidate = engine.snappedValue(base + direction * step)
                guard candidate != base else { break }  // hit boundary

                goingDown = candidate < base
                base = candidate
                text = cleanFormatted(candidate)
                fireStepHaptic(for: candidate)
                onCommit?()
            }
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

    private func handleEditFocusChange(_ focused: Bool) {
        if !focused {
            commitEdit()
        }
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
