// iOS 26+ only. No #available guards.

import SwiftUI

/// Enhanced glass surface for cards when the mesh theme is active.
///
/// All cards get the static diagonal specular highlight.
/// Shimmer is opt-in: pass `exerciseIndex` to enable it. When provided, the card
/// only shimmers if its index matches `engine.lastLoggedExerciseIndex` — so only
/// the card whose set was just logged gets the sweep, not every card on screen.
struct ProGlassModifier: ViewModifier {
    @Environment(\.heftTheme) private var theme
    @Environment(MeshEngine.self) private var engine
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// When non-nil, this card is eligible for shimmer. Only fires when the engine's
    /// lastLoggedExerciseIndex matches — i.e. this exercise's set was just logged.
    var exerciseIndex: Int?

    /// Corner radius of the card — used to clip overlays so they respect rounded corners.
    var cornerRadius: CGFloat = Radius.medium

    /// Shimmer band position. -1 = off-screen left, 2 = off-screen right.
    @State private var shimmerPhase: CGFloat = -1.0
    @State private var isShimmering = false

    func body(content: Content) -> some View {
        if theme == .mesh {
            content
                .overlay {
                    // Static diagonal specular highlight — applies to all cards
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.04),
                            Color.clear,
                            Color.white.opacity(0.02),
                            Color.clear,
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    .allowsHitTesting(false)
                }
                .overlay {
                    if isShimmering {
                        shimmerOverlay
                            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                            .allowsHitTesting(false)
                    }
                }
                .onChange(of: engine.state) { _, newState in
                    guard newState == .setLogged,
                          let myIndex = exerciseIndex,
                          myIndex == engine.lastLoggedExerciseIndex,
                          !reduceMotion
                    else { return }

                    shimmerPhase = -1.0
                    isShimmering = true
                    withAnimation(.easeInOut(duration: Motion.shimmerDuration)) {
                        shimmerPhase = 2.0
                    }
                    Task {
                        try? await Task.sleep(for: .milliseconds(Int(Motion.shimmerDuration * 1000) + 50))
                        isShimmering = false
                    }
                }
        } else {
            content
        }
    }

    private var shimmerOverlay: some View {
        GeometryReader { geo in
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: Color.white.opacity(0.08), location: 0.45),
                    .init(color: Color.white.opacity(0.12), location: 0.5),
                    .init(color: Color.white.opacity(0.08), location: 0.55),
                    .init(color: .clear, location: 1.0),
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .offset(x: shimmerPhase * geo.size.width)
        }
        .clipped()
    }
}

extension View {
    /// Applies the Pro mesh glass treatment. Pass `exerciseIndex` on active workout cards
    /// so only the card whose set was logged receives the shimmer sweep.
    /// `cornerRadius` must match the card's background shape to avoid hard overlay corners.
    func proGlass(exerciseIndex: Int? = nil, cornerRadius: CGFloat = Radius.medium) -> some View {
        modifier(ProGlassModifier(exerciseIndex: exerciseIndex, cornerRadius: cornerRadius))
    }
}
