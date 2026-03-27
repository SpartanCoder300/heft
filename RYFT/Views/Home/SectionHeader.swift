// iOS 26+ only. No #available guards.

import SwiftUI

struct SectionHeader: View {
    let title: String
    var detail: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(Typography.caption)
                .fontWeight(.semibold)
                .foregroundStyle(Color.textMuted)
                .textCase(.uppercase)
                .tracking(0.8)
            Spacer()
            if let detail {
                Text(detail)
                    .font(Typography.caption)
                    .foregroundStyle(Color.textMuted)
            }
        }
    }
}

#Preview {
    VStack(spacing: Spacing.md) {
        SectionHeader(title: "Routines")
        SectionHeader(title: "Recent", detail: "See All")
    }
    .padding()
    .preferredColorScheme(.dark)
}
