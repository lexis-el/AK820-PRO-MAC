import SwiftUI

// Liquid Glass styling (macOS 26+). On older macOS each modifier falls back to a material, so the app still builds for 13.

extension View {
    /// A glass panel with a thin bright rim, used behind the pane content.
    @ViewBuilder func glassPanel(cornerRadius: CGFloat = 22) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(macOS 26, *) {
            self.glassEffect(.regular, in: shape)
                .overlay(shape.strokeBorder(.white.opacity(0.18), lineWidth: 1))
        } else {
            self.background(.regularMaterial, in: shape)
                .overlay(shape.strokeBorder(.white.opacity(0.12), lineWidth: 1))
        }
    }

    /// A glass capsule, used for the status bar.
    @ViewBuilder func glassCapsule() -> some View {
        if #available(macOS 26, *) {
            self.glassEffect(.regular, in: Capsule())
        } else {
            self.background(.thinMaterial, in: Capsule())
        }
    }

    /// Lets the desktop show through the window, blurred, so the glass has something to refract.
    @ViewBuilder func translucentWindow() -> some View {
        if #available(macOS 15, *) {
            self.containerBackground(.ultraThinMaterial, for: .window)
        } else {
            self
        }
    }
}
