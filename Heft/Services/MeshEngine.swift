// iOS 26+ only. No #available guards.

import SwiftUI

/// Drives the Pro mesh background. Three events, zero idle cost.
///
/// Set logged → pulse. PR → amber flood. Workout complete → gold.
/// Everything else is a static dark gradient. No timers, no loops.
///
/// Animation is applied at the view layer via `.animation(value: colors)`.
/// `transitionDuration` is updated before each color change so the view
/// always picks up the correct duration.
@Observable @MainActor
final class MeshEngine {

    /// 9 colors for the 3×3 MeshGradient.
    private(set) var colors: [Color] = MeshTheme.base(intensity: 0)

    /// Duration the view should use when animating the next color change.
    private(set) var transitionDuration: TimeInterval = 1.0

    /// Index of the exercise whose card should shimmer on the next setLogged pulse.
    var lastLoggedExerciseIndex: Int? = nil

    var state: MeshState = .base {
        didSet {
            guard state != oldValue else { return }
            prSettleTask?.cancel()
            prSettleTask = nil
            transition(to: state)
        }
    }

    /// 0 = fresh/empty session, 1.0 = 20+ sets logged.
    /// Call `updateIntensity(_:)` rather than setting this directly during set-logging
    /// so the slow 2.5s animation is only started when no pulse is about to fire.
    private(set) var sessionIntensity: Double = 0

    /// Updates session intensity. Pass `pulse: true` when called alongside a set-logged
    /// event — the intensity is recorded but the slow ambient animation is skipped
    /// because the pulse is about to override colors anyway.
    func updateIntensity(_ newValue: Double, pulse: Bool) {
        guard newValue != sessionIntensity else { return }
        sessionIntensity = newValue
        guard state == .base, !pulse else { return }
        transitionDuration = 2.5
        colors = MeshTheme.base(intensity: sessionIntensity)
    }

    private var prSettleTask: Task<Void, Never>?

    private func transition(to state: MeshState) {
        switch state {
        case .base:
            transitionDuration = MeshTheme.transitionDuration(for: .base)
            colors = MeshTheme.base(intensity: sessionIntensity)

        case .workoutStarted:
            transitionDuration = MeshTheme.transitionDuration(for: .workoutStarted)
            colors = MeshTheme.started

        case .setLogged:
            transitionDuration = MeshTheme.transitionDuration(for: .setLogged)
            colors = MeshTheme.pulse

        case .prBloom:
            // Stage 1: hot flash
            transitionDuration = MeshTheme.transitionDuration(for: .prBloom)
            colors = MeshTheme.prPeak
            // Stage 2: settle to sustained amber
            prSettleTask = Task {
                try? await Task.sleep(for: .milliseconds(220))
                guard !Task.isCancelled else { return }
                transitionDuration = MeshTheme.prSettle
                colors = MeshTheme.prBloom
            }

        case .workoutComplete:
            transitionDuration = MeshTheme.transitionDuration(for: .workoutComplete)
            colors = MeshTheme.complete
        }
    }
}
