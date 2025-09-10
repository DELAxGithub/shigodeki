//
//  TaskRowComponent.swift
//  shigodeki
//
//  Extracted from TaskDetailView.swift for CLAUDE.md compliance
//  Task row display and interaction component
//

import SwiftUI

struct TaskRowView: View {
    let task: ShigodekiTask
    let taskList: TaskList
    let family: Family
    let taskManager: TaskManager
    let familyMembers: [User]
    
    private var assignedMember: User? {
        guard let assignedTo = task.assignedTo else { return nil }
        return familyMembers.first { $0.id == assignedTo }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Completion button
            Button(action: {
                toggleCompletion()
            }) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(task.isCompleted ? .green : .gray)
                    .scaleEffect(task.isCompleted ? 1.1 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: task.isCompleted)
            }
            .buttonStyle(.plain)
            .interactiveEffect()
            .accessibilityLabel(task.isCompleted ? "完了したタスク" : "未完了のタスク")
            .accessibilityHint(task.isCompleted ? "タップして未完了にします" : "タップして完了にします")
            
            VStack(alignment: .leading, spacing: 4) {
                // Task title
                HStack {
                    Text(task.title)
                        .font(.headline)
                        .strikethrough(task.isCompleted)
                        .foregroundColor(task.isCompleted ? .secondary : .primary)
                        .animation(.easeInOut(duration: 0.2), value: task.isCompleted)
                        .accessibilityLabel("タスク: \(task.title)")
                    
                    Spacer()
                    
                    // Priority indicator
                    Circle()
                        .fill(task.priority.swiftUIColor)
                        .frame(width: 8, height: 8)
                }
                
                // Task description
                if let description = task.description, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                // Task metadata
                HStack {
                    // Assigned member
                    if let assignedMember = assignedMember {
                        HStack(spacing: 4) {
                            Image(systemName: "person")
                                .font(.caption)
                            Text(assignedMember.name)
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    
                    // Due date
                    if let dueDate = task.dueDateFormatted {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.caption)
                            Text(dueDate)
                        }
                        .font(.caption)
                        .foregroundColor(task.isOverdue ? .red : .secondary)
                    }
                    
                    Spacer()
                    
                    // Completion date
                    if task.isCompleted, let completedAt = task.completedAt {
                        Text("完了: \(DateFormatter.taskDateTime.string(from: completedAt))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func toggleCompletion() {
        guard let taskId = task.id,
              let taskListId = taskList.id,
              let familyId = family.id else { return }
        
        // Haptic feedback based on completion state
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        let notificationFeedback = UINotificationFeedbackGenerator()
        
        if task.isCompleted {
            impactFeedback.impactOccurred()
        } else {
            notificationFeedback.notificationOccurred(.success)
        }
        
        Task {
            do {
                try await taskManager.toggleTaskCompletion(
                    taskId: taskId,
                    taskListId: taskListId,
                    familyId: familyId
                )
            } catch {
                print("Error toggling task completion: \(error)")
                // Error feedback
                let errorFeedback = UINotificationFeedbackGenerator()
                errorFeedback.notificationOccurred(.error)
            }
        }
    }
}
