// iOS 26+ only. No #available guards.

import SwiftUI

struct SummaryPRBadge: View {
    let weight: Double
    let reps: Int
    let formatWeight: (Double) -> String

    var body: some View {
        VStack(alignment: .trailing, spacing: 3) {
            PRBadge()
            Text("\(formatWeight(weight)) × \(reps)")
                .font(.caption2)
                .foregroundStyle(Color.OrinAmber.opacity(0.72))
        }
    }
}

// MARK: - Preview

#Preview {
    SummaryPRBadge(weight: 185, reps: 5, formatWeight: { w in
        w.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(w))" : String(format: "%.1f", w)
    })
    .padding()
    .preferredColorScheme(.dark)
}
