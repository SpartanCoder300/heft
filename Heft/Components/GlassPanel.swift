// iOS 26+ only. No #available guards.

import SwiftUI

struct GlassPanel<Content: View>: View {
    @ViewBuilder private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity)
            .frame(minHeight: DesignTokens.Layout.placeholderPanelHeight)
            .background {
                RoundedRectangle(cornerRadius: Radius.sheet, style: .continuous)
                    .fill(.clear)
                    .glassEffect(.regular.tint(.heftSurface.opacity(DesignTokens.Opacity.glassTint)))
            }
    }
}
