//
//  AccessibilityComponents.swift
//  shigodeki
//
//  Created from AccessibilitySystem split for CLAUDE.md compliance
//  Accessibility-optimized UI components
//

import SwiftUI

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
            // 🚨 CTO修正: タップフィードバックの遅延を撤廃
            // SwiftUIの自動アニメーション機能を活用し、即座にフィードバックを提供
            withAnimation(.quickEase) {
                isPressed = true
            }
            HapticFeedbackManager.shared.light()
            
            // 即座にリセット用アニメーションをスケジュール（遅延なし）
            withAnimation(.quickEase.delay(0.1)) {
                isPressed = false
            }
            print("⚡ AccessibilitySystem: Immediate tap feedback without DispatchQueue delay")
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

// MARK: - Interactive Extensions

extension View {
    func interactiveScale(isPressed: Binding<Bool>) -> some View {
        self
            .scaleEffect(isPressed.wrappedValue ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed.wrappedValue)
    }
}