// iOS 26+ only. No #available guards.

import SwiftUI

struct PlaceholderScreen: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        ZStack {
            Color.heftBackground
                .ignoresSafeArea()

            GlassPanel {
                VStack(spacing: Spacing.md) {
                    Image(systemName: systemImage)
                        .font(.system(size: DesignTokens.Icon.placeholder))
                        .foregroundStyle(Color.heftAccent)

                    Text(title)
                        .font(Typography.title)
                        .foregroundStyle(Color.textPrimary)

                    Text(subtitle)
                        .font(Typography.body)
                        .foregroundStyle(Color.textMuted)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: DesignTokens.Layout.placeholderContentWidth)
            }
            .padding(.horizontal, Spacing.lg)
        }
    }
}
