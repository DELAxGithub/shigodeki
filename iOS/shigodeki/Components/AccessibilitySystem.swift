//
//  AccessibilitySystem.swift
//  shigodeki
//
//  Created by Claude on 2025-08-28.
//

import SwiftUI

// MARK: - Accessibility Extensions

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
    
    // MARK: - Focus Management
    
    func accessibilityFocused<T: Hashable>(
        _ binding: FocusState<T?>.Binding,
        equals value: T
    ) -> some View {
        self.focused(binding, equals: value)
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

// MARK: - Accessibility-Optimized Components

struct AccessibleProjectRow: View {
    let project: Project
    @State private var isPressed = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with title and status
            HStack {
                Text(project.name)
                    .font(.headline)
                    .foregroundColor(.primaryText)
                    .fontWeight(.semibold)
                    .scaledFont(.headline, maxSize: 28)
                
                Spacer()
                
                StatusBadge(isCompleted: project.isCompleted)
            }
            
            // Description
            if let description = project.description, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
                    .lineLimit(nil) // Allow unlimited lines for accessibility
                    .scaledFont(.subheadline, maxSize: 22)
            }
            
            // Metadata row
            HStack {
                MemberCountBadge(count: project.memberIds.count)
                Spacer()
                Text(formatDate(project.createdAt))
                    .font(.caption)
                    .foregroundColor(.tertiaryText)
                    .scaledFont(.caption, maxSize: 18)
            }
        }
        .listCard(isSelected: isPressed)
        .accessibleCard(
            label: accessibilityLabel,
            hint: "プロジェクトの詳細を表示するにはダブルタップ"
        )
        .interactiveScale(isPressed: $isPressed)
        .onTapGesture {
            withAnimation(.quickEase) {
                isPressed = true
            }
            HapticFeedbackManager.shared.light()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.quickEase) {
                    isPressed = false
                }
            }
        }
    }
    
    private var accessibilityLabel: String {
        var label = "プロジェクト: \(project.name)"
        
        if let description = project.description, !description.isEmpty {
            label += "、説明: \(description)"
        }
        
        label += "、メンバー数: \(project.memberIds.count)人"
        label += "、作成日: \(formatDate(project.createdAt))"
        label += project.isCompleted ? "、完了済み" : "、進行中"
        
        return label
    }
    
    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
}

struct StatusBadge: View {
    let isCompleted: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: isCompleted ? "checkmark.circle.fill" : "clock")
                .font(.caption)
            Text(isCompleted ? "完了" : "進行中")
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundColor(isCompleted ? .completed : .inProgress)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background((isCompleted ? Color.completed : Color.inProgress).opacity(0.1))
        .clipShape(Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isCompleted ? "完了済み" : "進行中")
    }
}

struct MemberCountBadge: View {
    let count: Int
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "person.2.fill")
                .font(.caption)
                .foregroundColor(.primaryBlue)
            Text("\(count)人")
                .font(.caption)
                .foregroundColor(.secondaryText)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.primaryBlue.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(count)人のメンバー")
    }
}

// MARK: - Accessibility-Enhanced Empty States

struct AccessibleEmptyStateView: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let actionTitle: String?
    let action: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 24) {
            // Icon with accessibility support
            ZStack {
                Circle()
                    .fill(Color.primaryBlue.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: systemImage)
                    .font(.system(size: 40))
                    .foregroundColor(.primaryBlue)
            }
            .accessibilityHidden(true) // Decorative image
            
            // Text content
            VStack(spacing: 8) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
                    .multilineTextAlignment(.center)
                    .scaledFont(.title2, maxSize: 32)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .scaledFont(.subheadline, maxSize: 22)
            }
            .accessibilityElement(children: .combine)
            
            // Action button with enhanced accessibility
            if let actionTitle = actionTitle, let action = action {
                Button(action: {
                    HapticFeedbackManager.shared.medium()
                    withAnimation(.bouncySpring) {
                        action()
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                        Text(actionTitle)
                    }
                    .font(.headline)
                    .scaledFont(.headline, maxSize: 24)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [.primaryBlue, .primaryDark],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(
                        color: .primaryBlue.opacity(0.3),
                        radius: 8,
                        x: 0,
                        y: 4
                    )
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibleButton(
                    label: actionTitle,
                    hint: "新しい項目を作成します"
                )
            }
        }
        .padding(.horizontal, 40)
        .animatedAppear()
    }
}

// MARK: - Focus Management

@MainActor
class AccessibilityFocusManager: ObservableObject {
    static let shared = AccessibilityFocusManager()
    
    private init() {}
    
    func announcementDelayed(_ message: String, delay: TimeInterval = 0.5) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            UIAccessibility.post(notification: .announcement, argument: message)
        }
    }
    
    func screenChanged(to element: Any? = nil) {
        UIAccessibility.post(notification: .screenChanged, argument: element)
    }
    
    func layoutChanged(to element: Any? = nil) {
        UIAccessibility.post(notification: .layoutChanged, argument: element)
    }
}

// MARK: - Accessibility Testing Helper

#if DEBUG
struct AccessibilityTestingView: View {
    @State private var showingAccessibilityInfo = false
    
    var body: some View {
        VStack {
            Button("Toggle Accessibility Info") {
                showingAccessibilityInfo.toggle()
            }
            .padding()
            
            if showingAccessibilityInfo {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Accessibility Status:")
                        .font(.headline)
                    
                    Text("VoiceOver: \(UIAccessibility.isVoiceOverRunning ? "ON" : "OFF")")
                    Text("Reduce Motion: \(UIAccessibility.isReduceMotionEnabled ? "ON" : "OFF")")
                    Text("Reduce Transparency: \(UIAccessibility.isReduceTransparencyEnabled ? "ON" : "OFF")")
                    Text("Differentiate Without Color: \(UIAccessibility.shouldDifferentiateWithoutColor ? "ON" : "OFF")")
                    Text("Darker Colors: \(UIAccessibility.isDarkerSystemColorsEnabled ? "ON" : "OFF")")
                }
                .font(.caption)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
    }
}
#endif