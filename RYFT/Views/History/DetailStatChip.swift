// iOS 26+ only. No #available guards.

import SwiftUI

struct DetailStatChip: View {
    let label: String
    let value: String
    @Environment(\.ryftCardMaterial) private var cardMaterial

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
                .lineLimit(1)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardMaterial, in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
        .proGlass(specular: false)
    }
}

// MARK: - Preview

#Preview {
    HStack(spacing: 8) {
        DetailStatChip(label: "Duration", value: "45 min")
        DetailStatChip(label: "Volume", value: "14.2k lbs")
        DetailStatChip(label: "Sets", value: "18")
    }
    .padding()
    .environment(\.ryftCardMaterial, .regularMaterial)
    .preferredColorScheme(.dark)
}
