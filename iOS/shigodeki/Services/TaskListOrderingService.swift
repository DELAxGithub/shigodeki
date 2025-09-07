//
//  TaskListOrderingService.swift
//  shigodeki
//
//  Created by Claude on 2025-09-07.
//

import Foundation
import FirebaseFirestore

struct TaskListOrderingService {
    
    // MARK: - Order Calculations
    
    static func getNextTaskListOrder(phaseId: String, projectId: String) async throws -> Int {
        let taskLists = try await TaskListCRUDService.getTaskLists(phaseId: phaseId, projectId: projectId)
        return taskLists.map { $0.order }.max() ?? 0 + 1
    }
    
    // MARK: - Reordering Operations
    
    static func reorderTaskLists(_ taskLists: [TaskList], phaseId: String, projectId: String) async throws {
        let batch = Firestore.firestore().batch()
        
        for (index, taskList) in taskLists.enumerated() {
            var updatedTaskList = taskList
            updatedTaskList.order = index
            
            let taskListRef = TaskListCRUDService.getTaskListCollection(phaseId: phaseId, projectId: projectId).document(taskList.id ?? "")
            batch.setData(try Firestore.Encoder().encode(updatedTaskList), forDocument: taskListRef, merge: true)
        }
        
        try await batch.commit()
    }
    
    static func reorderTaskLists(phaseId: String, projectId: String) async throws {
        let currentTaskLists = try await TaskListCRUDService.getTaskLists(phaseId: phaseId, projectId: projectId)
        let reorderedTaskLists = currentTaskLists.enumerated().map { index, taskList in
            var updatedTaskList = taskList
            updatedTaskList.order = index
            return updatedTaskList
        }
        try await reorderTaskLists(reorderedTaskLists, phaseId: phaseId, projectId: projectId)
    }
}