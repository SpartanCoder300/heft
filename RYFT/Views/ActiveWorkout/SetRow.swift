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
    let onCycleType: () -> Void
    let onFocus: () -> Void
    let onLog: () -> Void
    let onDelete: () -> Void
    let onUndo: () -> Void
    let onCopyFromAbove: (() -> Void)?

    @State private var rowScale: CGFloat = 1.0
    @State private var badgeScale: CGFloat = 0

    var body: some View {
        HStack(spacing: 6) {
            // Focused accent bar
            RoundedRectangle(cornerRadius: 1.5)
                .fill(isFocused ? accentColor.opacity(0.96) : .clear)
                .frame(width: 3, height: isFocused ? 30 : 28)

            Text("\(setNumber)")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(isLogged ? Color.textMuted.opacity(0.68) : Color.textFaint)
                .frame(width: 20, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                Text(displayText)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(
                        isLogged
                            ? Color.textMuted.opacity(0.76)
                            : isFocused
                                ? Color.white.opacity(0.98)
                                : Color.textPrimary
                    )
                    .contentTransition(.numericText())
                    .animation(Motion.standardSpring, value: weightText)
                    .animation(Motion.standardSpring, value: repsText)
            }
            .animation(Motion.standardSpring, value: isPR)

            // PR badge — pops in with spring animation when PR is detected
            if isPR {
                Text("PR")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.ryftGold, in: Capsule())
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
                            ? Color.ryftGreen
                            : isFocused
                                ? Color.textPrimary.opacity(0.9)
                                : Color.textMuted
                    )
                    .background {
                        if isLogged {
                            Circle()
                                .fill(Color.ryftGreen.opacity(0.14))
                                .frame(width: 28, height: 28)
                        }
                    }
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .scaleEffect(rowScale)
        .padding(.vertical, 4)
        .padding(.leading, Spacing.xs)
        .padding(.trailing, Spacing.sm)
        .background(rowBackground)
        .overlay {
            if isLogged || isFocused {
                rowShape
                    .strokeBorder(
                        isLogged
                            ? Color.white.opacity(0.035)
                            : accentColor.opacity(0.16),
                        lineWidth: 1
                    )
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if !isLogged { onFocus() }
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
                if let copyFromAbove = onCopyFromAbove {
                    Button(action: copyFromAbove) {
                        Label("Copy from Above", systemImage: "arrow.up.doc.on.clipboard")
                    }
                }
                Button(role: .destructive, action: onDelete) {
                    Label("Delete Set", systemImage: "trash")
                }
            }
        }
        .onAppear {
            // If this set was already a PR (e.g. view re-mounted), show badge immediately
            if isPR { badgeScale = 1.0 }
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

    private var rowShape: some InsettableShape {
        UnevenRoundedRectangle(
            cornerRadii: .init(
                topLeading: isFirstInCard ? 8 : 0,
                bottomLeading: isLastInCard ? 8 : 0,
                bottomTrailing: isLastInCard ? 8 : 0,
                topTrailing: isFirstInCard ? 8 : 0
            ),
            style: .continuous
        )
    }

    private var rowBackground: some View {
        rowShape
            .fill(
                isLogged
                ? Color.white.opacity(0.065)
                : isFocused
                    ? accentColor.opacity(0.18)
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
        onCycleType: {}, onFocus: {}, onLog: {}, onDelete: {}, onUndo: {}, onCopyFromAbove: nil
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
        onCycleType: {}, onFocus: {}, onLog: {}, onDelete: {}, onUndo: {}, onCopyFromAbove: {}
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
        onCycleType: {}, onFocus: {}, onLog: {}, onDelete: {}, onUndo: {}, onCopyFromAbove: {}
    )
    .padding()
    .preferredColorScheme(.dark)
}
