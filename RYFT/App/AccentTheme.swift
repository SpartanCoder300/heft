// iOS 26+ only. No #available guards.

import SwiftUI

enum AccentTheme: String, CaseIterable, Identifiable {
    case midnight
    case graphite
    case ember
    case mesh           // Pro only

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .midnight: "Midnight"
        case .graphite: "Graphite"
        case .ember:    "Ember"
        case .mesh:     "Lux"
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
        case .mesh:     Color("BackgroundMesh")
        }
    }

    var isPro: Bool { self == .mesh }
}

// Inject active theme into the SwiftUI environment so any view can read it
// without going through AppState directly.
private struct RYFTThemeKey: EnvironmentKey {
    static let defaultValue: AccentTheme = .midnight
}

// Card material — ultraThinMaterial for Pro/Mesh so cards become translucent
// windows into the mesh beneath. RegularMaterial for all other themes.
private struct RYFTCardMaterialKey: EnvironmentKey {
    static let defaultValue: Material = .regularMaterial
}

extension EnvironmentValues {
    var ryftTheme: AccentTheme {
        get { self[RYFTThemeKey.self] }
        set { self[RYFTThemeKey.self] = newValue }
    }

    var ryftCardMaterial: Material {
        get { self[RYFTCardMaterialKey.self] }
        set { self[RYFTCardMaterialKey.self] = newValue }
    }
}
