// iOS 26+ only. No #available guards.
// ⚠️ Add this file to the RYFTWidgets target in Xcode:
//    Select file → File Inspector (⌥⌘1) → check RYFTWidgets under Target Membership.

import ActivityKit
import Foundation

struct WorkoutActivityAttributes: ActivityAttributes {
    /// Static — set once when the workout starts.
    let routineName: String

    struct ContentState: Codable, Hashable {
        let startedAt: Date
        let currentExercise: String
        let setsLogged: Int

        /// Non-nil only while rest is active.
        let restEndsAt: Date?
        let totalRestDuration: TimeInterval?

        var isResting: Bool { restEndsAt != nil }
    }
}
