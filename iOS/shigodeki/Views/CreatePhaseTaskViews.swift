//
//  CreatePhaseTaskViews.swift
//  shigodeki
//
//  Created by Claude on 2025-09-05.
//

import SwiftUI

struct CreatePhaseTaskListView: View {
    let phase: Phase
    let project: Project
    @ObservedObject var taskListManager: TaskListManager
    @Environment(\.presentationMode) var presentationMode
    @State private var taskListName = ""
    @State private var selectedColor: TaskListColor = .blue
    
    var body: some View {
        NavigationView {
            Form {
                TextField("タスクリスト名", text: $taskListName)
                
                Section("色") {
                    ColorSelectionGrid(selectedColor: $selectedColor)
                }
            }
            .navigationTitle("新しいタスクリスト")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("作成") {
                        createTaskList()
                    }
                    .disabled(taskListName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    private func createTaskList() {
        guard let phaseId = phase.id, let projectId = project.id else { return }
        let name = taskListName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        
        if let userId = AuthenticationManager.shared.currentUserId {
            Task {
                do {
                    _ = try await taskListManager.createTaskList(
                        name: name,
                        phaseId: phaseId,
                        projectId: projectId,
                        createdBy: userId,
                        color: selectedColor,
                        order: nil
                    )
                    await MainActor.run {
                        presentationMode.wrappedValue.dismiss()
                    }
                } catch {
                    print("Error creating task list: \(error)")
                }
            }
        }
    }
}

struct ColorSelectionGrid: View {
    @Binding var selectedColor: TaskListColor
    
    var body: some View {
        let columns = Array(repeating: GridItem(.flexible()), count: 4)
        LazyVGrid(columns: columns) {
            ForEach(TaskListColor.allCases, id: \.self) { color in
                Circle()
                    .fill(color.swiftUIColor)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Circle()
                            .stroke(selectedColor == color ? Color.primary : Color.clear, lineWidth: 3)
                    )
                    .onTapGesture {
                        selectedColor = color
                    }
            }
        }
    }
}

struct CreatePhaseTaskView: View {
    let taskList: TaskList
    let phase: Phase
    let project: Project
    @ObservedObject var taskManager: TaskManager
    @ObservedObject private var authManager = AuthenticationManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var taskTitle: String = ""
    @State private var taskDescription: String = ""
    @State private var selectedPriority: TaskPriority = .medium
    @State private var isCreating = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("タスク詳細")) {
                    TextField("タスクタイトル", text: $taskTitle)
                    TextField("説明（オプション）", text: $taskDescription, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section(header: Text("優先度")) {
                    Picker("優先度", selection: $selectedPriority) {
                        ForEach(TaskPriority.allCases, id: \.self) { priority in
                            HStack {
                                Circle()
                                    .fill(priority.swiftUIColor)
                                    .frame(width: 12, height: 12)
                                Text(priority.displayName)
                            }
                            .tag(priority)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
            }
            .navigationTitle("新しいタスク")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("作成") {
                        createTask()
                    }
                    .disabled(taskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCreating)
                }
            }
        }
    }
    
    private func createTask() {
        guard let userId = authManager.currentUser?.id,
              let taskListId = taskList.id,
              let phaseId = phase.id,
              let projectId = project.id else { return }
        
        isCreating = true
        
        Task {
            do {
                _ = try await taskManager.createPhaseTask(
                    title: taskTitle,
                    description: taskDescription.isEmpty ? nil : taskDescription,
                    taskListId: taskListId,
                    projectId: projectId,
                    phaseId: phaseId,
                    creatorUserId: userId,
                    priority: selectedPriority
                )
                
                await MainActor.run {
                    dismiss()
                }
            } catch {
                print("Error creating task: \(error)")
                isCreating = false
            }
        }
    }
}