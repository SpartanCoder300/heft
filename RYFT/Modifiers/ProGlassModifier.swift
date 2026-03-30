// iOS 26+ only. No #available guards.

import SwiftUI

/// Enhanced glass surface for cards when the mesh theme is active.
///
/// All cards get the static diagonal specular highlight.
/// Shimmer is opt-in: pass `exerciseIndex` to enable it. When provided, the card
/// only shimmers if its index matches `engine.lastLoggedExerciseIndex` — so only
/// the card whose set was just logged gets the sweep, not every card on screen.
struct ProGlassModifier: ViewModifier {
    @Environment(\.ryftTheme) private var theme
    @Environment(MeshEngine.self) private var engine
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// When non-nil, this card is eligible for shimmer. Only fires when the engine's
    /// lastLoggedExerciseIndex matches — i.e. this exercise's set was just logged.
    var exerciseIndex: Int?

    /// When non-nil, shifts the specular gradient angle slightly so stacked cards
    /// don't all reflect from the exact same angle. Uses modulo-5 cycling.
    var cardIndex: Int?

    /// When false, skips the specular highlight — card gets border only.
    /// Use for content/browsing surfaces; reserve full glass for key interactive cards.
    var specular: Bool = true

    /// Corner radius of the card — used to clip overlays so they respect rounded corners.
    var cornerRadius: CGFloat = Radius.medium


    // Golden ratio distribution — each card gets a non-sequential angle so no
    // visible stepping pattern emerges when cards are stacked.
    // φ ≈ 0.618 guarantees adjacent indices are maximally far apart in the range.
    private var specularT: CGFloat {
        (CGFloat(cardIndex ?? 0) * 0.618).truncatingRemainder(dividingBy: 1.0)
    }

    private var specularStart: UnitPoint {
        UnitPoint(x: specularT * 0.28, y: specularT * 0.14)
    }

    private var specularEnd: UnitPoint {
        UnitPoint(x: 1.0 - specularT * 0.10, y: 1.0 - specularT * 0.22)
    }

    /// Shimmer band position. -1 = off-screen left, 2 = off-screen right.
    @State private var shimmerPhase: CGFloat = -1.0
    @State private var isShimmering = false
    /// Peak opacity of the shimmer band. Higher for exercise-complete sweeps.
    @State private var shimmerPeak: CGFloat = 0.12

    func body(content: Content) -> some View {
        let withBorder = content
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.white.opacity(theme == .mesh ? 0.10 : 0.08), lineWidth: 1)
            }

        if theme == .mesh {
            withBorder
                .overlay {
                    if specular {
                        glassLightOverlay
                            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                            .allowsHitTesting(false)
                    }
                }
                .overlay {
                    if isShimmering {
                        shimmerOverlay
                            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                            .allowsHitTesting(false)
                    }
                }
                .onChange(of: engine.state) { _, newState in
                    guard (newState == .setLogged || newState == .exerciseComplete),
                          let myIndex = exerciseIndex,
                          myIndex == engine.lastLoggedExerciseIndex,
                          !reduceMotion
                    else { return }

                    // Exercise complete gets a brighter, wider band.
                    shimmerPeak = newState == .exerciseComplete ? 0.20 : 0.12
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
            withBorder
        }
    }

    private var shimmerOverlay: some View {
        // Band width scales with peak: normal (peak 0.12) → tight 10% band,
        // exercise-complete (peak 0.20) → wider 24% band for more presence.
        let edge = shimmerPeak * 0.67
        let spread: CGFloat = shimmerPeak > 0.15 ? 0.12 : 0.05
        return GeometryReader { geo in
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: Color.white.opacity(edge), location: 0.5 - spread),
                    .init(color: Color.white.opacity(shimmerPeak), location: 0.5),
                    .init(color: Color.white.opacity(edge), location: 0.5 + spread),
                    .init(color: .clear, location: 1.0),
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .offset(x: shimmerPhase * geo.size.width)
        }
        .clipped()
    }

    private var glassLightOverlay: some View {
        ZStack {
            // Broad warm bloom — reads like ambient light diffusing through the glass.
            RadialGradient(
                stops: [
                    .init(color: Color.white.opacity(0.07), location: 0),
                    .init(color: theme.accentColor.opacity(0.04), location: 0.24),
                    .init(color: .clear, location: 0.76)
                ],
                center: UnitPoint(x: 0.18 + specularT * 0.10, y: 0.06 + specularT * 0.04),
                startRadius: 4,
                endRadius: 220
            )

            // Narrower specular streak — gives the surface a more glass-like catch light.
            LinearGradient(
                stops: [
                    .init(color: Color.white.opacity(0.09), location: 0),
                    .init(color: Color.white.opacity(0.035), location: 0.16),
                    .init(color: .clear, location: 0.44)
                ],
                startPoint: specularStart,
                endPoint: specularEnd
            )

            // Subtle counter-sheen so the glass has depth instead of a single flat wash.
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.42),
                    .init(color: Color.white.opacity(0.025), location: 0.76),
                    .init(color: Color.white.opacity(0.045), location: 1)
                ],
                startPoint: UnitPoint(x: 0.92, y: 0.18),
                endPoint: UnitPoint(x: 0.30, y: 1.0)
            )
        }
    }
}

extension View {
    /// Applies the Pro mesh glass treatment. Pass `exerciseIndex` on active workout cards
    /// so only the card whose set was logged receives the shimmer sweep.
    /// `cornerRadius` must match the card's background shape to avoid hard overlay corners.
    func proGlass(exerciseIndex: Int? = nil, cardIndex: Int? = nil, specular: Bool = true, cornerRadius: CGFloat = Radius.medium) -> some View {
        modifier(ProGlassModifier(exerciseIndex: exerciseIndex, cardIndex: cardIndex, specular: specular, cornerRadius: cornerRadius))
    }
}
