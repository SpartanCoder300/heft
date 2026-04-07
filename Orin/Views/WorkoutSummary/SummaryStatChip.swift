// iOS 26+ only. No #available guards.

import SwiftUI

struct SummaryStatChip: View {
    let value: String
    let label: String
    @Environment(\.OrinCardMaterial) private var cardMaterial

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardMaterial, in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
        .proGlass()
    }
}

// MARK: - Preview

#Preview {
    HStack(spacing: 8) {
        SummaryStatChip(value: "45 min", label: "Duration")
        SummaryStatChip(value: "18", label: "Sets")
        SummaryStatChip(value: "12.4k lbs", label: "Volume")
    }
    .padding()
    .environment(\.OrinCardMaterial, .regularMaterial)
    .preferredColorScheme(.dark)
}
