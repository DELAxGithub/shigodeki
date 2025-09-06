//
//  CreateProjectComponents.swift
//  shigodeki
//
//  Created by Claude on 2025-09-05.
//

import SwiftUI

struct CreationMethodCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.primaryBlue.opacity(0.2) : Color.secondary.opacity(0.1))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: icon)
                        .foregroundColor(isSelected ? .primaryBlue : .secondary)
                        .font(.title3)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.primaryBlue)
                        .font(.title3)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.primaryBlue.opacity(0.05) : Color(.systemGray6))
                    .stroke(isSelected ? Color.primaryBlue : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SelectedTemplateCard: View {
    let template: ProjectTemplate
    let onRemove: () -> Void
    
    private var stats: TemplateStats {
        TemplateStats(template: template)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack {
                    Circle()
                        .fill(template.category.color.opacity(0.2))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: template.category.icon)
                        .foregroundColor(template.category.color)
                        .font(.subheadline)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(template.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(template.category.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button {
                    onRemove()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
            
            HStack(spacing: 16) {
                StatItem(
                    icon: "list.bullet",
                    value: "\(stats.totalPhases)",
                    label: "フェーズ",
                    color: .blue
                )
                
                StatItem(
                    icon: "checkmark.square",
                    value: "\(stats.totalTasks)",
                    label: "タスク",
                    color: .green
                )
                
                StatItem(
                    icon: "clock",
                    value: stats.completionTimeRange,
                    label: "期間",
                    color: .orange
                )
                
                Spacer()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGroupedBackground))
        )
    }
}