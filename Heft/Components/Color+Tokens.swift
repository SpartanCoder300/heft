// iOS 26+ only. No #available guards.

import SwiftUI

extension Color {
    // ── Theme accents ─────────────────────────────────────────────────────────
    static var heftAccent: Color          { Color("Accent") }
    static var heftAccentGraphite: Color  { Color("AccentGraphite") }
    static var heftAccentEmber: Color     { Color("AccentEmber") }
    static var heftAccentMesh: Color      { Color("AccentMesh") }

    // ── Theme backgrounds ─────────────────────────────────────────────────────
    // Use theme.backgroundColor in views rather than these directly.
    static var heftBackground: Color      { Color("BackgroundMidnight") }

    // ── Shared surfaces ───────────────────────────────────────────────────────
    static var heftSurface: Color         { Color("Surface") }

    // ── Semantic ──────────────────────────────────────────────────────────────
    static var heftRed: Color             { Color("HeftRed") }
    static var heftGreen: Color           { Color("HeftGreen") }
    static var heftAmber: Color           { Color("HeftAmber") }
    static var heftGold: Color            { Color("HeftGold") }

    // ── Text ──────────────────────────────────────────────────────────────────
    static var textPrimary: Color { .white.opacity(DesignTokens.Opacity.textPrimary) }
    static var textMuted: Color   { .white.opacity(DesignTokens.Opacity.textMuted) }
    static var textFaint: Color   { .white.opacity(DesignTokens.Opacity.textFaint) }
}
