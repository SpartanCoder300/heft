// iOS 26+ only. No #available guards.

import Foundation
import Observation

@Observable @MainActor
final class RestTimerState {
    private(set) var startDate: Date? = nil
    private(set) var targetEndDate: Date? = nil
    private(set) var totalDuration: TimeInterval = 0
    var pulseCount: Int = 0

    var isActive: Bool { targetEndDate != nil }

    /// Returns 1.0 when full, 0.0 when expired. Nil when inactive.
    func progress(at now: Date) -> Double? {
        guard let start = startDate, let end = targetEndDate else { return nil }
        let total = end.timeIntervalSince(start)
        guard total > 0 else { return 0 }
        let remaining = end.timeIntervalSince(now)
        return max(0, min(1, remaining / total))
    }

    /// Formatted remaining time string, e.g. "1:30" or "0:05".
    func remainingLabel(at now: Date) -> String? {
        guard let end = targetEndDate else { return nil }
        let remaining = max(0, Int(ceil(end.timeIntervalSince(now))))
        let m = remaining / 60
        let s = remaining % 60
        return "\(m):\(String(format: "%02d", s))"
    }

    func tintColor(at now: Date) -> TimerTintPhase {
        guard let ratio = progress(at: now) else { return .calm }
        if ratio > 0.5 { return .calm }
        return .readySoon
    }

    /// Call from TimelineView on each tick to check for expiration.
    func tick(at now: Date) {
        guard let end = targetEndDate else { return }
        if now >= end {
            startDate = nil
            targetEndDate = nil
            totalDuration = 0
            pulseCount += 1
        }
    }

    func start(duration: TimeInterval) {
        let clamped = max(1, duration)
        let now = Date.now
        startDate = now
        targetEndDate = now.addingTimeInterval(clamped)
        totalDuration = clamped
    }

    /// For previews: simulate a timer that started `elapsed` seconds ago with a given total duration.
    func simulateInProgress(totalDuration duration: TimeInterval, elapsed: TimeInterval) {
        let now = Date.now
        startDate = now.addingTimeInterval(-elapsed)
        targetEndDate = now.addingTimeInterval(duration - elapsed)
        totalDuration = duration
    }

    func skip() {
        startDate = nil
        targetEndDate = nil
        totalDuration = 0
    }

    /// Positive delta adds time; negative subtracts. Remaining is clamped to at least 5 seconds.
    func adjust(seconds: TimeInterval) {
        guard let end = targetEndDate, let start = startDate else { return }
        let newEnd = max(Date.now.addingTimeInterval(5), end.addingTimeInterval(seconds))
        targetEndDate = newEnd
        totalDuration = newEnd.timeIntervalSince(start)
    }
}

enum TimerTintPhase: Equatable {
    case calm, readySoon
}
