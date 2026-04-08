// iOS 26+ only. No #available guards.
// Debug-only manager — not user-facing.

import Foundation
import Observation

@Observable
final class SwipeTuningManager {
    static let shared = SwipeTuningManager()

    private(set) var config: SwipeTuningConfig = .init()

    private enum Keys {
        static let weightPointsPerStep    = "SwipeTuning.weightPointsPerStep"
        static let repsPointsPerStep      = "SwipeTuning.repsPointsPerStep"
        static let dragActivationThreshold = "SwipeTuning.dragActivationThreshold"
        static let momentumEnabled         = "SwipeTuning.momentumEnabled"
        static let momentumVelocityThreshold = "SwipeTuning.momentumVelocityThreshold"
        static let weightMaxMomentumSteps  = "SwipeTuning.weightMaxMomentumSteps"
        static let repsMaxMomentumSteps    = "SwipeTuning.repsMaxMomentumSteps"
        static let momentumDuration        = "SwipeTuning.momentumDuration"
        static let activeLiftAmount        = "SwipeTuning.activeLiftAmount"
    }

    private init() { loadOverrides() }

    func update(_ transform: (inout SwipeTuningConfig) -> Void) {
        transform(&config)
        persist()
    }

    func reset() {
        config = SwipeTuningConfig()
        let d = UserDefaults.standard
        [
            Keys.weightPointsPerStep, Keys.repsPointsPerStep, Keys.dragActivationThreshold,
            Keys.momentumEnabled, Keys.momentumVelocityThreshold, Keys.weightMaxMomentumSteps,
            Keys.repsMaxMomentumSteps, Keys.momentumDuration, Keys.activeLiftAmount
        ].forEach { d.removeObject(forKey: $0) }
    }

    // MARK: - Private

    private func loadOverrides() {
        let d = UserDefaults.standard
        var c = SwipeTuningConfig()
        if let v = d.object(forKey: Keys.weightPointsPerStep) as? Double    { c.weightPointsPerStep    = CGFloat(v) }
        if let v = d.object(forKey: Keys.repsPointsPerStep) as? Double      { c.repsPointsPerStep      = CGFloat(v) }
        if let v = d.object(forKey: Keys.dragActivationThreshold) as? Double { c.dragActivationThreshold = CGFloat(v) }
        if let v = d.object(forKey: Keys.momentumEnabled) as? Bool           { c.momentumEnabled         = v }
        if let v = d.object(forKey: Keys.momentumVelocityThreshold) as? Double { c.momentumVelocityThreshold = CGFloat(v) }
        if let v = d.object(forKey: Keys.weightMaxMomentumSteps) as? Int     { c.weightMaxMomentumSteps  = v }
        if let v = d.object(forKey: Keys.repsMaxMomentumSteps) as? Int       { c.repsMaxMomentumSteps    = v }
        if let v = d.object(forKey: Keys.momentumDuration) as? Double        { c.momentumDuration        = v }
        if let v = d.object(forKey: Keys.activeLiftAmount) as? Double        { c.activeLiftAmount        = CGFloat(v) }
        config = c
    }

    private func persist() {
        let d = UserDefaults.standard
        d.set(Double(config.weightPointsPerStep),      forKey: Keys.weightPointsPerStep)
        d.set(Double(config.repsPointsPerStep),        forKey: Keys.repsPointsPerStep)
        d.set(Double(config.dragActivationThreshold),  forKey: Keys.dragActivationThreshold)
        d.set(config.momentumEnabled,                  forKey: Keys.momentumEnabled)
        d.set(Double(config.momentumVelocityThreshold), forKey: Keys.momentumVelocityThreshold)
        d.set(config.weightMaxMomentumSteps,           forKey: Keys.weightMaxMomentumSteps)
        d.set(config.repsMaxMomentumSteps,             forKey: Keys.repsMaxMomentumSteps)
        d.set(config.momentumDuration,                 forKey: Keys.momentumDuration)
        d.set(Double(config.activeLiftAmount),         forKey: Keys.activeLiftAmount)
    }
}
