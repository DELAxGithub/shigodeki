//
//  TaskListContentSection.swift
//  shigodeki
//
//  Extracted from TaskDetailView.swift for CLAUDE.md compliance
//  Task list content display component
//

import SwiftUI

struct TaskListContentSection: View {
    let pendingTasks: [ShigodekiTask]
    let completedTasks: [ShigodekiTask]
    let taskList: TaskList
    let family: Family
    let taskManager: TaskManager
    let familyMembers: [User]
    let isLoading: Bool
    let onCreateTask: () -> Void
    
    var body: some View {
        Group {
            // Pending Tasks
            if !pendingTasks.isEmpty {
                Section("未完了 (\(pendingTasks.count))") {
                    ForEach(pendingTasks) { task in
                        TaskRowView(
                            task: task,
                            taskList: taskList,
                            family: family,
                            taskManager: taskManager,
                            familyMembers: familyMembers
                        )
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                    }
                }
            }
            
            // Completed Tasks
            if !completedTasks.isEmpty {
                Section("完了 (\(completedTasks.count))") {
                    ForEach(completedTasks) { task in
                        TaskRowView(
                            task: task,
                            taskList: taskList,
                            family: family,
                            taskManager: taskManager,
                            familyMembers: familyMembers
                        )
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                    }
                }
            }
            
            // Empty state
            if (pendingTasks.isEmpty && completedTasks.isEmpty) && !isLoading {
                Section {
                    TaskEmptyStateView(onCreateTask: onCreateTask)
                }
            }
        }
    }
}

struct TaskEmptyStateView: View {
    let onCreateTask: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checklist")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            
            Text("タスクがありません")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("新しいタスクを作成してみましょう")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button(action: onCreateTask) {
                HStack {
                    Image(systemName: "plus")
                    Text("タスクを作成")
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}