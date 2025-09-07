//
//  VoiceOverExtensions.swift
//  shigodeki
//
//  Created from AccessibilitySystem split for CLAUDE.md compliance
//  VoiceOver and basic accessibility View extensions
//

import SwiftUI

// MARK: - VoiceOver Support Extensions

extension View {
    // MARK: - VoiceOver Support
    
    func accessibleButton(
        label: String,
        hint: String? = nil,
        traits: AccessibilityTraits = .isButton
    ) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(traits)
    }
    
    func accessibleText(
        label: String? = nil,
        value: String? = nil,
        hint: String? = nil
    ) -> some View {
        self
            .accessibilityLabel(label ?? "")
            .accessibilityValue(value ?? "")
            .accessibilityHint(hint ?? "")
    }
    
    func accessibleCard(
        label: String,
        value: String? = nil,
        hint: String? = nil
    ) -> some View {
        self
            .accessibilityElement(children: .combine)
            .accessibilityLabel(label)
            .accessibilityValue(value ?? "")
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(.isButton)
    }
    
    // MARK: - Focus Management
    
    func accessibilityFocused<T: Hashable>(
        _ binding: FocusState<T?>.Binding,
        equals value: T
    ) -> some View {
        self.focused(binding, equals: value)
    }
}