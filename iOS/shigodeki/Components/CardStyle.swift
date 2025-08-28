//
//  CardStyle.swift
//  shigodeki
//
//  Created by Claude on 2025-08-28.
//

import SwiftUI

// MARK: - Card Design System

struct CardStyle: ViewModifier {
    let elevation: CardElevation
    let cornerRadius: CGFloat
    let padding: EdgeInsets
    
    init(
        elevation: CardElevation = .medium,
        cornerRadius: CGFloat = 12,
        padding: EdgeInsets = EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
    ) {
        self.elevation = elevation
        self.cornerRadius = cornerRadius
        self.padding = padding
    }
    
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color(.systemBackground))
                    .shadow(
                        color: .black.opacity(elevation.shadowOpacity),
                        radius: elevation.shadowRadius,
                        x: 0,
                        y: elevation.shadowOffset
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color(.separator).opacity(0.3), lineWidth: 0.5)
            )
    }
}

enum CardElevation {
    case low
    case medium
    case high
    
    var shadowRadius: CGFloat {
        switch self {
        case .low: return 2
        case .medium: return 4
        case .high: return 8
        }
    }
    
    var shadowOffset: CGFloat {
        switch self {
        case .low: return 1
        case .medium: return 2
        case .high: return 4
        }
    }
    
    var shadowOpacity: Double {
        switch self {
        case .low: return 0.1
        case .medium: return 0.15
        case .high: return 0.2
        }
    }
}

// MARK: - Card Container Views

struct PrimaryCard<Content: View>: View {
    let content: Content
    let elevation: CardElevation
    
    init(elevation: CardElevation = .medium, @ViewBuilder content: () -> Content) {
        self.elevation = elevation
        self.content = content()
    }
    
    var body: some View {
        content
            .modifier(CardStyle(elevation: elevation))
    }
}

struct ListCard<Content: View>: View {
    let content: Content
    let isSelected: Bool
    
    init(isSelected: Bool = false, @ViewBuilder content: () -> Content) {
        self.isSelected = isSelected
        self.content = content()
    }
    
    var body: some View {
        content
            .modifier(
                CardStyle(
                    elevation: isSelected ? .high : .low,
                    cornerRadius: 8,
                    padding: EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
                )
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

struct ActionCard<Content: View>: View {
    let content: Content
    let action: () -> Void
    
    init(action: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.action = action
        self.content = content()
    }
    
    var body: some View {
        Button(action: action) {
            content
                .modifier(CardStyle(elevation: .medium))
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Button Styles

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - View Extensions

extension View {
    func cardStyle(
        elevation: CardElevation = .medium,
        cornerRadius: CGFloat = 12
    ) -> some View {
        self.modifier(CardStyle(elevation: elevation, cornerRadius: cornerRadius))
    }
    
    func primaryCard(elevation: CardElevation = .medium) -> some View {
        PrimaryCard(elevation: elevation) {
            self
        }
    }
    
    func listCard(isSelected: Bool = false) -> some View {
        ListCard(isSelected: isSelected) {
            self
        }
    }
}