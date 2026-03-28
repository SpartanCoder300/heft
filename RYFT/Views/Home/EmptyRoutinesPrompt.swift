// iOS 26+ only. No #available guards.

import SwiftUI

struct EmptyRoutinesPrompt: View {
    let onTap: () -> Void
    @Environment(\.ryftTheme) private var theme

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: Spacing.sm) {
                Image(systemName: "list.bullet.clipboard")
                    .font(.system(size: DesignTokens.Icon.placeholder * 0.75))
                    .foregroundStyle(theme.accentColor)
                Text("Create your first routine")
                    .font(Typography.body)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.textPrimary)
                Text("Tap here to build a routine and launch sessions faster.")
                    .font(Typography.caption)
                    .foregroundStyle(Color.textMuted)
                    .multilineTextAlignment(.center)
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "plus.circle.fill")
                    Text("New Routine")
                        .fontWeight(.semibold)
                }
                .font(Typography.caption)
                .foregroundStyle(theme.accentColor)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.xs)
                .background(theme.accentColor.opacity(0.12), in: Capsule())
                .padding(.top, Spacing.xs)
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
            .proGlass(specular: false)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    EmptyRoutinesPrompt(onTap: {})
        .padding()
        .environment(\.ryftTheme, .midnight)
        .preferredColorScheme(.dark)
}
