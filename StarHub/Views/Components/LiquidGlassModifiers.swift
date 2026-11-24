import SwiftUI

/// Centralizes macOS 26.0+ Liquid Glass progressive enhancements for control
/// and navigation surfaces, with macOS 14–15 standard material fallbacks.
///
/// Content-layer cards (`cardSurface`, `ModCard`, `MetricTile`) intentionally
/// do NOT use Liquid Glass, per Apple HIG Materials guidance.
extension View {
    /// Floating control/overlay panel (e.g., command palette, sidebar download card).
    @ViewBuilder
    func floatingGlassSurface<S: Shape>(in shape: S, shadowRadius: CGFloat = 12, shadowY: CGFloat = 4) -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(.regular, in: shape)
        } else {
            self
                .background(.regularMaterial, in: shape)
                .overlay(shape.stroke(Color.primary.opacity(AppDesign.Opacity.light), lineWidth: 1))
                .shadow(color: .black.opacity(0.14), radius: shadowRadius, y: shadowY)
        }
    }

    /// Floating interactive glass button surface (e.g., Back-to-Top circular button).
    @ViewBuilder
    func floatingInteractiveGlass<S: Shape>(in shape: S) -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(.regular.interactive(), in: shape)
        } else {
            self
                .background(.regularMaterial, in: shape)
                .overlay(shape.stroke(Color.primary.opacity(AppDesign.Opacity.light), lineWidth: 1))
                .shadow(color: .black.opacity(AppDesign.Opacity.medium), radius: 3, y: 1)
        }
    }

    /// Prominent primary toolbar button (at most one per toolbar).
    @ViewBuilder
    func prominentToolbarAction() -> some View {
        if #available(macOS 26.0, *) {
            self.buttonStyle(.glassProminent)
        } else {
            self.buttonStyle(.borderedProminent)
        }
    }

    /// Soft top scroll edge effect so scrolling content blends smoothly under
    /// the Liquid Glass window toolbar on macOS 26+.
    @ViewBuilder
    func softTopScrollEdgeEffect() -> some View {
        if #available(macOS 26.0, *) {
            self.scrollEdgeEffectStyle(.soft, for: .top)
        } else {
            self
        }
    }
}
