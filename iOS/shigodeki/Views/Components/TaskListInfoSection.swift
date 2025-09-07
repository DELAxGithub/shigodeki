//
//  TaskListInfoSection.swift
//  shigodeki
//
//  Extracted from TaskDetailView.swift for CLAUDE.md compliance
//  Task list information display component
//

import SwiftUI

struct TaskListInfoSection: View {
    let taskList: TaskList
    let tasks: [ShigodekiTask]
    let completedTasks: [ShigodekiTask]
    
    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Circle()
                        .fill(taskList.color.swiftUIColor)
                        .frame(width: 20, height: 20)
                    
                    Text(taskList.name)
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Spacer()
                }
                
                HStack {
                    Text("\(tasks.count)個のタスク")
                    Text("•")
                    Text("\(completedTasks.count)個完了")
                    Spacer()
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
        }
    }
}