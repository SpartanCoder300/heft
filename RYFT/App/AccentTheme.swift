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

    /// Raw sRGB doubles for encoding into Live Activity ContentState.
    /// Color is not Codable so the widget reconstructs it from these values.
    var accentRGB: (r: Double, g: Double, b: Double) {
        switch self {
        case .midnight: return (0.486, 0.498, 0.961) // #7C7FF5
        case .graphite: return (0.557, 0.604, 0.671) // #8E9AAB
        case .ember:    return (0.910, 0.384, 0.165) // #E8622A
        case .mesh:     return (0.929, 0.902, 0.847) // #EDE6D8 warm white
        }
    }

    /// Reads the current theme from UserDefaults without needing SwiftUI observation.
    /// Safe to call from any non-UI context (ViewModels, services, background tasks).
    static var currentAccentRGB: (r: Double, g: Double, b: Double) {
        let raw = UserDefaults.standard.string(forKey: "RYFT.accentTheme") ?? ""
        return (AccentTheme(rawValue: raw) ?? .midnight).accentRGB
    }
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
