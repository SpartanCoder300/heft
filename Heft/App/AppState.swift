// iOS 26+ only. No #available guards.

import Observation
import SwiftData
import Foundation

enum AppTab: Hashable {
    case home
    case history
    case settings
}

@Observable
final class AppState {
    var selectedTab: AppTab = .home
    var activeWorkoutID: UUID?
    var isShowingActiveWorkout: Bool = false
    var pendingRoutineID: UUID? = nil
    /// Set when the user repeats a past session. Mutually exclusive with pendingRoutineID.
    var pendingSessionID: UUID? = nil

    var accentTheme: AccentTheme = {
        let raw = UserDefaults.standard.string(forKey: "heft.accentTheme") ?? ""
        return AccentTheme(rawValue: raw) ?? .midnightStrength
    }() {
        didSet {
            UserDefaults.standard.set(accentTheme.rawValue, forKey: "heft.accentTheme")
        }
    }
}
