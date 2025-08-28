//
//  EnhancedTaskManager.swift
//  shigodeki
//
//  Created by Claude on 2025-08-28.
//

import Foundation
import FirebaseFirestore
import Combine

@MainActor
class EnhancedTaskManager: ObservableObject {
    @Published var tasks: [ShigodekiTask] = []
    @Published var currentTask: ShigodekiTask?
    @Published var isLoading = false
    @Published var error: FirebaseError?
    
    internal var listeners: [ListenerRegistration] = []
    
    deinit {
        Task { @MainActor in
            removeAllListeners()
        }
    }
    
    // MARK: - Task CRUD Operations
    
    func createTask(title: String, description: String? = nil, assignedTo: String? = nil, 
                   createdBy: String, dueDate: Date? = nil, priority: TaskPriority = .medium,
                   listId: String, phaseId: String, projectId: String, order: Int? = nil) async throws -> ShigodekiTask {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let finalOrder: Int
            if let order = order {
                finalOrder = order
            } else {
                finalOrder = try await getNextTaskOrder(listId: listId, phaseId: phaseId, projectId: projectId)
            }
            var task = ShigodekiTask(title: title, description: description, assignedTo: assignedTo, 
                                   createdBy: createdBy, dueDate: dueDate, priority: priority,
                                   listId: listId, phaseId: phaseId, projectId: projectId, order: finalOrder)
            
            try task.validate()
            
            let taskCollection = getTaskCollection(listId: listId, phaseId: phaseId, projectId: projectId)
            let documentRef = taskCollection.document()
            task.id = documentRef.documentID
            task.createdAt = Date()
            
            try await documentRef.setData(try Firestore.Encoder().encode(task))
            
            return task
        } catch {
            let firebaseError = FirebaseError.from(error)
            self.error = firebaseError
            throw firebaseError
        }
    }
    
    func getTask(id: String, listId: String, phaseId: String, projectId: String) async throws -> ShigodekiTask? {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let taskDoc = getTaskCollection(listId: listId, phaseId: phaseId, projectId: projectId).document(id)
            let snapshot = try await taskDoc.getDocument()
            
            guard snapshot.exists else { return nil }
            return try snapshot.data(as: ShigodekiTask.self)
        } catch {
            let firebaseError = FirebaseError.from(error)
            self.error = firebaseError
            throw firebaseError
        }
    }
    
    func getTasks(listId: String, phaseId: String, projectId: String) async throws -> [ShigodekiTask] {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let tasksCollection = getTaskCollection(listId: listId, phaseId: phaseId, projectId: projectId)
            let snapshot = try await tasksCollection.order(by: "order").getDocuments()
            
            return try snapshot.documents.compactMap { document in
                try document.data(as: ShigodekiTask.self)
            }
        } catch {
            let firebaseError = FirebaseError.from(error)
            self.error = firebaseError
            throw firebaseError
        }
    }
    
    func updateTask(_ task: ShigodekiTask) async throws -> ShigodekiTask {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try task.validate()
            
            let taskDoc = getTaskCollection(listId: task.listId, phaseId: task.phaseId, projectId: task.projectId).document(task.id ?? "")
            try await taskDoc.setData(try Firestore.Encoder().encode(task), merge: true)
            
            if currentTask?.id == task.id {
                currentTask = task
            }
            
            if let index = tasks.firstIndex(where: { $0.id == task.id }) {
                tasks[index] = task
            }
            
            return task
        } catch {
            let firebaseError = FirebaseError.from(error)
            self.error = firebaseError
            throw firebaseError
        }
    }
    
    func deleteTask(id: String, listId: String, phaseId: String, projectId: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let subtaskManager = SubtaskManager()
            let subtasks = try await subtaskManager.getSubtasks(taskId: id, listId: listId, phaseId: phaseId, projectId: projectId)
            
            for subtask in subtasks {
                try await subtaskManager.deleteSubtask(id: subtask.id ?? "", taskId: id, listId: listId, phaseId: phaseId, projectId: projectId)
            }
            
            let taskDoc = getTaskCollection(listId: listId, phaseId: phaseId, projectId: projectId).document(id)
            try await taskDoc.delete()
            
            tasks.removeAll { $0.id == id }
            if currentTask?.id == id {
                currentTask = nil
            }
            
            try await reorderTasks(listId: listId, phaseId: phaseId, projectId: projectId)
        } catch {
            let firebaseError = FirebaseError.from(error)
            self.error = firebaseError
            throw firebaseError
        }
    }
    
    // MARK: - Helper Methods
    
    internal func getTaskCollection(listId: String, phaseId: String, projectId: String) -> CollectionReference {
        return Firestore.firestore()
            .collection("projects").document(projectId)
            .collection("phases").document(phaseId)
            .collection("lists").document(listId)
            .collection("tasks")
    }
    
    private func getNextTaskOrder(listId: String, phaseId: String, projectId: String) async throws -> Int {
        let tasks = try await getTasks(listId: listId, phaseId: phaseId, projectId: projectId)
        return tasks.map { $0.order }.max() ?? 0 + 1
    }
    
    private func reorderTasks(listId: String, phaseId: String, projectId: String) async throws {
        let currentTasks = try await getTasks(listId: listId, phaseId: phaseId, projectId: projectId)
        let reorderedTasks = currentTasks.enumerated().map { index, task in
            var updatedTask = task
            updatedTask.order = index
            return updatedTask
        }
        try await TaskOrderingManager.reorderTasks(reorderedTasks, listId: listId, phaseId: phaseId, projectId: projectId)
    }
    
    func removeAllListeners() {
        listeners.forEach { $0.remove() }
        listeners.removeAll()
    }
}