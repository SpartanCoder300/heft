// iOS 26+ only. No #available guards.
// ⚠️ Add this file to the RYFTWidgets target in Xcode:
//    Select file → File Inspector (⌥⌘1) → check RYFTWidgets under Target Membership.

import ActivityKit
import Foundation
import SwiftUI

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

        /// Theme accent colour encoded as raw sRGB doubles — Color is not Codable.
        /// Nil-optional so older persisted states decode without crashing.
        let accentR: Double?
        let accentG: Double?
        let accentB: Double?

        var isResting: Bool { restEndsAt != nil }

        /// Reconstructed accent Color. Falls back to brand green if fields are absent.
        var accentColor: Color {
            guard let r = accentR, let g = accentG, let b = accentB else {
                return Color(red: 0.204, green: 0.827, blue: 0.600)
            }
            return Color(red: r, green: g, blue: b)
        }
    }
}
