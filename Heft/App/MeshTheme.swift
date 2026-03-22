// iOS 26+ only. No #available guards.

import SwiftUI

/// Color palette and state arrays for the Pro mesh background.
///
/// Three moments. That's it.
/// 1. Set logged → overhead lights flare
/// 2. PR → amber floods the screen (two-stage: hot flash → sustained bloom)
/// 3. Workout complete → green wash
///
/// Everything else is static dark steel — two light sources (overhead + floor
/// reflection), dark center and sides. Think dim gym at 5 AM, not a nightclub.
enum MeshTheme {

    // MARK: - Iron/Steel Palette
    // Desaturated cool grays with a subtle blue undertone that gets more neutral
    // as luminance increases — mimics how real steel reads under mixed lighting.
    // Blue channel is ~1.5× red in darks, ~1.4× in brights.

    /// Near-black — sides, corners, center shadow.
    private static let iron0 = Color(red: 0.030, green: 0.033, blue: 0.050)
    /// Dark steel — barely-lit surfaces.
    private static let iron1 = Color(red: 0.050, green: 0.056, blue: 0.078)
    /// Mid steel — secondary light spill (floor reflection).
    private static let iron2 = Color(red: 0.078, green: 0.086, blue: 0.115)
    /// Edge glow — primary light spill (overhead).
    private static let iron3 = Color(red: 0.110, green: 0.120, blue: 0.158)
    /// Pulse peak — brightest during set-logged flare.
    private static let iron4 = Color(red: 0.155, green: 0.170, blue: 0.218)
    /// Overhead flare — strong pulse at top-center.
    private static let iron5 = Color(red: 0.235, green: 0.258, blue: 0.330)
    /// Peak pulse — absolute ceiling of the flare.
    private static let iron6 = Color(red: 0.310, green: 0.342, blue: 0.438)

    // MARK: - Amber/PR Palette

    private static let amberDeep = Color(red: 0.100, green: 0.055, blue: 0.008)
    private static let amberMid  = Color(red: 0.220, green: 0.125, blue: 0.015)
    private static let amberGlow = Color(red: 0.310, green: 0.185, blue: 0.020)
    /// Hot flash — the initial PR snap, almost too bright.
    private static let amberHot  = Color(red: 0.460, green: 0.285, blue: 0.030)

    // MARK: - Green/Complete Palette

    private static let greenDeep = Color(red: 0.012, green: 0.072, blue: 0.032)
    private static let greenMid  = Color(red: 0.025, green: 0.145, blue: 0.062)
    private static let greenGlow = Color(red: 0.040, green: 0.220, blue: 0.090)
    /// Peak green — vivid enough to feel like a finish line crossed.
    private static let greenHot  = Color(red: 0.055, green: 0.320, blue: 0.125)

    // MARK: - Session Intensity Interpolation

    /// Linear blend between base (empty session) and intense (20+ sets logged).
    /// Two-source lighting: overhead (top-center) + floor reflection (bottom-center).
    /// Center and sides stay dark for depth.
    private struct RGB {
        let r, g, b: Double
        func blended(with other: RGB, t: Double) -> Color {
            Color(red: r + (other.r - r) * t,
                  green: g + (other.g - g) * t,
                  blue: b + (other.b - b) * t)
        }
    }

    // Two-source gym lighting layout:
    //   TC = overhead light (brightest)
    //   BC = floor reflection (dimmer, cooler)
    //   Center = dark (depth/shadow between the two sources)
    //   Sides = dark (light doesn't reach)
    private static let baseRGB: [RGB] = [
        RGB(r: 0.030, g: 0.033, b: 0.050),  // TL — dark corner
        RGB(r: 0.110, g: 0.120, b: 0.158),  // TC — overhead light (iron3)
        RGB(r: 0.030, g: 0.033, b: 0.050),  // TR — dark corner
        RGB(r: 0.030, g: 0.033, b: 0.050),  // ML — dark side
        RGB(r: 0.050, g: 0.056, b: 0.078),  // center — shadow between sources (iron1)
        RGB(r: 0.030, g: 0.033, b: 0.050),  // MR — dark side
        RGB(r: 0.030, g: 0.033, b: 0.050),  // BL — dark corner
        RGB(r: 0.078, g: 0.086, b: 0.115),  // BC — floor reflection (iron2)
        RGB(r: 0.030, g: 0.033, b: 0.050),  // BR — dark corner
    ]

    // At full intensity, both light sources intensify and sides wake up slightly.
    private static let intenseRGB: [RGB] = [
        RGB(r: 0.050, g: 0.056, b: 0.078),  // TL — wakes up
        RGB(r: 0.155, g: 0.170, b: 0.218),  // TC — overhead peaks (iron4)
        RGB(r: 0.050, g: 0.056, b: 0.078),  // TR — wakes up
        RGB(r: 0.050, g: 0.056, b: 0.078),  // ML — wakes up
        RGB(r: 0.078, g: 0.086, b: 0.115),  // center — lifts slightly (iron2)
        RGB(r: 0.050, g: 0.056, b: 0.078),  // MR — wakes up
        RGB(r: 0.030, g: 0.033, b: 0.050),  // BL — stays dark (anchor)
        RGB(r: 0.110, g: 0.120, b: 0.158),  // BC — reflection brightens (iron3)
        RGB(r: 0.030, g: 0.033, b: 0.050),  // BR — stays dark (anchor)
    ]

    /// Returns base colors blended toward the intense palette.
    /// - Parameter intensity: 0 = fresh session, 1.0 = 20+ sets logged.
    static func base(intensity: Double) -> [Color] {
        let t = max(0, min(1, intensity))
        return zip(baseRGB, intenseRGB).map { b, i in b.blended(with: i, t: t) }
    }

    // MARK: - Grid Points (3×3, asymmetric)
    // Top-center and bottom-center are the two light source control points.
    // They're shifted slightly off-grid to break symmetry and feel organic.

    static let gridPoints: [SIMD2<Float>] = [
        SIMD2(0.0, 0.0),    SIMD2(0.48, -0.04),  SIMD2(1.0, 0.0),
        SIMD2(-0.03, 0.46),  SIMD2(0.50, 0.48),   SIMD2(1.03, 0.52),
        SIMD2(0.0, 1.0),    SIMD2(0.52, 1.04),   SIMD2(1.0, 1.0),
    ]

    // MARK: - State Color Arrays (two-source lighting maintained)

    /// Workout started — all lights come on simultaneously. Even illumination,
    /// no directional bias. Settles back to two-source base over 1.5s.
    static let started: [Color] = [
        iron2, iron4, iron2,
        iron3, iron5, iron3,
        iron2, iron4, iron2,
    ]

    /// Set logged — overhead lights blast, reflection surges, whole room wakes up.
    static let pulse: [Color] = [
        iron2, iron6, iron2,
        iron2, iron4, iron2,
        iron1, iron5, iron1,
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

    /// Workout complete — green wash. Light sources go green, center fills.
    static let complete: [Color] = [
        greenDeep, greenHot,  greenDeep,
        greenMid,  greenGlow, greenMid,
        greenDeep, greenGlow, greenDeep,
    ]

    // MARK: - Transition Durations

    /// Duration for each state transition. Animation is applied at the view layer.
    static func transitionDuration(for state: MeshState) -> TimeInterval {
        switch state {
        case .base:            return 1.5
        case .workoutStarted:  return 0.5   // deliberate build, not a snap
        case .setLogged:       return 0.15
        case .prBloom:         return 0.20   // stage 1 — prSettle handled separately
        case .workoutComplete: return 0.8
        }
    }

    /// Bloom down to sustained amber (stage 2 of PR sequence).
    static let prSettle: TimeInterval = 1.20
}

/// Four workout events + base. Nothing else.
enum MeshState: Hashable {
    case base
    case workoutStarted
    case setLogged
    case prBloom
    case workoutComplete
}
