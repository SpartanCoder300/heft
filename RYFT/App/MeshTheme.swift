// iOS 26+ only. No #available guards.

import SwiftUI

/// Color palette and state arrays for the Pro mesh background.
///
/// Three moments. That's it.
/// 1. Set logged → steel-blue overhead flare
/// 2. PR → amber floods the screen (two-stage: hot flash → sustained bloom)
/// 3. Workout complete → gold wash
///
/// Everything else is warm-neutral charcoal — aged concrete and raw iron,
/// not colored. Events fire against that neutral so each rep has something
/// to push against.
enum MeshTheme {

    // MARK: - Warm-Neutral Rest Palette (stone)
    // Used for the ambient base state and session intensity blend.
    // No hue bias — like concrete under tungsten. Slightly warm so it
    // doesn't feel clinical, but reads as "off" compared to any event color.

    /// Near-black warm concrete — corners and shadow regions.
    private static let stone0 = Color(red: 0.038, green: 0.036, blue: 0.032)
    /// Center shadow — gap between the two light sources.
    private static let stone1 = Color(red: 0.052, green: 0.050, blue: 0.046)
    /// Floor reflection — cool-ish, barely visible at rest.
    private static let stone2 = Color(red: 0.075, green: 0.072, blue: 0.068)
    /// Overhead tungsten — the single visible light source at rest.
    private static let stone3 = Color(red: 0.120, green: 0.110, blue: 0.095)
    /// Bright tungsten — overhead at full draw during a pulse. Same warmth, more output.
    private static let stoneBright = Color(red: 0.195, green: 0.178, blue: 0.152)
    /// Peak tungsten — every overhead at full draw. Only used for workout complete.
    private static let stonePeak = Color(red: 0.285, green: 0.260, blue: 0.222)

    // MARK: - Steel-Blue Event Palette (iron)
    // Only used for the set-logged pulse and workout-started flash.
    // Blue channel ≈ 2× red — reads as cool steel, not colorless.
    // Transitioning from warm stone → blue iron is what makes each set feel physical.

    /// Near-black steel — event corner anchor.
    private static let iron0 = Color(red: 0.035, green: 0.040, blue: 0.075)
    /// Edge mids — barely-lit steel.
    private static let iron1 = Color(red: 0.065, green: 0.080, blue: 0.145)
    /// Pulse edges / floor surge.
    private static let iron2 = Color(red: 0.110, green: 0.135, blue: 0.230)
    /// Center glow — overhead source during pulse.
    private static let iron3 = Color(red: 0.175, green: 0.210, blue: 0.355)
    /// Pulse center burst.
    private static let iron4 = Color(red: 0.260, green: 0.305, blue: 0.490)
    /// Peak flare — absolute ceiling, workout-start fill.
    private static let iron5 = Color(red: 0.360, green: 0.415, blue: 0.600)

    // MARK: - Amber/PR Palette

    private static let amberDeep = Color(red: 0.100, green: 0.055, blue: 0.008)
    private static let amberMid  = Color(red: 0.220, green: 0.125, blue: 0.015)
    private static let amberGlow = Color(red: 0.310, green: 0.185, blue: 0.020)
    /// Hot flash — the initial PR snap, almost too bright.
    private static let amberHot  = Color(red: 0.460, green: 0.285, blue: 0.030)

    // MARK: - Session Intensity Interpolation

    private struct RGB {
        let r, g, b: Double
        func blended(with other: RGB, t: Double) -> Color {
            Color(red: r + (other.r - r) * t,
                  green: g + (other.g - g) * t,
                  blue: b + (other.b - b) * t)
        }
    }

    // Resting layout — two warm sources, everything else near-black:
    //   TC = overhead tungsten (brightest)
    //   BC = floor reflection (dimmer, cooler)
    //   Center = shadow between sources
    //   Corners/sides = near-black concrete
    private static let baseRGB: [RGB] = [
        RGB(r: 0.038, g: 0.036, b: 0.032),  // TL — dark corner (stone0)
        RGB(r: 0.120, g: 0.110, b: 0.095),  // TC — overhead tungsten (stone3)
        RGB(r: 0.038, g: 0.036, b: 0.032),  // TR — dark corner (stone0)
        RGB(r: 0.038, g: 0.036, b: 0.032),  // ML — dark side (stone0)
        RGB(r: 0.052, g: 0.050, b: 0.046),  // center — shadow (stone1)
        RGB(r: 0.038, g: 0.036, b: 0.032),  // MR — dark side (stone0)
        RGB(r: 0.038, g: 0.036, b: 0.032),  // BL — dark corner (stone0)
        RGB(r: 0.075, g: 0.072, b: 0.068),  // BC — floor reflection (stone2)
        RGB(r: 0.038, g: 0.036, b: 0.032),  // BR — dark corner (stone0)
    ]

    // At full intensity both sources brighten — still warm, just more presence.
    private static let intenseRGB: [RGB] = [
        RGB(r: 0.065, g: 0.060, b: 0.053),  // TL — wakes up
        RGB(r: 0.185, g: 0.168, b: 0.145),  // TC — overhead peaks
        RGB(r: 0.065, g: 0.060, b: 0.053),  // TR — wakes up
        RGB(r: 0.060, g: 0.057, b: 0.052),  // ML — wakes up
        RGB(r: 0.082, g: 0.078, b: 0.070),  // center — lifts slightly
        RGB(r: 0.060, g: 0.057, b: 0.052),  // MR — wakes up
        RGB(r: 0.038, g: 0.036, b: 0.032),  // BL — stays dark (anchor)
        RGB(r: 0.115, g: 0.108, b: 0.098),  // BC — reflection brightens
        RGB(r: 0.038, g: 0.036, b: 0.032),  // BR — stays dark (anchor)
    ]

    /// Returns base colors blended toward the intense palette.
    /// - Parameter intensity: 0 = fresh session, 1.0 = 20+ sets logged.
    static func base(intensity: Double) -> [Color] {
        let t = max(0, min(1, intensity))
        return zip(baseRGB, intenseRGB).map { b, i in b.blended(with: i, t: t) }
    }

    // MARK: - Grid Points (3×3, asymmetric)

    static let gridPoints: [SIMD2<Float>] = [
        SIMD2(0.0, 0.0),     SIMD2(0.48, -0.04),  SIMD2(1.0, 0.0),
        SIMD2(-0.03, 0.46),  SIMD2(0.50, 0.48),   SIMD2(1.03, 0.52),
        SIMD2(0.0, 1.0),     SIMD2(0.52, 1.04),   SIMD2(1.0, 1.0),
    ]

    // MARK: - State Color Arrays

    /// Workout started — warm overhead flares wide, like gym lights coming on.
    /// More spread than a set pulse; settles back over 0.5s.
    static let started: [Color] = [
        stone1, stoneBright, stone1,
        stone1, stone2,      stone1,
        stone0, stone2,      stone0,
    ]

    /// Set logged — overhead brightens, same warmth. The room responding to effort.
    static let pulse: [Color] = [
        stone0, stoneBright, stone0,
        stone0, stone1,      stone0,
        stone0, stone2,      stone0,
    ]

    /// Exercise complete — overhead + floor both lift. One tier above set-logged.
    static let exercisePulse: [Color] = [
        stone0, stoneBright, stone0,
        stone0, stone2,      stone0,
        stone0, stone2,      stone0,
    ]

    /// PR — initial hot amber flash. Top brighter, bottom cooler.
    static let prPeak: [Color] = [
        amberMid,  amberHot,  amberMid,
        amberMid,  amberHot,  amberMid,
        amberDeep, amberMid,  amberDeep,
    ]

    /// PR — sustained amber bloom after the flash settles.
    static let prBloom: [Color] = [
        amberDeep, amberGlow, amberDeep,
        amberDeep, amberMid,  amberDeep,
        amberDeep, amberMid,  amberDeep,
    ]

    /// Workout complete — every overhead at full draw. The room fully lit, warm white.
    static let complete: [Color] = [
        stone1,       stonePeak,   stone1,
        stone2,       stoneBright, stone2,
        stone1,       stoneBright, stone1,
    ]

    // MARK: - Transition Durations

    static func transitionDuration(for state: MeshState) -> TimeInterval {
        switch state {
        case .base:             return 1.5
        case .workoutStarted:   return 0.5
        case .setLogged:        return 0.15
        case .exerciseComplete: return 0.15
        case .prBloom:          return 0.20
        case .workoutComplete:  return 0.8
        }
    }

    /// Bloom down to sustained amber (stage 2 of PR sequence).
    static let prSettle: TimeInterval = 1.20
}

/// Workout events + base.
enum MeshState: Hashable {
    case base
    case workoutStarted
    case setLogged
    case exerciseComplete
    case prBloom
    case workoutComplete
}
