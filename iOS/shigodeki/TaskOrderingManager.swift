//
//  TaskOrderingManager.swift
//  shigodeki
//
//  Created by Claude on 2025-08-28.
//

import Foundation
import FirebaseFirestore

struct TaskOrderingManager {
    
    static func reorderTasks(_ tasks: [ShigodekiTask], listId: String, phaseId: String, projectId: String) async throws {
        let batch = Firestore.firestore().batch()
        
        for (index, task) in tasks.enumerated() {
            var updatedTask = task
            updatedTask.order = index
            
            let taskRef = Firestore.firestore()
                .collection("projects").document(projectId)
                .collection("phases").document(phaseId)
                .collection("lists").document(listId)
                .collection("tasks").document(task.id ?? "")
            
            try batch.setData(try Firestore.Encoder().encode(updatedTask), forDocument: taskRef, merge: true)
        }
        
        try await batch.commit()
    }
    
    static func moveTask(_ task: ShigodekiTask, to newListId: String, at newOrder: Int) async throws -> ShigodekiTask {
        // Delete from old location
        let oldTaskRef = Firestore.firestore()
            .collection("projects").document(task.projectId)
            .collection("phases").document(task.phaseId)
            .collection("lists").document(task.listId)
            .collection("tasks").document(task.id ?? "")
        
        // Update task with new location
        var updatedTask = task
        updatedTask.listId = newListId
        updatedTask.order = newOrder
        
        // Create in new location
        let newTaskRef = Firestore.firestore()
            .collection("projects").document(task.projectId)
            .collection("phases").document(task.phaseId)
            .collection("lists").document(newListId)
            .collection("tasks").document(task.id ?? "")
        
        let batch = Firestore.firestore().batch()
        batch.deleteDocument(oldTaskRef)
        try batch.setData(try Firestore.Encoder().encode(updatedTask), forDocument: newTaskRef)
        
        try await batch.commit()
        return updatedTask
    }
}