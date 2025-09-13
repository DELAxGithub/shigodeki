//
//  TaskCreationService.swift
//  shigodeki
//
//  Extracted from CreateTaskView.swift for CLAUDE.md compliance
//  Handles async task creation operations
//

import Foundation

@MainActor
class TaskCreationService: ObservableObject {
    @Published var isCreating = false
    @Published var showSuccess = false
    @Published var errorMessage: String?
    
    private let taskManager: TaskManager
    private let tagManager: TagManager
    
    init(taskManager: TaskManager, tagManager: TagManager) {
        self.taskManager = taskManager
        self.tagManager = tagManager
    }
    
    func createTask(
        title: String,
        description: String,
        taskList: TaskList,
        family: Family,
        creatorUserId: String,
        selectedAssignee: String?,
        dueDate: Date?,
        hasDueDate: Bool,
        selectedPriority: TaskPriority,
        selectedTags: [String],
        attachments: [String]
    ) async {
        guard let taskListId = taskList.id, 
              let familyId = family.id else { 
            errorMessage = "Invalid task list or family ID"
            return 
        }
        
        isCreating = true
        errorMessage = nil
        
        do {
            _ = try await taskManager.createTask(
                title: title,
                description: description.isEmpty ? nil : description,
                taskListId: taskListId,
                familyId: familyId,
                creatorUserId: creatorUserId,
                assignedTo: selectedAssignee,
                dueDate: hasDueDate ? dueDate : nil,
                priority: selectedPriority,
                tags: selectedTags,
                attachments: attachments
            )
            
            // Update tag usage counts with proper async handling
            await updateTagUsage(selectedTags, projectId: taskList.projectId)
            
            isCreating = false
            showSuccess = true
            
        } catch {
            isCreating = false
            errorMessage = "タスクの作成に失敗しました: \(error.localizedDescription)"
        }
    }
    
    private func updateTagUsage(_ selectedTags: [String], projectId: String) async {
        guard !selectedTags.isEmpty else { return }
        
        for tagName in selectedTags {
            await tagManager.incrementUsage(for: tagName, projectId: projectId)
        }
    }
}

// MARK: - Tag Management Helper

extension TaskCreationService {
    func loadTags(projectId: String) async {
        guard !projectId.isEmpty else { return }
        
        await tagManager.loadTags(projectId: projectId)
        tagManager.startListening(projectId: projectId)
    }
    
    func stopTagListening() {
        tagManager.stopListening()
    }
}
