// iOS 26+ only. No #available guards.

import SwiftUI

struct SetTypeLabel: View {
    let setType: SetType

    var body: some View {
        Text(label)
            .font(.caption2.weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
    }

    private var label: String {
        switch setType {
        case .warmup:  "W"
        case .dropset: "D"
        case .normal:  ""
        }
    }

    private var color: Color {
        switch setType {
        case .warmup:  Color.ryftWarmup
        case .dropset: Color.ryftBlue
        case .normal:  Color.textFaint
        }
    }
}

// MARK: - Preview

#Preview {
    HStack(spacing: 12) {
        SetTypeLabel(setType: .warmup)
        SetTypeLabel(setType: .dropset)
    }
    .padding()
    .preferredColorScheme(.dark)
}
