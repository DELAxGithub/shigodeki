//
//  TaskDetailSheets.swift
//  shigodeki
//
//  Extracted from TaskDetailView.swift for CLAUDE.md compliance
//  Task detail sheet management component
//

import SwiftUI

struct TaskDetailSheets: ViewModifier {
    let taskList: TaskList
    let family: Family
    let taskManager: TaskManager
    let authManager: AuthenticationManager
    let aiGenerator: AITaskGenerator
    let familyMembers: [User]
    let tasks: [ShigodekiTask]
    
    @Binding var showingCreateTask: Bool
    @Binding var showingAIAssistant: Bool
    @Binding var showingAISettings: Bool
    
    let onDataLoad: () -> Void
    
    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showingCreateTask) {
                if let userId = authManager.currentUser?.id {
                    CreateTaskView(
                        taskList: taskList,
                        family: family,
                        taskManager: taskManager,
                        creatorUserId: userId,
                        familyMembers: familyMembers
                    )
                }
            }
            .sheet(isPresented: $showingAIAssistant) {
                TaskAIAssistantView(
                    taskList: taskList,
                    existingTasks: tasks,
                    aiGenerator: aiGenerator,
                    onTasksGenerated: { generatedTasks in
                        Task {
                            await TaskDetailSheetHandler.handleAIGeneratedTasks(
                                generatedTasks: generatedTasks,
                                taskList: taskList,
                                family: family,
                                taskManager: taskManager,
                                existingTasksCount: tasks.count,
                                onComplete: onDataLoad
                            )
                        }
                    }
                )
            }
            .sheet(isPresented: $showingAISettings) {
                APISettingsView()
                    .onDisappear {
                        aiGenerator.updateAvailableProviders()
                    }
            }
    }
}

// MARK: - Sheet Handler

struct TaskDetailSheetHandler {
    static func handleAIGeneratedTasks(
        generatedTasks: [ShigodekiTask],
        taskList: TaskList,
        family: Family,
        taskManager: TaskManager,
        existingTasksCount: Int,
        onComplete: @escaping () -> Void
    ) async {
        print("Generated \(generatedTasks.count) tasks")
        
        for generatedTask in generatedTasks {
            do {
                // Create task with proper IDs
                let newTask = ShigodekiTask(
                    title: generatedTask.title,
                    description: generatedTask.description,
                    assignedTo: generatedTask.assignedTo,
                    createdBy: generatedTask.createdBy,
                    dueDate: generatedTask.dueDate,
                    priority: generatedTask.priority,
                    listId: taskList.id ?? "",
                    phaseId: generatedTask.phaseId,
                    projectId: generatedTask.projectId,
                    order: existingTasksCount + (generatedTasks.firstIndex(of: generatedTask) ?? 0)
                )
                
                // Save to database
                guard let taskListId = taskList.id,
                      let familyId = family.id else {
                    print("Error: Missing required IDs")
                    continue
                }
                
                try await taskManager.createTask(
                    title: newTask.title,
                    description: newTask.description,
                    taskListId: taskListId,
                    familyId: familyId,
                    creatorUserId: newTask.createdBy,
                    assignedTo: newTask.assignedTo,
                    dueDate: newTask.dueDate,
                    priority: newTask.priority
                )
                
                print("✅ Successfully created AI task: \(newTask.title)")
                
            } catch {
                print("❌ Error saving AI task: \(error)")
            }
        }
        
        // Refresh the task list to show new tasks
        await MainActor.run {
            onComplete()
        }
    }
}

// MARK: - View Extension

extension View {
    func taskDetailSheets(
        taskList: TaskList,
        family: Family,
        taskManager: TaskManager,
        authManager: AuthenticationManager,
        aiGenerator: AITaskGenerator,
        familyMembers: [User],
        tasks: [ShigodekiTask],
        showingCreateTask: Binding<Bool>,
        showingAIAssistant: Binding<Bool>,
        showingAISettings: Binding<Bool>,
        onDataLoad: @escaping () -> Void
    ) -> some View {
        modifier(TaskDetailSheets(
            taskList: taskList,
            family: family,
            taskManager: taskManager,
            authManager: authManager,
            aiGenerator: aiGenerator,
            familyMembers: familyMembers,
            tasks: tasks,
            showingCreateTask: showingCreateTask,
            showingAIAssistant: showingAIAssistant,
            showingAISettings: showingAISettings,
            onDataLoad: onDataLoad
        ))
    }
}