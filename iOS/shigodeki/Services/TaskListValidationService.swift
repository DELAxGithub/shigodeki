//
//  TaskListValidationService.swift
//  shigodeki
//
//  Created by Claude on 2025-09-07.
//

import Foundation
import FirebaseFirestore

struct TaskListValidationService {
    
    // MARK: - Validation Operations
    
    @MainActor
    static func validateTaskListHierarchy(taskList: TaskList) async throws {
        let enhancedTaskManager = EnhancedTaskManager()
        let tasks = try await enhancedTaskManager.getTasks(listId: taskList.id ?? "", phaseId: taskList.phaseId, projectId: taskList.projectId)
        try ModelRelationships.validateTaskListHierarchy(taskList: taskList, tasks: tasks)
    }
}