//
//  TaskQuickActions.swift
//  shigodeki
//
//  Created by Claude on 2025-09-01.
//  [Sprint 2] Wave 4: Real-time sync and performance optimization (PERF-802)
//

import SwiftUI
import Combine

/// Quick action component for task management with performance optimizations
struct TaskQuickActions: View {
    let task: ShigodekiTask
    let onToggleComplete: (ShigodekiTask) -> Void
    let onQuickEdit: (ShigodekiTask) -> Void
    let onAssignToMe: (ShigodekiTask) -> Void
    
    @State private var isAnimating = false
    @State private var showingQuickAssign = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Toggle completion with smooth animation
            Button {
                // 🚨 CTO修正: アニメーション遅延を撤廃し、即座に状態変更
                // SwiftUIの自動アニメーション機能を活用し、人工的遅延を排除
                withAnimation(.easeInOut(duration: 0.2)) {
                    isAnimating = true
                    onToggleComplete(task)
                }
                
                // アニメーション完了を待たずに即座に状態をリセット
                withAnimation(.easeInOut(duration: 0.2).delay(0.2)) {
                    isAnimating = false
                }
                print("⚡ TaskQuickActions: Immediate animation state management")
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(task.isCompleted ? .completed : .secondaryText)
                    .scaleEffect(isAnimating ? 1.2 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isAnimating)
            }
            .buttonStyle(PlainButtonStyle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.headline)
                    .strikethrough(task.isCompleted)
                    .foregroundColor(task.isCompleted ? .secondaryText : .primaryText)
                
                if let description = task.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                        .lineLimit(2)
                }
                
                // Quick info badges
                HStack(spacing: 8) {
                    // Priority indicator
                    if task.priority != .medium {
                        HStack(spacing: 2) {
                            Circle()
                                .fill(task.priority.swiftUIColor)
                                .frame(width: 6, height: 6)
                            Text(task.priority.displayName)
                                .font(.caption2)
                                .foregroundColor(.tertiaryText)
                        }
                    }
                    
                    // Due date indicator
                    if let dueDate = task.dueDate {
                        HStack(spacing: 2) {
                            Image(systemName: "clock")
                                .font(.caption2)
                            Text(RelativeDateTimeFormatter().localizedString(for: dueDate, relativeTo: Date()))
                                .font(.caption2)
                        }
                        .foregroundColor(task.isOverdue ? .error : .tertiaryText)
                    }
                    
                    // Subtask progress
                    if task.hasSubtasks {
                        HStack(spacing: 2) {
                            Image(systemName: "list.bullet")
                                .font(.caption2)
                            Text("\(task.completedSubtaskCount)/\(task.subtaskCount)")
                                .font(.caption2)
                        }
                        .foregroundColor(.tertiaryText)
                    }
                }
            }
            
            Spacer()
            
            // Quick action menu
            Menu {
                Button {
                    onQuickEdit(task)
                } label: {
                    Label("編集", systemImage: "pencil")
                }
                
                if task.assignedTo != AuthenticationManager.shared.currentUserId {
                    Button {
                        onAssignToMe(task)
                    } label: {
                        Label("自分に割り当て", systemImage: "person.crop.circle.badge.plus")
                    }
                }
                
                Button {
                    HapticFeedbackManager.shared.medium()
                } label: {
                    Label("優先度を変更", systemImage: "exclamationmark.triangle")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.headline)
                    .foregroundColor(.secondaryText)
                    .padding(8)
            }
            .menuStyle(BorderlessButtonMenuStyle())
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

/// Optimized task row for list performance
struct OptimizedTaskRow: View {
    let task: ShigodekiTask
    let onAction: (TaskAction, ShigodekiTask) -> Void
    
    enum TaskAction {
        case toggleComplete
        case edit
        case assignToMe
        case changePriority
    }
    
    var body: some View {
        TaskQuickActions(
            task: task,
            onToggleComplete: { onAction(.toggleComplete, $0) },
            onQuickEdit: { onAction(.edit, $0) },
            onAssignToMe: { onAction(.assignToMe, $0) }
        )
        .id(task.id) // Explicit ID for list optimization
    }
}

/// Performance-optimized task list view
struct TaskListOptimized: View {
    let tasks: [ShigodekiTask]
    let onTaskAction: (OptimizedTaskRow.TaskAction, ShigodekiTask) -> Void
    
    var body: some View {
        LazyVStack(spacing: 8) {
            ForEach(tasks) { task in
                OptimizedTaskRow(
                    task: task,
                    onAction: onTaskAction
                )
                .primaryCard()
            }
        }
        .padding(.horizontal)
    }
}

#Preview {
    VStack {
        TaskQuickActions(
            task: ShigodekiTask(
                title: "サンプルタスク",
                description: "これはサンプルの説明文です",
                createdBy: "user1",
                dueDate: Date().addingTimeInterval(86400),
                priority: .high,
                listId: "list1",
                phaseId: "phase1", 
                projectId: "project1",
                order: 0
            ),
            onToggleComplete: { _ in },
            onQuickEdit: { _ in },
            onAssignToMe: { _ in }
        )
        .padding()
        
        Divider()
        
        TaskListOptimized(
            tasks: [
                ShigodekiTask(title: "完了したタスク", createdBy: "user1", listId: "list1", phaseId: "phase1", projectId: "project1", order: 0),
                ShigodekiTask(title: "進行中のタスク", description: "詳細説明", createdBy: "user1", dueDate: Date().addingTimeInterval(86400), priority: .medium, listId: "list1", phaseId: "phase1", projectId: "project1", order: 1)
            ],
            onTaskAction: { _, _ in }
        )
    }
}