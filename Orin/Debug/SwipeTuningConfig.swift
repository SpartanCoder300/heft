// iOS 26+ only. No #available guards.
// Debug-only tuning config — not user-facing.

import CoreGraphics

struct SwipeTuningConfig {
    /// Points of horizontal drag to advance weight by one step.
    var weightPointsPerStep: CGFloat = 16
    /// Points of horizontal drag to advance reps by one step.
    var repsPointsPerStep: CGFloat = 18
    /// Minimum horizontal drag distance before the gesture locks in.
    var dragActivationThreshold: CGFloat = 6
    /// Whether fast flings apply extra momentum steps.
    var momentumEnabled: Bool = true
    /// Velocity (pt/s) required to trigger a momentum burst.
    var momentumVelocityThreshold: CGFloat = 900
    /// Max extra steps applied by momentum on the weight control.
    var weightMaxMomentumSteps: Int = 4
    /// Max extra steps applied by momentum on the reps control.
    var repsMaxMomentumSteps: Int = 2
    /// Duration (s) of the momentum animation burst.
    var momentumDuration: Double = 0.15
    /// How many points the control lifts above the touch point while dragging.
    /// Needs to clear a typical thumb pad (~40–60pt), so values below ~40 leave
    /// the number hidden under the finger. 48pt is a good starting point.
    var activeLiftAmount: CGFloat = 48
}
