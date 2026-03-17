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
}
