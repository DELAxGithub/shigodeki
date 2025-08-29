//
//  SubtaskManager.swift
//  shigodeki
//
//  Created by Claude on 2025-08-28.
//

import Foundation
import FirebaseFirestore
import Combine

@MainActor
class SubtaskManager: ObservableObject {
    @Published var subtasks: [Subtask] = []
    @Published var isLoading = false
    @Published var error: FirebaseError?
    
    internal var listeners: [ListenerRegistration] = []
    
    deinit {
        // Clean up listeners synchronously - no async operations in deinit
        listeners.forEach { $0.remove() }
        listeners.removeAll()
    }
    
    func createSubtask(title: String, description: String? = nil, assignedTo: String? = nil,
                      createdBy: String, dueDate: Date? = nil, taskId: String, 
                      listId: String, phaseId: String, projectId: String, order: Int? = nil) async throws -> Subtask {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let finalOrder: Int
            if let order = order {
                finalOrder = order
            } else {
                finalOrder = try await getNextSubtaskOrder(taskId: taskId, listId: listId, phaseId: phaseId, projectId: projectId)
            }
            var subtask = Subtask(title: title, description: description, assignedTo: assignedTo,
                                createdBy: createdBy, dueDate: dueDate, taskId: taskId, 
                                listId: listId, phaseId: phaseId, projectId: projectId, order: finalOrder)
            
            try subtask.validate()
            
            let subtaskCollection = getSubtaskCollection(taskId: taskId, listId: listId, phaseId: phaseId, projectId: projectId)
            let documentRef = subtaskCollection.document()
            subtask.id = documentRef.documentID
            subtask.createdAt = Date()
            
            try await documentRef.setData(try Firestore.Encoder().encode(subtask))
            
            // Update parent task subtask count
            try await updateTaskSubtaskCounts(taskId: taskId, listId: listId, phaseId: phaseId, projectId: projectId)
            
            return subtask
        } catch {
            let firebaseError = FirebaseError.from(error)
            self.error = firebaseError
            throw firebaseError
        }
    }
    
    func getSubtasks(taskId: String, listId: String, phaseId: String, projectId: String) async throws -> [Subtask] {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let subtasksCollection = getSubtaskCollection(taskId: taskId, listId: listId, phaseId: phaseId, projectId: projectId)
            let snapshot = try await subtasksCollection.order(by: "order").getDocuments()
            
            return try snapshot.documents.compactMap { document in
                try document.data(as: Subtask.self)
            }
        } catch {
            let firebaseError = FirebaseError.from(error)
            self.error = firebaseError
            throw firebaseError
        }
    }
    
    func updateSubtask(_ subtask: Subtask) async throws -> Subtask {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try subtask.validate()
            
            let subtaskDoc = getSubtaskCollection(taskId: subtask.taskId, listId: subtask.listId, phaseId: subtask.phaseId, projectId: subtask.projectId).document(subtask.id ?? "")
            
            let wasCompleted = subtasks.first(where: { $0.id == subtask.id })?.isCompleted ?? false
            try await subtaskDoc.setData(try Firestore.Encoder().encode(subtask), merge: true)
            
            if let index = subtasks.firstIndex(where: { $0.id == subtask.id }) {
                subtasks[index] = subtask
            }
            
            // Update completion timestamp
            if subtask.isCompleted != wasCompleted {
                var updatedSubtask = subtask
                updatedSubtask.completedAt = subtask.isCompleted ? Date() : nil
                try await subtaskDoc.updateData(["completedAt": updatedSubtask.completedAt as Any])
                
                // Update parent task subtask counts
                try await updateTaskSubtaskCounts(taskId: subtask.taskId, listId: subtask.listId, phaseId: subtask.phaseId, projectId: subtask.projectId)
            }
            
            return subtask
        } catch {
            let firebaseError = FirebaseError.from(error)
            self.error = firebaseError
            throw firebaseError
        }
    }
    
    func deleteSubtask(id: String, taskId: String, listId: String, phaseId: String, projectId: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let subtaskDoc = getSubtaskCollection(taskId: taskId, listId: listId, phaseId: phaseId, projectId: projectId).document(id)
            try await subtaskDoc.delete()
            
            subtasks.removeAll { $0.id == id }
            
            // Update parent task subtask counts
            try await updateTaskSubtaskCounts(taskId: taskId, listId: listId, phaseId: phaseId, projectId: projectId)
        } catch {
            let firebaseError = FirebaseError.from(error)
            self.error = firebaseError
            throw firebaseError
        }
    }
    
    internal func getSubtaskCollection(taskId: String, listId: String, phaseId: String, projectId: String) -> CollectionReference {
        return Firestore.firestore()
            .collection("projects").document(projectId)
            .collection("phases").document(phaseId)
            .collection("lists").document(listId)
            .collection("tasks").document(taskId)
            .collection("subtasks")
    }
    
    private func getNextSubtaskOrder(taskId: String, listId: String, phaseId: String, projectId: String) async throws -> Int {
        let subtasks = try await getSubtasks(taskId: taskId, listId: listId, phaseId: phaseId, projectId: projectId)
        return subtasks.map { $0.order }.max() ?? 0 + 1
    }
    
    private func updateTaskSubtaskCounts(taskId: String, listId: String, phaseId: String, projectId: String) async throws {
        let subtasks = try await getSubtasks(taskId: taskId, listId: listId, phaseId: phaseId, projectId: projectId)
        let completedCount = subtasks.filter { $0.isCompleted }.count
        
        let taskDoc = Firestore.firestore()
            .collection("projects").document(projectId)
            .collection("phases").document(phaseId)
            .collection("lists").document(listId)
            .collection("tasks").document(taskId)
        
        try await taskDoc.updateData([
            "subtaskCount": subtasks.count,
            "completedSubtaskCount": completedCount,
            "hasSubtasks": subtasks.count > 0
        ])
    }
    
    func removeAllListeners() {
        listeners.forEach { $0.remove() }
        listeners.removeAll()
    }
}