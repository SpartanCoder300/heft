// iOS 26+ only. No #available guards.

import SwiftUI

enum AccentTheme: String, CaseIterable, Identifiable {
    case midnight
    case graphite
    case ember
    case mesh           // Pro only — placeholder

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .midnight: "Midnight"
        case .graphite: "Graphite"
        case .ember:    "Ember"
        case .mesh:     "Dynamic Mesh"
        }
    }

    var accentColor: Color {
        switch self {
        case .midnight: Color("Accent")
        case .graphite: Color("AccentGraphite")
        case .ember:    Color("AccentEmber")
        case .mesh:     Color("AccentMesh")
        }
    }

    var backgroundColor: Color {
        switch self {
        case .midnight: Color("BackgroundMidnight")
        case .graphite: Color("BackgroundGraphite")
        case .ember:    Color("BackgroundEmber")
        case .mesh:     Color("BackgroundMidnight")
        }
    }

    var isPro: Bool { self == .mesh }
}

// Inject active theme into the SwiftUI environment so any view can read it
// without going through AppState directly.
private struct HeftThemeKey: EnvironmentKey {
    static let defaultValue: AccentTheme = .midnight
}

extension EnvironmentValues {
    var heftTheme: AccentTheme {
        get { self[HeftThemeKey.self] }
        set { self[HeftThemeKey.self] = newValue }
    }
}
