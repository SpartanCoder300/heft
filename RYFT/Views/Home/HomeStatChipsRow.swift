// iOS 26+ only. No #available guards.

import SwiftUI

struct HomeStatChipsRow: View {
    let stats: HomeStatsViewModel
    @Environment(\.ryftTheme) private var theme

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
    var valueColor: Color = Color.textPrimary
    var isAccented: Bool = false
    var isHighlighted: Bool = false

    @Environment(\.ryftCardMaterial) private var cardMaterial

    var body: some View {
        ZStack(alignment: .leading) {
            // ── Watermark ────────────────────────────────────────────
            Image(systemName: icon)
                .font(.system(size: 54, weight: .bold))
                .foregroundStyle(iconColor.opacity(isAccented ? 0.15 : isHighlighted ? 0.18 : 0.13))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .offset(x: 10, y: 10)

            // ── Content ──────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 3) {
                Text(value)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(isAccented ? iconColor : .primary)
                    .monospacedDigit()
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isAccented ? iconColor.opacity(0.7) : isHighlighted ? iconColor.opacity(0.6) : Color.textFaint)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                .fill(cardMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                        .fill(iconColor.opacity(isAccented ? 0.15 : isHighlighted ? 0.12 : 0.10))
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                .strokeBorder(
                    isAccented ? iconColor.opacity(0.25) : isHighlighted ? iconColor.opacity(0.18) : .white.opacity(0.07),
                    lineWidth: isAccented || isHighlighted ? 1 : 0.5
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
        .proGlass()
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
        .environment(MeshEngine())
        .preferredColorScheme(.dark)
}
