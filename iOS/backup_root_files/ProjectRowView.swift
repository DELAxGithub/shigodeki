//
//  ProjectRowView.swift
//  shigodeki
//
//  Created by Claude on 2025-08-28.
//

import SwiftUI

struct ProjectRowView: View {
    let project: Project
    @State private var isPressed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
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
                    .multilineTextAlignment(.leading)
                    .scaledFont(.subheadline, maxSize: 22)
            }
            
            // Metadata row
            HStack {
                MemberCountBadge(count: project.memberIds.count)
                
                Spacer()
                
                // Creation date
                Text(formatDate(project.createdAt))
                    .font(.caption)
                    .foregroundColor(.tertiaryText)
                    .scaledFont(.caption, maxSize: 18)
            }
        }
        .listCard(isSelected: isPressed)
        .contentShape(Rectangle())
        .accessibleCard(
            label: accessibilityLabel,
            hint: "プロジェクトの詳細を表示するにはダブルタップ"
        )
        .highContrastColors()
        .interactiveScale(isPressed: $isPressed)
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
        formatter.dateStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
}

#Preview {
    let sampleProject = Project(name: "Sample Project", description: "A sample project for preview", ownerId: "user1")
    ProjectRowView(project: sampleProject)
        .padding()
}