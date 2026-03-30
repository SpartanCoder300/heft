// iOS 26+ only. No #available guards.

import SwiftUI

struct HomeGreetingView: View {
    private var headline: String {
        let calendar = Calendar.current
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: .now) ?? 1
        let phrases = [
            "Ready to lift?",
            "Back under the bar?",
            "Time to get after it.",
            "What are we hitting today?",
            "Let’s build something.",
            "Clock in. Lift heavy."
        ]
        return phrases[(dayOfYear - 1) % phrases.count]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(Date.now.formatted(.dateTime.weekday(.wide)))
                .font(Typography.caption)
                .foregroundStyle(Color.textFaint)
                .textCase(.uppercase)
                .tracking(1)
            Text(headline)
                .font(Typography.display)
                .fontWeight(.bold)
                .foregroundStyle(Color.textPrimary)
        }
    }
}

#Preview {
    HomeGreetingView()
        .padding()
        .preferredColorScheme(.dark)
}
