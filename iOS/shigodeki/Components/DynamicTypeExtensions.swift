//
//  DynamicTypeExtensions.swift
//  shigodeki
//
//  Created from AccessibilitySystem split for CLAUDE.md compliance
//  Dynamic Type, motion, and visual accessibility extensions
//

import SwiftUI

// MARK: - Dynamic Type and Visual Accessibility Extensions

extension View {
    // MARK: - Dynamic Type Support
    
    func dynamicTypeSize(_ size: DynamicTypeSize) -> some View {
        self.dynamicTypeSize(...size)
    }
    
    func scaledFont(_ font: Font, maxSize: CGFloat? = nil) -> some View {
        self.font(font)
            .modifier(ScalableFontModifier(maxSize: maxSize))
    }
    
    // MARK: - Reduce Motion Support
    
    func reducedMotionAnimation<V: Equatable>(
        _ animation: Animation,
        value: V,
        reducedAnimation: Animation? = nil
    ) -> some View {
        self.animation(
            UIAccessibility.isReduceMotionEnabled ? reducedAnimation : animation,
            value: value
        )
    }
    
    func reducedMotionTransition(
        _ transition: AnyTransition,
        reducedTransition: AnyTransition = .identity
    ) -> some View {
        self.transition(
            UIAccessibility.isReduceMotionEnabled ? reducedTransition : transition
        )
    }
    
    // MARK: - High Contrast Support
    
    func highContrastColors() -> some View {
        self.modifier(HighContrastModifier())
    }
}

// MARK: - Font Scaling Modifier

struct ScalableFontModifier: ViewModifier {
    let maxSize: CGFloat?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    func body(content: Content) -> some View {
        if let maxSize = maxSize {
            content
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        } else {
            content
        }
    }
}

// MARK: - High Contrast Modifier

struct HighContrastModifier: ViewModifier {
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    
    func body(content: Content) -> some View {
        content
            .background(
                // Add extra background contrast if needed
                differentiateWithoutColor ? 
                    (colorScheme == .dark ? Color.black : Color.white) : 
                    Color.clear
            )
            .opacity(reduceTransparency ? 1.0 : 0.95)
    }
}