// iOS 26+ only. No #available guards.

import SwiftUI

/// Tappable chip showing the set type (W / N / D). Cycles on tap with selection haptic.
struct SetTypeChip: View {
    let setType: SetType
    var onTap: (() -> Void)?

    var body: some View {
        Button {
            onTap?()
        } label: {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(chipColor)
                .frame(width: 26, height: 22)
                .background(chipColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(onTap == nil)
        .sensoryFeedback(.selection, trigger: setType)
    }

    private var label: String {
        switch setType {
        case .normal:  "N"
        case .warmup:  "W"
        case .dropset: "D"
        }
    }

    private var chipColor: Color {
        switch setType {
        case .normal:  Color.textFaint
        case .warmup:  Color.heftAmber
        case .dropset: Color.heftAccentAbyss
        }
    }
}
