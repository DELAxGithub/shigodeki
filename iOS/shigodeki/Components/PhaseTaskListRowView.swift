//
//  PhaseTaskListRowView.swift
//  shigodeki
//
//  Created by Claude on 2025-09-05.
//

import SwiftUI

struct PhaseTaskListRowView: View {
    let taskList: TaskList
    @State private var taskCount: Int? = nil
    
    var body: some View {
        HStack {
            Circle()
                .fill(taskList.color.swiftUIColor)
                .frame(width: 16, height: 16)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(taskList.name)
                    .font(.headline)
                
                Text("\(taskCount ?? 0)個のタスク")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .task(id: taskList.id) {
            await loadTaskCount()
        }
    }
    
    private func loadTaskCount() async {
        guard let listId = taskList.id else { return }
        let manager = EnhancedTaskManager()
        do {
            let tasks = try await manager.getTasks(listId: listId, phaseId: taskList.phaseId, projectId: taskList.projectId)
            await MainActor.run { taskCount = tasks.count }
        } catch {
            // keep nil
        }
    }
}