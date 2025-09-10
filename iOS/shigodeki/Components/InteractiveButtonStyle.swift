import SwiftUI

/// A button style that applies a standard scale and opacity effect on press for consistent UX.
struct InteractiveButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    func makeBody(configuration: Configuration) -> some View {
        let scale: CGFloat = (configuration.isPressed && isEnabled) ? 0.98 : 1.0
        let opacity: Double = (configuration.isPressed && isEnabled) ? 0.9 : 1.0
        let anim: Animation = reduceMotion ? .easeInOut(duration: 0) : .quickEase
        
        return configuration.label
            .scaleEffect(scale)
            .opacity(opacity)
            .animation(anim, value: configuration.isPressed)
    }
}

extension View {
    /// Applies a standard interactive effect to any button, ensuring consistent
    /// visual feedback across the app.
    func interactiveEffect() -> some View {
        self.buttonStyle(InteractiveButtonStyle())
    }
}
