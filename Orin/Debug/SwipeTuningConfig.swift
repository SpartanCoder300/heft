// iOS 26+ only. No #available guards.
// Debug-only tuning config — not user-facing.

import CoreGraphics

struct SwipeTuningConfig {
    /// Points of horizontal drag to advance weight by one step.
    var weightPointsPerStep: CGFloat = 18

    /// Points of horizontal drag to advance reps by one step.
    var repsPointsPerStep: CGFloat = 25

    /// Minimum horizontal drag distance before the gesture locks in.
    var dragActivationThreshold: CGFloat = 7

    /// Whether fast flings apply extra momentum steps.
    var momentumEnabled: Bool = true

    /// Velocity (pt/s) required to trigger a momentum burst.
    var momentumVelocityThreshold: CGFloat = 1050

    /// Max extra steps applied by momentum on the weight control.
    var weightMaxMomentumSteps: Int = 3

    /// Max extra steps applied by momentum on the reps control.
    var repsMaxMomentumSteps: Int = 1

    /// Duration (s) of the momentum animation burst.
    var momentumDuration: Double = 0.16

    /// How many points the control lifts above the touch point while dragging.
    var activeLiftAmount: CGFloat = 50
}
