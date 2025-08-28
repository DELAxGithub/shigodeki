//
//  TaskListManager.swift
//  shigodeki
//
//  Created by Claude on 2025-08-28.
//

import Foundation
import FirebaseFirestore
import Combine

@MainActor
class TaskListManager: ObservableObject {
    @Published var taskLists: [TaskList] = []
    @Published var currentTaskList: TaskList?
    @Published var isLoading = false
    @Published var error: FirebaseError?
    
    private var listeners: [ListenerRegistration] = []
    
    deinit {
        removeAllListeners()
    }
    
    // MARK: - TaskList CRUD Operations
    
    func createTaskList(name: String, phaseId: String, projectId: String, createdBy: String, color: TaskListColor = .blue, order: Int? = nil) async throws -> TaskList {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let finalOrder = order ?? (try await getNextTaskListOrder(phaseId: phaseId, projectId: projectId))
            var taskList = TaskList(name: name, phaseId: phaseId, projectId: projectId, createdBy: createdBy, color: color, order: finalOrder)
            
            try taskList.validate()
            
            let taskListCollection = getTaskListCollection(phaseId: phaseId, projectId: projectId)
            let documentRef = taskListCollection.document()
            taskList.id = documentRef.documentID
            taskList.createdAt = Date()
            
            try await documentRef.setData(try Firestore.Encoder().encode(taskList))
            
            return taskList
        } catch {
            let firebaseError = FirebaseError.from(error)
            self.error = firebaseError
            throw firebaseError
        }
    }
    
    // Legacy method for backward compatibility
    func createTaskList(name: String, familyId: String, createdBy: String, color: TaskListColor = .blue) async throws -> TaskList {
        isLoading = true
        defer { isLoading = false }
        
        do {
            var taskList = TaskList(name: name, familyId: familyId, createdBy: createdBy, color: color)
            try taskList.validate()
            
            let taskListCollection = Firestore.firestore().collection("families").document(familyId).collection("taskLists")
            let documentRef = taskListCollection.document()
            taskList.id = documentRef.documentID
            taskList.createdAt = Date()
            
            try await documentRef.setData(try Firestore.Encoder().encode(taskList))
            
            return taskList
        } catch {
            let firebaseError = FirebaseError.from(error)
            self.error = firebaseError
            throw firebaseError
        }
    }
    
    func getTaskList(id: String, phaseId: String, projectId: String) async throws -> TaskList? {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let taskListDoc = getTaskListCollection(phaseId: phaseId, projectId: projectId).document(id)
            let snapshot = try await taskListDoc.getDocument()
            
            guard snapshot.exists else { return nil }
            return try snapshot.data(as: TaskList.self)
        } catch {
            let firebaseError = FirebaseError.from(error)
            self.error = firebaseError
            throw firebaseError
        }
    }
    
    func getTaskLists(phaseId: String, projectId: String) async throws -> [TaskList] {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let taskListsCollection = getTaskListCollection(phaseId: phaseId, projectId: projectId)
            let snapshot = try await taskListsCollection.order(by: "order").getDocuments()
            
            return try snapshot.documents.compactMap { document in
                try document.data(as: TaskList.self)
            }
        } catch {
            let firebaseError = FirebaseError.from(error)
            self.error = firebaseError
            throw firebaseError
        }
    }
    
    // Legacy method for backward compatibility
    func getTaskLists(familyId: String) async throws -> [TaskList] {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let taskListsCollection = Firestore.firestore().collection("families").document(familyId).collection("taskLists")
            let snapshot = try await taskListsCollection.getDocuments()
            
            return try snapshot.documents.compactMap { document in
                try document.data(as: TaskList.self)
            }
        } catch {
            let firebaseError = FirebaseError.from(error)
            self.error = firebaseError
            throw firebaseError
        }
    }
    
    func updateTaskList(_ taskList: TaskList) async throws -> TaskList {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try taskList.validate()
            
            let taskListDoc: DocumentReference
            if let familyId = taskList.familyId {
                // Legacy path
                taskListDoc = Firestore.firestore().collection("families").document(familyId).collection("taskLists").document(taskList.id ?? "")
            } else {
                // New path
                taskListDoc = getTaskListCollection(phaseId: taskList.phaseId, projectId: taskList.projectId).document(taskList.id ?? "")
            }
            
            try await taskListDoc.setData(try Firestore.Encoder().encode(taskList), merge: true)
            
            // Update local state
            if currentTaskList?.id == taskList.id {
                currentTaskList = taskList
            }
            
            if let index = taskLists.firstIndex(where: { $0.id == taskList.id }) {
                taskLists[index] = taskList
            }
            
            return taskList
        } catch {
            let firebaseError = FirebaseError.from(error)
            self.error = firebaseError
            throw firebaseError
        }
    }
    
    func deleteTaskList(id: String, phaseId: String, projectId: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Delete all tasks in this task list first
            let enhancedTaskManager = EnhancedTaskManager()
            let tasks = try await enhancedTaskManager.getTasks(listId: id, phaseId: phaseId, projectId: projectId)
            
            for task in tasks {
                try await enhancedTaskManager.deleteTask(id: task.id ?? "", listId: id, phaseId: phaseId, projectId: projectId)
            }
            
            // Delete the task list
            let taskListDoc = getTaskListCollection(phaseId: phaseId, projectId: projectId).document(id)
            try await taskListDoc.delete()
            
            // Update local state
            taskLists.removeAll { $0.id == id }
            if currentTaskList?.id == id {
                currentTaskList = nil
            }
            
            // Reorder remaining task lists
            try await reorderTaskLists(phaseId: phaseId, projectId: projectId)
        } catch {
            let firebaseError = FirebaseError.from(error)
            self.error = firebaseError
            throw firebaseError
        }
    }
    
    // Legacy method for backward compatibility
    func deleteTaskList(id: String, familyId: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let taskListDoc = Firestore.firestore().collection("families").document(familyId).collection("taskLists").document(id)
            try await taskListDoc.delete()
            
            taskLists.removeAll { $0.id == id }
            if currentTaskList?.id == id {
                currentTaskList = nil
            }
        } catch {
            let firebaseError = FirebaseError.from(error)
            self.error = firebaseError
            throw firebaseError
        }
    }
    
    // MARK: - TaskList Ordering
    
    private func getNextTaskListOrder(phaseId: String, projectId: String) async throws -> Int {
        let taskLists = try await getTaskLists(phaseId: phaseId, projectId: projectId)
        return taskLists.map { $0.order }.max() ?? 0 + 1
    }
    
    func reorderTaskLists(_ taskLists: [TaskList], phaseId: String, projectId: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let batch = Firestore.firestore().batch()
            
            for (index, taskList) in taskLists.enumerated() {
                var updatedTaskList = taskList
                updatedTaskList.order = index
                
                let taskListRef = getTaskListCollection(phaseId: phaseId, projectId: projectId).document(taskList.id ?? "")
                try batch.setData(try Firestore.Encoder().encode(updatedTaskList), forDocument: taskListRef, merge: true)
            }
            
            try await batch.commit()
            self.taskLists = taskLists.sorted { $0.order < $1.order }
        } catch {
            let firebaseError = FirebaseError.from(error)
            self.error = firebaseError
            throw firebaseError
        }
    }
    
    private func reorderTaskLists(phaseId: String, projectId: String) async throws {
        let currentTaskLists = try await getTaskLists(phaseId: phaseId, projectId: projectId)
        let reorderedTaskLists = currentTaskLists.enumerated().map { index, taskList in
            var updatedTaskList = taskList
            updatedTaskList.order = index
            return updatedTaskList
        }
        try await reorderTaskLists(reorderedTaskLists, phaseId: phaseId, projectId: projectId)
    }
    
    // MARK: - Archive Operations
    
    func archiveTaskList(id: String, phaseId: String, projectId: String) async throws {
        guard var taskList = try await getTaskList(id: id, phaseId: phaseId, projectId: projectId) else {
            throw FirebaseError.documentNotFound
        }
        
        taskList.isArchived = true
        _ = try await updateTaskList(taskList)
    }
    
    func unarchiveTaskList(id: String, phaseId: String, projectId: String) async throws {
        guard var taskList = try await getTaskList(id: id, phaseId: phaseId, projectId: projectId) else {
            throw FirebaseError.documentNotFound
        }
        
        taskList.isArchived = false
        _ = try await updateTaskList(taskList)
    }
    
    // MARK: - Helper Methods
    
    private func getTaskListCollection(phaseId: String, projectId: String) -> CollectionReference {
        return Firestore.firestore()
            .collection("projects").document(projectId)
            .collection("phases").document(phaseId)
            .collection("lists")
    }
    
    // MARK: - Real-time Listeners
    
    func startListeningForTaskLists(phaseId: String, projectId: String) {
        let taskListsCollection = getTaskListCollection(phaseId: phaseId, projectId: projectId)
        
        let listener = taskListsCollection.order(by: "order").addSnapshotListener { [weak self] snapshot, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.error = FirebaseError.from(error)
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    self?.taskLists = []
                    return
                }
                
                do {
                    let taskLists = try documents.compactMap { document in
                        try document.data(as: TaskList.self)
                    }
                    self?.taskLists = taskLists
                } catch {
                    self?.error = FirebaseError.from(error)
                }
            }
        }
        
        listeners.append(listener)
    }
    
    // Legacy listener for backward compatibility
    func startListeningForTaskLists(familyId: String) {
        let taskListsCollection = Firestore.firestore().collection("families").document(familyId).collection("taskLists")
        
        let listener = taskListsCollection.addSnapshotListener { [weak self] snapshot, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.error = FirebaseError.from(error)
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    self?.taskLists = []
                    return
                }
                
                do {
                    let taskLists = try documents.compactMap { document in
                        try document.data(as: TaskList.self)
                    }
                    self?.taskLists = taskLists
                } catch {
                    self?.error = FirebaseError.from(error)
                }
            }
        }
        
        listeners.append(listener)
    }
    
    func removeAllListeners() {
        listeners.forEach { $0.remove() }
        listeners.removeAll()
    }
    
    // MARK: - Validation Helpers
    
    func validateTaskListHierarchy(taskList: TaskList) async throws {
        let enhancedTaskManager = EnhancedTaskManager()
        let tasks = try await enhancedTaskManager.getTasks(listId: taskList.id ?? "", phaseId: taskList.phaseId, projectId: taskList.projectId)
        try ModelRelationships.validateTaskListHierarchy(taskList: taskList, tasks: tasks)
    }
}