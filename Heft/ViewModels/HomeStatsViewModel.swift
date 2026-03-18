// iOS 26+ only. No #available guards.

import Foundation
import SwiftData
import Observation

@Observable
@MainActor
final class HomeStatsViewModel {
    private(set) var streakLabel: String = "—"
    private(set) var thisWeekLabel: String = "—"
    private(set) var prCountLabel: String = "—"

    private var refreshTask: Task<Void, Never>?

    func update(container: ModelContainer) {
        refreshTask?.cancel()
        refreshTask = Task { await refreshStats(container: container) }
    }

    private func refreshStats(container: ModelContainer) async {
        let actor = HomeStatsActor(modelContainer: container)
        async let streak = actor.currentStreak()
        async let thisWeek = actor.sessionCountThisWeek()
        async let prs = actor.prCountThisWeek()

        let (s, w, p) = await (streak, thisWeek, prs)
        guard !Task.isCancelled else { return }

        streakLabel = s > 0 ? "\(s)" : "—"
        thisWeekLabel = w > 0 ? "\(w)" : "—"
        prCountLabel = p > 0 ? "\(p)" : "—"
    }
}
