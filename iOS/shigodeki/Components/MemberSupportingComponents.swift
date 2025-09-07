//
//  MemberSupportingComponents.swift
//  shigodeki
//
//  Created from MemberDetailSections split for CLAUDE.md compliance
//  Supporting UI components for member detail sections
//

import SwiftUI

// MARK: - Supporting Components

struct ProjectRowCompact: View {
    let project: Project
    
    var body: some View {
        HStack {
            Circle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: 8, height: 8)
            
            Text(project.name)
                .font(.body)
            
            Spacer()
            
            // TODO: Project.status property doesn't exist yet
            // Text(project.status.displayName)
            //     .font(.caption)
            //     .padding(.horizontal, 8)
            //     .padding(.vertical, 2)
            //     .background(statusColor.opacity(0.2))
            //     .foregroundColor(statusColor)
            //     .cornerRadius(4)
        }
        .padding(.vertical, 4)
    }
    
    private var statusColor: Color {
        // TODO: Project.status property doesn't exist yet
        // switch project.status {
        // case .planning: return .blue
        // case .active: return .green
        // case .completed: return .gray
        // case .cancelled: return .red
        // }
        return .blue // temporary default
    }
}

struct TaskRowCompact: View {
    let task: ShigodekiTask
    
    var body: some View {
        HStack {
            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundColor(task.isCompleted ? .green : .gray)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.body)
                    .strikethrough(task.isCompleted)
                
                if let dueDate = task.dueDate {
                    Text("期限: \(DateFormatter.shortDate.string(from: dueDate))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            PriorityBadge(priority: task.priority)
        }
        .padding(.vertical, 4)
    }
}

struct StatisticCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct PriorityBadge: View {
    let priority: TaskPriority
    
    private var priorityColor: Color {
        switch priority {
        case .low: return .green
        case .medium: return .yellow
        case .high: return .orange
        // .critical case removed - doesn't exist in TaskPriority enum
        }
    }
    
    var body: some View {
        Text(priority.displayName)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(priorityColor.opacity(0.2))
            .foregroundColor(priorityColor)
            .cornerRadius(4)
    }
}