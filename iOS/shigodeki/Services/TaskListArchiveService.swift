//
//  TaskListArchiveService.swift
//  shigodeki
//
//  Created by Claude on 2025-09-07.
//

import Foundation
import FirebaseFirestore

struct TaskListArchiveService {
    
    // MARK: - Archive Operations
    
    static func archiveTaskList(id: String, phaseId: String, projectId: String) async throws {
        guard var taskList = try await TaskListCRUDService.getTaskList(id: id, phaseId: phaseId, projectId: projectId) else {
            throw FirebaseError.documentNotFound
        }
        
        taskList.isArchived = true
        _ = try await TaskListCRUDService.updateTaskList(taskList)
    }
    
    static func unarchiveTaskList(id: String, phaseId: String, projectId: String) async throws {
        guard var taskList = try await TaskListCRUDService.getTaskList(id: id, phaseId: phaseId, projectId: projectId) else {
            throw FirebaseError.documentNotFound
        }
        
        taskList.isArchived = false
        _ = try await TaskListCRUDService.updateTaskList(taskList)
    }
}