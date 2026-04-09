// iOS 26+ only. No #available guards.

import SwiftUI

// MARK: - Helpers

/// Formats a duration in seconds as "30s" (< 60s) or "1:30" (≥ 60s).
func formatDuration(_ seconds: Int) -> String {
    guard seconds > 0 else { return "—" }
    if seconds < 60 { return "\(seconds)s" }
    let m = seconds / 60
    let s = seconds % 60
    return s == 0 ? "\(m)m" : "\(m):\(String(format: "%02d", s))"
}

private func formatWeight(_ w: Double) -> String {
    w.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(w))" : String(format: "%.1f", w)
}

private enum DeltaDirection {
    case up, down
    var symbol: String { switch self { case .up: "↑"; case .down: "↓" } }
    var color: Color {
        switch self {
        case .up:   Color.OrinGreen
        case .down: Color.red.opacity(0.75)
        }
    }
}

private struct DeltaResult {
    let direction: DeltaDirection
    let label: String
    var displayText: String { "\(direction.symbol) \(label)" }
    var color: Color { direction.color }
}

// MARK: - Set Row

/// Compact set row — values display only, editing via bottom command bar.
/// Tap row to focus, tap circle to log directly.
struct SetRow: View {
    let setNumber: Int
    let weightText: String
    let repsText: String
    let durationText: String
    let isTimed: Bool
    let tracksWeight: Bool
    let setType: SetType
    let isLogged: Bool
    let isFocused: Bool
    let isSwiping: Bool
    let isFirstInCard: Bool
    let isLastInCard: Bool
    let isPR: Bool
    let justGotPR: Bool
    let accentColor: Color
    /// When non-nil and the set has no user-entered values, this text is shown greyed
    /// out to signal that the app will pre-fill from set 1.
    let placeholderDisplayText: String?
    /// Animation delay for the placeholder fade-in (stagger effect across sets).
    let placeholderDelay: Double
    let previousSet: ActiveWorkoutViewModel.PreviousSet?
    /// True only for the single most-recently-logged set — drives the delta fade timer.
    let justLogged: Bool
    let onCycleType: () -> Void
    let onFocus: () -> Void
    let onLog: () -> Void
    let onDelete: () -> Void
    let onUndo: () -> Void
    let onCopyFromAbove: (() -> Void)?
    let onAdoptPlaceholder: (() -> Void)?
    let swipeProgress: CGFloat

    @State private var rowScale: CGFloat = 1.0
    @State private var badgeScale: CGFloat = 0
    @State private var showDelta = false
    @State private var deltaFadeTask: Task<Void, Never>? = nil
    @State private var logHighlightOpacity: Double = 0
    @State private var checkScale: CGFloat = 1.0

    private enum ActiveRowStyle {
        static let accentOpacity = 0.92
        static let fillOpacity = 0.045
        static let strokeOpacity = 0.045
        static let strokeWidth: CGFloat = 1
        static let swipeFillBoost = 0.028
        static let swipeStrokeBoost = 0.024
        static let swipeScale: CGFloat = 0.995
    }

    private enum CompletedCheckmarkStyle {
        static let foreground = Color.OrinGreen.opacity(0.66)
        static let background = Color.OrinGreen.opacity(0.085)
        static let incompleteForeground = Color.white.opacity(0.40)
    }

    private var isShowingPlaceholder: Bool {
        guard let _ = placeholderDisplayText else { return false }
        return !isLogged && weightText.isEmpty && repsText.isEmpty && durationText.isEmpty
    }

    private var rowFillOpacity: Double {
        let base = isFocused ? ActiveRowStyle.fillOpacity : 0
        return base + Double(min(1, max(0, swipeProgress))) * ActiveRowStyle.swipeFillBoost
    }

    private var rowStrokeOpacity: Double {
        let base = isFocused ? ActiveRowStyle.strokeOpacity : 0
        return base + Double(min(1, max(0, swipeProgress))) * ActiveRowStyle.swipeStrokeBoost
    }

    var body: some View {
        rowContentView
            .onAppear(perform: handleAppear)
            .onDisappear(perform: handleDisappear)
            .onChange(of: justLogged) { oldValue, newValue in
                handleJustLoggedChange(oldValue, newValue)
            }
            .onChange(of: justGotPR) { oldValue, newValue in
                handleJustGotPRChange(oldValue, newValue)
            }
    }

    private func handleAppear() {
        if isPR { badgeScale = 1.0 }
    }

    private func handleDisappear() {
        deltaFadeTask?.cancel()
    }

    private func handleJustLoggedChange(_ oldValue: Bool, _ isJust: Bool) {
        deltaFadeTask?.cancel()
        if isJust {
            showDelta = true
            deltaFadeTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(2500))
                guard !Task.isCancelled else { return }
                withAnimation(Motion.standardSpring) { showDelta = false }
            }
            withAnimation(.easeOut(duration: 0.08)) {
                logHighlightOpacity = 1.0
                rowScale = 0.992
                checkScale = 1.08
            }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(110))
                withAnimation(.easeOut(duration: 0.16)) {
                    logHighlightOpacity = 0.0
                }
                withAnimation(Motion.standardSpring) {
                    rowScale = 1.0
                    checkScale = 1.0
                }
            }
        } else {
            withAnimation(Motion.standardSpring) { showDelta = false }
            logHighlightOpacity = 0
            checkScale = 1.0
        }
    }

    private func handleJustGotPRChange(_ oldValue: Bool, _ newValue: Bool) {
        guard newValue else { return }
        badgeScale = 0
        withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
            badgeScale = 1.0
        }
        withAnimation(.spring(response: 0.18, dampingFraction: 0.4)) {
            rowScale = 1.05
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(180))
            withAnimation(Motion.standardSpring) {
                rowScale = 1.0
            }
        }
    }

    private var rowContentView: some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(isFocused ? accentColor.opacity(ActiveRowStyle.accentOpacity) : .clear)
                .frame(width: 3, height: isFocused ? 30 : 22)

            Text("\(setNumber)")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(setNumberColor)
                .frame(width: 20, alignment: .center)

            VStack(alignment: .leading, spacing: 1) {
                if isFocused, let prev = previousDisplayText {
                    Text(prev)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.54))
                        .transition(.opacity)
                }

                Text(isShowingPlaceholder ? placeholderDisplayText ?? displayText : displayText)
                    .font(.system(
                        size: isFocused ? 17 : 16,
                        weight: isFocused ? .semibold : .medium,
                        design: .rounded
                    ))
                    .monospacedDigit()
                    .foregroundStyle(valueForegroundStyle)
                    .contentTransition(.numericText())
                    .animation(Motion.standardSpring, value: displayText)
                    .animation(
                        .spring(response: 0.35, dampingFraction: 0.85)
                            .delay(isShowingPlaceholder ? placeholderDelay : 0),
                        value: isShowingPlaceholder
                    )
            }

            if showDelta, let delta = deltaResult {
                Text(delta.displayText)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(delta.color)
                    .transition(.opacity)
            }

            if isPR {
                PRBadge()
                    .scaleEffect(badgeScale)
            }

            Spacer(minLength: Spacing.sm)

            Button(action: isLogged ? onUndo : onLog) {
                Image(systemName: isLogged ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(
                        isLogged
                            ? CompletedCheckmarkStyle.foreground
                            : CompletedCheckmarkStyle.incompleteForeground
                    )
                    .background {
                        if isLogged {
                            Circle()
                                .fill(CompletedCheckmarkStyle.background)
                                .frame(width: 30, height: 30)
                        }
                    }
                    .frame(width: 44, height: 36)
                    .contentShape(Rectangle())
                    .contentTransition(.symbolEffect(.replace))
                    .scaleEffect(checkScale)
                    .opacity(isSwiping ? 0.55 : 1.0)
            }
            .buttonStyle(.plain)
        }
        .scaleEffect(rowScale * (isSwiping ? ActiveRowStyle.swipeScale : 1.0))
        .padding(.top, isFirstInCard ? 8 : (isFocused ? 6 : 3))
        .padding(.bottom, isFocused ? 6 : 3)
        .padding(.trailing, Spacing.sm)
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(accentColor.opacity(rowFillOpacity))
                .opacity((isFocused || isSwiping) ? 1 : 0)
                .padding(.top, isFirstInCard ? 6 : 1)
                .padding(.bottom, 1)
                .allowsHitTesting(false)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(
                    accentColor.opacity(rowStrokeOpacity),
                    lineWidth: ActiveRowStyle.strokeWidth
                )
                .opacity((isFocused || isSwiping) ? 1 : 0)
                .padding(.top, isFirstInCard ? 6 : 1)
                .padding(.bottom, 1)
                .allowsHitTesting(false)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(accentColor.opacity(0.14))
                .opacity(logHighlightOpacity)
                .padding(.top, isFirstInCard ? 6 : 1)
                .padding(.bottom, 1)
                .allowsHitTesting(false)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard !isLogged else { return }
            if isShowingPlaceholder {
                onAdoptPlaceholder?()
            } else {
                onFocus()
            }
        }
        .accessibilityAction(named: isLogged ? "Undo Set" : "Log Set") {
            if isLogged {
                onUndo()
            } else {
                onLog()
            }
        }
    }

    private var setNumberColor: some ShapeStyle {
        if isLogged {
            return AnyShapeStyle(Color.white.opacity(0.50))
        }
        if isFocused {
            return AnyShapeStyle(accentColor.opacity(0.95))
        }
        return AnyShapeStyle(Color.white.opacity(0.34))
    }

    private var valueForegroundStyle: AnyShapeStyle {
        if isLogged {
            return AnyShapeStyle(Color.white.opacity(0.68))
        }
        if isShowingPlaceholder {
            return AnyShapeStyle(Color.white.opacity(0.42))
        }
        if isFocused {
            return AnyShapeStyle(Color.white.opacity(0.96))
        }
        return AnyShapeStyle(Color.white.opacity(0.80))
    }

    private var displayText: String {
        if isTimed {
            let secs = Int(durationText) ?? 0
            let durationLabel = durationText.isEmpty ? "—" : formatDuration(secs)
            guard tracksWeight else { return durationLabel }
            let w = weightText.isEmpty ? "—" : weightText
            return "\(w) lb · \(durationLabel)"
        }
        guard tracksWeight else {
            let r = repsText.isEmpty ? "—" : repsText
            return "\(r) reps"
        }
        let w = weightText.isEmpty ? "—" : weightText
        let r = repsText.isEmpty ? "—" : repsText
        return "\(w) × \(r)"
    }

    /// "Last  X" string for the focused row — shows the matching previous set's value.
    private var previousDisplayText: String? {
        guard let prev = previousSet else { return nil }
        if isTimed {
            let dur = prev.duration.map { formatDuration(Int($0)) } ?? "—"
            if tracksWeight {
                return "Last  \(formatWeight(prev.weight)) × \(dur)"
            }
            return "Last  \(dur)"
        }
        if tracksWeight {
            return "Last  \(formatWeight(prev.weight)) × \(prev.reps)"
        }
        return "Last  \(prev.reps) reps"
    }

    /// Progress vs previous session — direction + magnitude label for logged rows.
    private var deltaResult: DeltaResult? {
        guard isLogged, let prev = previousSet else { return nil }

        if isTimed {
            guard let prevDur = prev.duration, let loggedDur = Double(durationText) else { return nil }
            let diff = loggedDur - prevDur
            guard diff != 0 else { return nil }
            let dir: DeltaDirection = diff > 0 ? .up : .down
            let label = (diff > 0 ? "+" : "") + formatDuration(Int(abs(diff)))
            return DeltaResult(direction: dir, label: label)
        }

        let loggedWeight = Double(weightText) ?? 0
        let loggedReps   = Int(repsText) ?? 0

        if tracksWeight {
            let weightDiff = loggedWeight - prev.weight
            let repsDiff   = loggedReps - prev.reps
            guard weightDiff != 0 || repsDiff != 0 else { return nil }

            let loggedVol = loggedWeight * Double(loggedReps)
            let prevVol   = prev.weight  * Double(prev.reps)
            guard loggedVol != prevVol else { return nil }

            let dir: DeltaDirection = loggedVol > prevVol ? .up : .down

            // Weight changed → label shows weight delta; otherwise show reps delta
            if weightDiff != 0 {
                let abs = formatWeight(Swift.abs(weightDiff))
                let prefix = weightDiff > 0 ? "+" : "-"
                return DeltaResult(direction: dir, label: "\(prefix)\(abs) lb")
            } else {
                let abs = Swift.abs(repsDiff)
                let prefix = repsDiff > 0 ? "+" : "-"
                return DeltaResult(direction: dir, label: "\(prefix)\(abs) \(abs == 1 ? "rep" : "reps")")
            }
        }

        // Reps only
        let repsDiff = loggedReps - prev.reps
        guard repsDiff != 0 else { return nil }
        let dir: DeltaDirection = repsDiff > 0 ? .up : .down
        let abs = Swift.abs(repsDiff)
        let prefix = repsDiff > 0 ? "+" : "-"
        return DeltaResult(direction: dir, label: "\(prefix)\(abs) \(abs == 1 ? "rep" : "reps")")
    }

}

// MARK: - Previews

#Preview("Unlogged – focused") {
    SetRow(
        setNumber: 1,
        weightText: "185",
        repsText: "5",
        durationText: "",
        isTimed: false,
        tracksWeight: true,
        setType: .normal,
        isLogged: false,
        isFocused: true,
        isSwiping: false,
        isFirstInCard: true,
        isLastInCard: false,
        isPR: false,
        justGotPR: false,
        accentColor: AccentTheme.midnight.accentColor,
        placeholderDisplayText: nil,
        placeholderDelay: 0,
        previousSet: nil, justLogged: false,
        onCycleType: {}, onFocus: {}, onLog: {}, onDelete: {}, onUndo: {}, onCopyFromAbove: nil, onAdoptPlaceholder: nil,
        swipeProgress: 0
    )
    .padding()
    .preferredColorScheme(.dark)
}

#Preview("Placeholder") {
    SetRow(
        setNumber: 2,
        weightText: "",
        repsText: "",
        durationText: "",
        isTimed: false,
        tracksWeight: true,
        setType: .normal,
        isLogged: false,
        isFocused: false,
        isSwiping: false,
        isFirstInCard: false,
        isLastInCard: false,
        isPR: false,
        justGotPR: false,
        accentColor: AccentTheme.midnight.accentColor,
        placeholderDisplayText: "185 × 5",
        placeholderDelay: 0.05,
        previousSet: nil, justLogged: false,
        onCycleType: {}, onFocus: {}, onLog: {}, onDelete: {}, onUndo: {}, onCopyFromAbove: {}, onAdoptPlaceholder: {},
        swipeProgress: 0
    )
    .padding()
    .preferredColorScheme(.dark)
}

#Preview("Logged – PR") {
    SetRow(
        setNumber: 2,
        weightText: "200",
        repsText: "3",
        durationText: "",
        isTimed: false,
        tracksWeight: true,
        setType: .normal,
        isLogged: true,
        isFocused: false,
        isSwiping: false,
        isFirstInCard: false,
        isLastInCard: false,
        isPR: true,
        justGotPR: false,
        accentColor: AccentTheme.midnight.accentColor,
        placeholderDisplayText: nil,
        placeholderDelay: 0,
        previousSet: nil, justLogged: false,
        onCycleType: {}, onFocus: {}, onLog: {}, onDelete: {}, onUndo: {}, onCopyFromAbove: {}, onAdoptPlaceholder: nil,
        swipeProgress: 0
    )
    .padding()
    .preferredColorScheme(.dark)
}

#Preview("Warmup") {
    SetRow(
        setNumber: 1,
        weightText: "135",
        repsText: "8",
        durationText: "",
        isTimed: false,
        tracksWeight: true,
        setType: .warmup,
        isLogged: false,
        isFocused: false,
        isSwiping: false,
        isFirstInCard: false,
        isLastInCard: true,
        isPR: false,
        justGotPR: false,
        accentColor: AccentTheme.midnight.accentColor,
        placeholderDisplayText: nil,
        placeholderDelay: 0,
        previousSet: nil, justLogged: false,
        onCycleType: {}, onFocus: {}, onLog: {}, onDelete: {}, onUndo: {}, onCopyFromAbove: {}, onAdoptPlaceholder: nil,
        swipeProgress: 0
    )
    .padding()
    .preferredColorScheme(.dark)
}
