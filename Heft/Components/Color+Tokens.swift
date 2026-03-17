// iOS 26+ only. No #available guards.

import SwiftUI

extension Color {
    static var heftBackground: Color { Color("Background") }
    static var heftSurface: Color { Color("Surface") }
    static var heftAccent: Color { Color("Accent") }
    static var heftAccentEmber: Color { Color("AccentEmber") }
    static var heftAccentGraphite: Color { Color("AccentGraphite") }
    static var heftAccentAbyss: Color { Color("AccentAbyss") }
    static var heftAccentMesh: Color { Color("AccentMesh") }
    static var heftRed: Color { Color("HeftRed") }
    static var heftGreen: Color { Color("HeftGreen") }
    static var heftAmber: Color { Color("HeftAmber") }

    static var textPrimary: Color { .white.opacity(DesignTokens.Opacity.textPrimary) }
    static var textMuted: Color { .white.opacity(DesignTokens.Opacity.textMuted) }
    static var textFaint: Color { .white.opacity(DesignTokens.Opacity.textFaint) }
}
