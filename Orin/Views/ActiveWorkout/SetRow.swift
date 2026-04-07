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

    @State private var rowScale: CGFloat = 1.0
    @State private var badgeScale: CGFloat = 0
    @State private var showDelta = false
    @State private var deltaFadeTask: Task<Void, Never>? = nil
    @State private var logHighlightOpacity: Double = 0
    @State private var checkScale: CGFloat = 1.0

    private var isShowingPlaceholder: Bool {
        guard let _ = placeholderDisplayText else { return false }
        return !isLogged && weightText.isEmpty && repsText.isEmpty && durationText.isEmpty
    }

    var body: some View {
        HStack(spacing: 6) {
            // Focused accent bar
            RoundedRectangle(cornerRadius: 1.5)
                .fill(isFocused ? accentColor.opacity(1.0) : .clear)
                .frame(width: 4, height: isFocused ? 34 : 26)

            Text("\(setNumber)")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(
                    isLogged
                        ? Color.white.opacity(0.16)
                        : isFocused
                            ? accentColor.opacity(0.70)
                            : Color.textFaint
                )
                .frame(width: 20, alignment: .center)

            VStack(alignment: .leading, spacing: 1) {
                // "Last: X" — sits above the value on the focused row as context
                if isFocused, let prev = previousDisplayText {
                    Text(prev)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.48))
                        .transition(.opacity)
                }

                Text(isShowingPlaceholder ? placeholderDisplayText! : displayText)
                    .font(.system(
                        size: isLogged ? 15 : isFocused ? 17 : 16,
                        weight: isLogged ? .regular : isFocused ? .semibold : .medium,
                        design: .rounded
                    ))
                    .monospacedDigit()
                    .foregroundStyle(
                        isLogged
                            ? Color.white.opacity(0.16)
                            : isShowingPlaceholder
                                ? Color.white.opacity(0.32)
                                : isFocused
                                    ? Color.white.opacity(0.98)
                                    : Color.white.opacity(0.46)
                    )
                    .contentTransition(.numericText())
                    .animation(Motion.standardSpring, value: weightText)
                    .animation(Motion.standardSpring, value: repsText)
                    .animation(
                        .spring(response: 0.35, dampingFraction: 0.85)
                            .delay(isShowingPlaceholder ? placeholderDelay : 0),
                        value: isShowingPlaceholder
                    )
            }
            .animation(Motion.standardSpring, value: isPR)
            .animation(Motion.standardSpring, value: isFocused)

            // Delta — only on the most recently logged set, fades after 2.5s
            if showDelta, let delta = deltaResult {
                Text(delta.displayText)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(delta.color)
                    .transition(.opacity)
            }

            // PR badge — pops in with spring animation when PR is detected
            if isPR {
                PRBadge()
                    .scaleEffect(badgeScale)
            }

            Spacer()

            // Log / status button
            // Unlogged: tap to log immediately (values pre-filled from last session).
            // Logged: tap to undo — the checkmark is the natural undo target.
            Button(action: isLogged ? onUndo : onLog) {
                Image(systemName: isLogged ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(
                        isLogged
                            ? Color.OrinGreen.opacity(0.82)
                            : isFocused
                                ? accentColor.opacity(0.90)
                                : Color.white.opacity(0.28)
                    )
                    .background {
                        if isLogged {
                            Circle()
                                .fill(Color.OrinGreen.opacity(0.08))
                                .frame(width: 28, height: 28)
                        }
                    }
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                    .contentTransition(.symbolEffect(.replace))
                    .animation(.easeOut(duration: 0.10), value: isLogged)
                    .scaleEffect(checkScale)
                    .animation(.spring(response: 0.24, dampingFraction: 0.72), value: checkScale)
            }
            .buttonStyle(.plain)
        }
        .scaleEffect(rowScale)
        .padding(.vertical, isLogged ? 3 : isFocused ? 7 : 4)
        .padding(.leading, Spacing.xs)
        .padding(.trailing, Spacing.sm)
        .background(rowBackground)
        .overlay {
            rowShape
                .fill(accentColor.opacity(0.16))
                .opacity(logHighlightOpacity)
                .allowsHitTesting(false)
        }
        .overlay {
            if isLogged || isFocused {
                rowShape
                    .strokeBorder(
                        isLogged
                            ? Color.white.opacity(0.025)
                            : accentColor.opacity(0.50),
                        lineWidth: 1
                    )
            }
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
        .opacity(1.0)
        .animation(Motion.standardSpring, value: isLogged)
        .animation(Motion.standardSpring, value: isFocused)
        .contextMenu {
            if isLogged {
                Button(action: onUndo) {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                }
            } else {
                Button(action: onCycleType) {
                    Label("Change Type", systemImage: "tag")
                }
                if let copyFromAbove = onCopyFromAbove {
                    Button(action: copyFromAbove) {
                        Label("Copy from Above", systemImage: "arrow.up.doc.on.clipboard")
                    }
                }
                Divider()
                Button(role: .destructive, action: onDelete) {
                    Label("Delete Set", systemImage: "trash")
                }
            }
        }
        .onAppear {
            if isPR { badgeScale = 1.0 }
        }
        .onChange(of: justLogged) { _, isJust in
            deltaFadeTask?.cancel()
            if isJust {
                showDelta = true
                deltaFadeTask = Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(2500))
                    guard !Task.isCancelled else { return }
                    withAnimation(Motion.standardSpring) { showDelta = false }
                }
                // Immediate ack: accent-tinted highlight with a restrained settle.
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
        .onChange(of: justGotPR) { _, newVal in
            guard newVal else { return }
            // Badge: scale from zero with bouncy spring
            badgeScale = 0
            withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                badgeScale = 1.0
            }
            // Row: pulse scale 1.0 → 1.05 → 1.0
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

    private var rowShape: some InsettableShape {
        Rectangle()
    }

    private var rowBackground: some View {
        rowShape
            .fill(
                isLogged
                ? Color.white.opacity(0.04)
                : isFocused
                    ? accentColor.opacity(0.40)
                    : .clear
            )
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
        isFirstInCard: true,
        isLastInCard: false,
        isPR: false,
        justGotPR: false,
        accentColor: AccentTheme.midnight.accentColor,
        placeholderDisplayText: nil,
        placeholderDelay: 0,
        previousSet: nil, justLogged: false,
        onCycleType: {}, onFocus: {}, onLog: {}, onDelete: {}, onUndo: {}, onCopyFromAbove: nil, onAdoptPlaceholder: nil
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
        isFirstInCard: false,
        isLastInCard: false,
        isPR: false,
        justGotPR: false,
        accentColor: AccentTheme.midnight.accentColor,
        placeholderDisplayText: "185 × 5",
        placeholderDelay: 0.05,
        previousSet: nil, justLogged: false,
        onCycleType: {}, onFocus: {}, onLog: {}, onDelete: {}, onUndo: {}, onCopyFromAbove: {}, onAdoptPlaceholder: {}
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
        isFirstInCard: false,
        isLastInCard: false,
        isPR: true,
        justGotPR: false,
        accentColor: AccentTheme.midnight.accentColor,
        placeholderDisplayText: nil,
        placeholderDelay: 0,
        previousSet: nil, justLogged: false,
        onCycleType: {}, onFocus: {}, onLog: {}, onDelete: {}, onUndo: {}, onCopyFromAbove: {}, onAdoptPlaceholder: nil
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
        isFirstInCard: false,
        isLastInCard: true,
        isPR: false,
        justGotPR: false,
        accentColor: AccentTheme.midnight.accentColor,
        placeholderDisplayText: nil,
        placeholderDelay: 0,
        previousSet: nil, justLogged: false,
        onCycleType: {}, onFocus: {}, onLog: {}, onDelete: {}, onUndo: {}, onCopyFromAbove: {}, onAdoptPlaceholder: nil
    )
    .padding()
    .preferredColorScheme(.dark)
}
