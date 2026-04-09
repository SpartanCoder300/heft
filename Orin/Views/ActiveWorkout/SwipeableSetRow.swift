// iOS 26+ only. No #available guards.

import SwiftUI
import UIKit

struct SwipeSetAction: Identifiable {
    let id = UUID()
    let systemImage: String
    let tint: Color
    let accessibilityLabel: String
    let action: () -> Void
}

struct SwipeableSetRow<Content: View>: View {
    let rowID: UUID
    let actions: [SwipeSetAction]
    @Binding var openRowID: UUID?
    let content: (_ isInteracting: Bool, _ swipeProgress: CGFloat) -> Content

    @State private var offsetX: CGFloat = 0
    @State private var panStartOffsetX: CGFloat = 0

    private let actionWidth: CGFloat = 44
    private let actionSpacing: CGFloat = 8
    private let trailingInset: CGFloat = 12
    private let maxOverswipe: CGFloat = 88
    private let commitOverswipeThreshold: CGFloat = 56
    private let settleAnimation = Animation.spring(response: 0.22, dampingFraction: 0.92)
    private let closeAnimation = Animation.easeOut(duration: 0.26)

    init(
        rowID: UUID,
        actions: [SwipeSetAction],
        openRowID: Binding<UUID?>,
        @ViewBuilder content: @escaping (_ isInteracting: Bool, _ swipeProgress: CGFloat) -> Content
    ) {
        self.rowID = rowID
        self.actions = actions
        self._openRowID = openRowID
        self.content = content
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            actionBackground

            content(isInteracting, swipeProgress)
                .contentShape(Rectangle())
                .offset(x: offsetX)
        }
        .clipped()
        .gesture(
            HorizontalSwipePanGesture(
                isEnabled: !actions.isEmpty,
                allowsRightSwipeToClose: isOpen,
                onBegan: handlePanBegan,
                onChanged: handlePanChanged(_:),
                onEnded: handlePanEnded(translationX:predictedEndX:),
                onCancelled: resetPanState
            )
        )
        .onChange(of: openRowID) { _, newValue in
            guard newValue != rowID, offsetX != 0 else { return }
            closeRow(animation: closeAnimation)
        }
    }

    private var revealWidth: CGFloat {
        guard !actions.isEmpty else { return 0 }
        let buttonWidths = CGFloat(actions.count) * actionWidth
        let spacingWidths = CGFloat(max(0, actions.count - 1)) * actionSpacing
        return buttonWidths + spacingWidths + trailingInset
    }

    private var isOpen: Bool {
        openRowID == rowID
    }

    private var isInteracting: Bool {
        offsetX < 0
    }

    private var swipeProgress: CGFloat {
        min(1, max(0, -offsetX / max(revealWidth, 1)))
    }

    private var actionBackground: some View {
        let exposedWidth = max(0, -offsetX)
        let progress = min(1, exposedWidth / max(revealWidth, 1))
        let commitProgress = fullSwipeCommitProgress(exposedWidth: exposedWidth)
        let primaryWidth = primaryActionWidth(exposedWidth: exposedWidth, commitProgress: commitProgress)
        let dynamicSpacing = actionSpacing * (1 - (commitProgress * 0.9))

        return HStack(spacing: dynamicSpacing) {
            ForEach(Array(actions.enumerated()), id: \.element.id) { index, action in
                actionButton(
                    action,
                    index: index,
                    exposedWidth: exposedWidth,
                    progress: progress,
                    commitProgress: commitProgress,
                    primaryWidth: primaryWidth
                )
            }
        }
        .padding(.trailing, trailingInset)
        .opacity(max(0, min(1, progress * 1.05)))
        .frame(maxWidth: .infinity, alignment: .trailing)
        .frame(width: exposedWidth, alignment: .trailing)
        .clipped()
    }

    private func actionButton(
        _ action: SwipeSetAction,
        index: Int,
        exposedWidth: CGFloat,
        progress: CGFloat,
        commitProgress: CGFloat,
        primaryWidth: CGFloat
    ) -> some View {
        let actionProgress = actionRevealProgress(for: index, exposedWidth: exposedWidth)
        let isPrimary = index == actions.count - 1
        let width = isPrimary ? primaryWidth : actionWidth
        let opacity = isPrimary ? max(actionProgress, 0.92) : actionProgress * (1 - (commitProgress * 0.9))
        let scale = isPrimary ? (0.96 + (0.04 * progress)) : (0.94 + (0.06 * actionProgress))
        let foreground = primaryForeground(for: action.tint, isPrimary: isPrimary, commitProgress: commitProgress)
        let fill = backgroundFill(for: action.tint, isPrimary: isPrimary, progress: progress, commitProgress: commitProgress)

        return Button(action: {
            closeRow(animation: closeAnimation)
            action.action()
        }) {
            Image(systemName: action.systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(foreground)
                .frame(width: width, height: 34)
                .background {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(fill)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(action.accessibilityLabel)
        .opacity(opacity)
        .scaleEffect(scale)
    }

    private var primaryAction: SwipeSetAction? {
        actions.last
    }

    private func handlePanBegan() {
        panStartOffsetX = isOpen ? -revealWidth : 0
    }

    private func handlePanChanged(_ translationX: CGFloat) {
        let proposed = panStartOffsetX + translationX
        let clamped = max(-(revealWidth + maxOverswipe), min(0, proposed))
        offsetX = clamped

        if offsetX < 0 {
            openRowID = rowID
        }
    }

    private func handlePanEnded(translationX: CGFloat, predictedEndX: CGFloat) {
        let exposedWidth = max(0, -offsetX)
        let shouldCommitPrimaryAction =
            exposedWidth > revealWidth + commitOverswipeThreshold
            || predictedEndX <= -(revealWidth + maxOverswipe * 0.9)

        if shouldCommitPrimaryAction, let primaryAction {
            commit(primaryAction)
            return
        }

        withAnimation(settleAnimation) {
            if abs(offsetX) > revealWidth * 0.45 {
                offsetX = -revealWidth
                openRowID = rowID
            } else {
                offsetX = 0
                if openRowID == rowID {
                    openRowID = nil
                }
            }
        }
    }

    private func resetPanState() {
        panStartOffsetX = 0
        if offsetX == 0 {
            openRowID = nil
        }
    }

    private func commit(_ action: SwipeSetAction) {
        withAnimation(.spring(response: 0.18, dampingFraction: 0.95)) {
            offsetX = -revealWidth
            openRowID = rowID
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(70))
            closeRow(animation: closeAnimation)
            action.action()
        }
    }

    private func actionRevealProgress(for index: Int, exposedWidth: CGFloat) -> CGFloat {
        let trailingActions = actions.count - index
        let threshold = CGFloat(trailingActions) * actionWidth
            + CGFloat(max(0, trailingActions - 1)) * actionSpacing
        let visibleAmount = exposedWidth - trailingInset - threshold + actionWidth
        return max(0, min(1, visibleAmount / actionWidth))
    }

    private func fullSwipeCommitProgress(exposedWidth: CGFloat) -> CGFloat {
        let start = revealWidth
        let end = revealWidth + maxOverswipe * 0.55
        guard end > start else { return 0 }
        return max(0, min(1, (exposedWidth - start) / (end - start)))
    }

    private func primaryActionWidth(exposedWidth: CGFloat, commitProgress: CGFloat) -> CGFloat {
        let available = max(actionWidth, exposedWidth - trailingInset)
        return actionWidth + ((available - actionWidth) * commitProgress)
    }

    private func backgroundFill(
        for tint: Color,
        isPrimary: Bool,
        progress: CGFloat,
        commitProgress: CGFloat
    ) -> some ShapeStyle {
        if isPrimary {
            return AnyShapeStyle(tint.opacity(0.14 + (0.10 * progress) + (0.48 * commitProgress)))
        }

        return AnyShapeStyle(tint.opacity((0.14 + (0.08 * progress)) * (1 - (commitProgress * 0.65))))
    }

    private func primaryForeground(
        for tint: Color,
        isPrimary: Bool,
        commitProgress: CGFloat
    ) -> some ShapeStyle {
        if isPrimary, commitProgress > 0.72 {
            return AnyShapeStyle(.white.opacity(0.96))
        }

        return AnyShapeStyle(tint)
    }

    private func closeRow(animation: Animation? = nil) {
        let updates = {
            offsetX = 0
            if openRowID == rowID {
                openRowID = nil
            }
        }

        if let animation {
            withAnimation(animation, updates)
        } else {
            updates()
        }
    }
}

private struct HorizontalSwipePanGesture: UIGestureRecognizerRepresentable {
    let isEnabled: Bool
    let allowsRightSwipeToClose: Bool
    let onBegan: () -> Void
    let onChanged: (CGFloat) -> Void
    let onEnded: (_ translationX: CGFloat, _ predictedEndX: CGFloat) -> Void
    let onCancelled: () -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator()
    }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let recognizer = UIPanGestureRecognizer()
        recognizer.maximumNumberOfTouches = 1
        recognizer.delegate = context.coordinator
        recognizer.cancelsTouchesInView = true
        recognizer.delaysTouchesBegan = false
        recognizer.delaysTouchesEnded = false
        context.coordinator.isEnabled = isEnabled
        context.coordinator.allowsRightSwipeToClose = allowsRightSwipeToClose
        return recognizer
    }

    func updateUIGestureRecognizer(_ recognizer: UIPanGestureRecognizer, context: Context) {
        context.coordinator.isEnabled = isEnabled
        context.coordinator.allowsRightSwipeToClose = allowsRightSwipeToClose
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        let translationX = recognizer.translation(in: recognizer.view).x
        let velocityX = recognizer.velocity(in: recognizer.view).x
        let predictedEndX = translationX + (velocityX * 0.12)

        switch recognizer.state {
        case .began:
            onBegan()
            onChanged(translationX)
        case .changed:
            onChanged(translationX)
        case .ended:
            onEnded(translationX, predictedEndX)
        case .cancelled, .failed:
            onCancelled()
        default:
            break
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var isEnabled = true
        var allowsRightSwipeToClose = false

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard isEnabled, let pan = gestureRecognizer as? UIPanGestureRecognizer else {
                return false
            }

            let velocity = pan.velocity(in: pan.view)
            guard abs(velocity.x) > abs(velocity.y) * 1.2 else { return false }
            if velocity.x < 0 {
                return true
            }
            return allowsRightSwipeToClose && velocity.x > 0
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }
}
