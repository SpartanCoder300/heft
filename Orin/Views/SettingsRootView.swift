// iOS 26+ only. No #available guards.

import SwiftUI
import SwiftData

struct SettingsRootView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.OrinTheme) private var theme
    @Environment(\.OrinCardMaterial) private var cardMaterial
    @State private var isShowingResetExercisesConfirm = false
    @State private var tunerTapCount: Int = 0
    @State private var isShowingTuner = false

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
                    .listRowBackground(Rectangle().fill(cardMaterial))
                }
            } header: {
                Text("Theme")
            }

            // ── Exercise Library ───────────────────────────────────────
            Section {
                Button(role: .destructive) {
                    isShowingResetExercisesConfirm = true
                } label: {
                    LabeledContent("Reset Built-In Exercises") {
                        Image(systemName: "arrow.uturn.backward.circle")
                            .foregroundStyle(Color.OrinRed)
                    }
                }
                .listRowBackground(Rectangle().fill(cardMaterial))
            } footer: {
                Text("Restores all built-in exercises to their default names, equipment, type, increment, and starting weight. Custom exercises are not changed.")
            }

            // ── About ──────────────────────────────────────────────────
            Section {
                LabeledContent("Version", value: "1.0")
                    .listRowBackground(Rectangle().fill(cardMaterial))
                    .onTapGesture {
                        tunerTapCount += 1
                        if tunerTapCount >= 7 {
                            tunerTapCount = 0
                            isShowingTuner = true
                        }
                    }
            } header: {
                Text("About")
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("Settings")
        .sheet(isPresented: $isShowingTuner) {
            SwipeTunerSheet()
        }
        .themedBackground()
        .alert("Reset Built-In Exercises?", isPresented: $isShowingResetExercisesConfirm) {
            Button("Reset", role: .destructive) {
                ExerciseSeeder.resetBuiltInExercises(in: modelContext)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This restores all built-in exercises to the app defaults. Custom exercises will stay as they are.")
        }
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

                Text(theme.displayName)
                    .font(Typography.body)
                    .foregroundStyle(Color.textPrimary)

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
