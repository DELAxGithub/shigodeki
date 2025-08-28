//
//  EmptyStateView.swift
//  shigodeki
//
//  Created by Claude on 2025-08-28.
//

import SwiftUI

// MARK: - Empty State View

struct EmptyStateView: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let actionTitle: String?
    let action: (() -> Void)?
    
    init(
        title: String,
        subtitle: String,
        systemImage: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.actionTitle = actionTitle
        self.action = action
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.primaryBlue.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: systemImage)
                    .font(.system(size: 40))
                    .foregroundColor(.primaryBlue)
            }
            .pulse(duration: 2.0, minOpacity: 0.7)
            
            // Text content
            VStack(spacing: 8) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
                    .multilineTextAlignment(.center)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
            }
            
            // Action button
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
            }
        }
        .padding(.horizontal, 40)
        .animatedAppear()
    }
}

// MARK: - Specialized Empty States

struct ProjectEmptyStateView: View {
    let action: () -> Void
    
    var body: some View {
        EmptyStateView(
            title: "プロジェクトがありません",
            subtitle: "新しいプロジェクトを作成して\nタスク管理を始めましょう",
            systemImage: "folder.badge.plus",
            actionTitle: "プロジェクトを作成",
            action: action
        )
    }
}

struct PhaseEmptyStateView: View {
    let action: () -> Void
    
    var body: some View {
        EmptyStateView(
            title: "フェーズがありません",
            subtitle: "プロジェクトを段階的に進めるために\nフェーズを作成しましょう",
            systemImage: "list.number",
            actionTitle: "フェーズを作成",
            action: action
        )
    }
}

struct TaskListEmptyStateView: View {
    let action: () -> Void
    
    var body: some View {
        EmptyStateView(
            title: "タスクリストがありません",
            subtitle: "このフェーズのタスクを整理するために\nタスクリストを作成しましょう",
            systemImage: "list.bullet.rectangle",
            actionTitle: "タスクリストを作成",
            action: action
        )
    }
}

struct TaskEmptyStateView: View {
    let action: () -> Void
    
    var body: some View {
        EmptyStateView(
            title: "タスクがありません",
            subtitle: "やるべきことを追加して\n進捗を管理しましょう",
            systemImage: "checkmark.circle",
            actionTitle: "タスクを追加",
            action: action
        )
    }
}

// MARK: - Loading State View

struct LoadingStateView: View {
    let message: String
    
    init(message: String = "読み込み中...") {
        self.message = message
    }
    
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .primaryBlue))
                .scaleEffect(1.2)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondaryText)
        }
        .pulse()
    }
}

// MARK: - Error State View

struct ErrorStateView: View {
    let title: String
    let message: String
    let actionTitle: String
    let action: () -> Void
    
    init(
        title: String = "エラーが発生しました",
        message: String,
        actionTitle: String = "再試行",
        action: @escaping () -> Void
    ) {
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Error icon
            ZStack {
                Circle()
                    .fill(Color.error.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.error)
            }
            
            // Text content
            VStack(spacing: 8) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
                
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
            }
            
            // Retry button
            Button(action: {
                HapticFeedbackManager.shared.medium()
                withAnimation(.standardSpring) {
                    action()
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                    Text(actionTitle)
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primaryBlue)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.primaryBlue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.horizontal, 32)
    }
}

// MARK: - Success State View

struct SuccessStateView: View {
    let title: String
    let message: String
    @State private var showCheckmark = false
    
    init(title: String, message: String) {
        self.title = title
        self.message = message
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Success icon with animation
            ZStack {
                Circle()
                    .fill(Color.completed.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                if showCheckmark {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.completed)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .onAppear {
                withAnimation(.bouncySpring.delay(0.2)) {
                    showCheckmark = true
                }
            }
            
            // Text content
            VStack(spacing: 8) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
                
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 32)
        .onAppear {
            HapticFeedbackManager.shared.success()
        }
    }
}

#Preview("Project Empty State") {
    ProjectEmptyStateView(action: {})
        .padding()
}

#Preview("Loading State") {
    LoadingStateView()
        .padding()
}

#Preview("Error State") {
    ErrorStateView(message: "ネットワーク接続を確認してください", action: {})
        .padding()
}