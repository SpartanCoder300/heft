// iOS 26+ only. No #available guards.

import SwiftUI

enum DesignTokens {
    enum TypeSize {
        static let display: CGFloat = 34
        static let title: CGFloat = 28
        static let heading: CGFloat = 22
        static let body: CGFloat = 17
        static let caption: CGFloat = 13
    }

    enum Duration {
        static let standard: Double = 0.3
        static let fast: Double = 0.15
    }

    enum Layout {
        static let placeholderPanelHeight: CGFloat = 240
        static let placeholderContentWidth: CGFloat = 320
    }

    enum Icon {
        static let placeholder: CGFloat = 56
    }

    enum Opacity {
        static let textPrimary: Double = 0.92
        static let textMuted: Double = 0.48
        static let textFaint: Double = 0.28
        static let glassTint: Double = 0.24
    }
}

enum Typography {
    static let display = Font.system(size: DesignTokens.TypeSize.display)
    static let title = Font.system(size: DesignTokens.TypeSize.title)
    static let heading = Font.system(size: DesignTokens.TypeSize.heading)
    static let body = Font.system(size: DesignTokens.TypeSize.body)
    static let caption = Font.system(size: DesignTokens.TypeSize.caption)
}

enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

enum Radius {
    static let small: CGFloat = 8
    static let medium: CGFloat = 16
    static let large: CGFloat = 24
    static let sheet: CGFloat = 32
}

enum Motion {
    static let standard = DesignTokens.Duration.standard
    static let fast = DesignTokens.Duration.fast
    static let standardSpring = Animation.spring(
        response: DesignTokens.Duration.standard,
        dampingFraction: 0.75
    )
}
