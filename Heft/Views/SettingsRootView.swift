// iOS 26+ only. No #available guards.

import SwiftUI

struct SettingsRootView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.heftTheme) private var theme

    var body: some View {
        List {
            // ── Appearance ─────────────────────────────────────────────
            Section {
                ForEach(AccentTheme.allCases) { t in
                    ThemeRow(
                        theme: t,
                        isSelected: appState.accentTheme == t,
                        accentColor: theme.accentColor
                    ) {
                        appState.accentTheme = t
                    }
                }
            } header: {
                Text("Theme")
            }

            // ── About ──────────────────────────────────────────────────
            Section {
                LabeledContent("Version", value: "1.0")
            } header: {
                Text("About")
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("Settings")
        .themedBackground()
    }
}

// MARK: - Theme Row

private struct ThemeRow: View {
    let theme: AccentTheme
    let isSelected: Bool
    let accentColor: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.md) {
                ZStack {
                    Circle()
                        .fill(theme.backgroundColor)
                    Circle()
                        .fill(theme.accentColor)
                        .padding(7)
                }
                .frame(width: 32, height: 32)
                .overlay(Circle().strokeBorder(.white.opacity(0.12), lineWidth: 1))

                VStack(alignment: .leading, spacing: 2) {
                    Text(theme.displayName)
                        .font(Typography.body)
                        .foregroundStyle(Color.textPrimary)
                    if theme.isPro {
                        Text("Pro")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.heftAmber)
                            .textCase(.uppercase)
                            .tracking(0.5)
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .fontWeight(.semibold)
                        .foregroundStyle(accentColor)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        SettingsRootView()
    }
    .environment(AppState())
}
