// iOS 26+ only. No #available guards.

import SwiftUI

extension Color {
    // ── Theme accents ─────────────────────────────────────────────────────────
    static var ryftAccent: Color          { Color("Accent") }
    static var ryftAccentGraphite: Color  { Color("AccentGraphite") }
    static var ryftAccentEmber: Color     { Color("AccentEmber") }
    static var ryftAccentMesh: Color      { Color("AccentMesh") }

    // ── Theme backgrounds ─────────────────────────────────────────────────────
    // Use theme.backgroundColor in views rather than these directly.
    static var ryftBackground: Color      { Color("BackgroundMidnight") }

    // ── Shared surfaces ───────────────────────────────────────────────────────
    static var ryftSurface: Color         { Color("Surface") }

    // ── Semantic ──────────────────────────────────────────────────────────────
    static var ryftRed: Color             { Color("RYFTRed") }
    static var ryftGreen: Color           { Color("RYFTGreen") }
    static var ryftAmber: Color           { Color("RYFTAmber") }
    static var ryftWarmup: Color          { Color("RYFTWarmup") }
    static var ryftGold: Color            { Color("RYFTGold") }
    static var ryftBlue: Color            { Color(red: 0.302, green: 0.490, blue: 0.996) }

    // ── Text ──────────────────────────────────────────────────────────────────
    static var textPrimary: Color { .white.opacity(DesignTokens.Opacity.textPrimary) }
    static var textMuted: Color   { .white.opacity(DesignTokens.Opacity.textMuted) }
    static var textFaint: Color   { .white.opacity(DesignTokens.Opacity.textFaint) }
}
