// iOS 26+ only. No #available guards.

import SwiftUI

struct HomeStatChipsRow: View {
    let stats: HomeStatsViewModel
    @Environment(\.OrinTheme) private var theme

    var body: some View {
        HStack(spacing: Spacing.sm) {
            StatChip(label: "Day Streak", value: stats.streakLabel,
                     icon: "flame.fill", iconColor: theme.accentColor, isHighlighted: true)
            StatChip(label: "This Week", value: stats.thisWeekLabel,
                     icon: "figure.strengthtraining.traditional", iconColor: theme.accentColor)
            StatChip(label: "PRs", value: stats.prCountLabel,
                     icon: "trophy.fill", iconColor: theme.accentColor, isAccented: true)
        }
    }
}

// MARK: - Stat Chip

struct StatChip: View {
    let label: String
    let value: String
    let icon: String
    var iconColor: Color = Color.textPrimary
    var isAccented: Bool = false
    var isHighlighted: Bool = false

    @Environment(\.OrinCardMaterial) private var cardMaterial

    var body: some View {
        ZStack(alignment: .leading) {
            // ── Watermark ────────────────────────────────────────────
            Image(systemName: icon)
                .font(.system(size: 42, weight: .bold))
                .foregroundStyle(iconColor.opacity(isAccented ? 0.26 : isHighlighted ? 0.30 : 0.24))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .offset(x: 8, y: 8)

            // ── Content ──────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(isAccented ? iconColor : .white)
                    .monospacedDigit()
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(isAccented ? iconColor.opacity(0.80) : isHighlighted ? iconColor.opacity(0.78) : .white.opacity(0.55))
                    .textCase(.uppercase)
                    .tracking(0.45)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 76, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                .fill(cardMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                        .fill(iconColor.opacity(isAccented ? 0.15 : isHighlighted ? 0.12 : 0.10))
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
        .proGlass()
        .overlay {
            if isAccented || isHighlighted {
                RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                    .strokeBorder(
                        isAccented ? iconColor.opacity(0.25) : iconColor.opacity(0.18),
                        lineWidth: 1
                    )
            }
        }
    }
}

private struct HomeStatChipsRowPreview: View {
    @State private var stats = HomeStatsViewModel()

    var body: some View {
        HomeStatChipsRow(stats: stats)
            .task {
                stats.update(container: HomePreviewData.container)
            }
    }
}

#Preview {
    HomeStatChipsRowPreview()
        .padding()
        .preferredColorScheme(.dark)
}
