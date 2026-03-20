// iOS 26+ only. No #available guards.

import SwiftUI

/// Tappable chip showing the set type (W / N / D).
/// Tap cycles the type. Long press shows a legend popover.
struct SetTypeChip: View {
    let setType: SetType
    var onTap: (() -> Void)?

    var body: some View {
        Text(label)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(chipColor)
            .frame(width: 24, height: 22)
            .background(chipColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
            // Expand hit area to HIG minimum without changing visual size
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .onTapGesture {
                guard let onTap else { return }
                onTap()
            }
            .allowsHitTesting(onTap != nil)
            .sensoryFeedback(.selection, trigger: setType)
            .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        switch setType {
        case .normal:  "Normal set"
        case .warmup:  "Warmup set"
        case .dropset: "Dropset"
        }
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
        case .dropset: Color.blue
        }
    }
}


#Preview("All types") {
    @Previewable @State var current: SetType = .normal
    HStack(spacing: 12) {
        SetTypeChip(setType: .normal,  onTap: { current = .normal })
        SetTypeChip(setType: .warmup,  onTap: { current = .warmup })
        SetTypeChip(setType: .dropset, onTap: { current = .dropset })
    }
    .padding()
}

#Preview("Interactive cycle") {
    @Previewable @State var setType: SetType = .normal
    let types = SetType.allCases
    SetTypeChip(setType: setType) {
        let idx = ((types.firstIndex(of: setType) ?? 0) + 1) % types.count
        setType = types[idx]
    }
    .padding()
}
