//
//  TaskListCRUDService.swift
//  shigodeki
//
//  Created by Claude on 2025-09-07.
//

import Foundation
import FirebaseFirestore

struct TaskListCRUDService {
    
    // MARK: - TaskList Creation
    
    static func createTaskList(name: String, phaseId: String, projectId: String, createdBy: String, color: TaskListColor = .blue, order: Int? = nil) async throws -> TaskList {
        let finalOrder: Int
        if let order = order {
            finalOrder = order
        } else {
            finalOrder = try await TaskListOrderingService.getNextTaskListOrder(phaseId: phaseId, projectId: projectId)
        }
        
        var taskList = TaskList(name: name, phaseId: phaseId, projectId: projectId, createdBy: createdBy, color: color, order: finalOrder)
        
        try taskList.validate()
        
        let taskListCollection = getTaskListCollection(phaseId: phaseId, projectId: projectId)
        let documentRef = taskListCollection.document()
        taskList.id = documentRef.documentID
        taskList.createdAt = Date()
        
        try await documentRef.setData(try Firestore.Encoder().encode(taskList))
        print("📦 TaskListCRUDService: Created list '" + name + "' [" + (taskList.id ?? "") + "] in phase " + phaseId)
        
        return taskList
    }
    
    // Legacy method for backward compatibility
    static func createTaskList(name: String, familyId: String, createdBy: String, color: TaskListColor = .blue) async throws -> TaskList {
        var taskList = TaskList(name: name, familyId: familyId, createdBy: createdBy, color: color)
        try taskList.validate()
        
        let taskListCollection = Firestore.firestore().collection("families").document(familyId).collection("taskLists")
        let documentRef = taskListCollection.document()
        taskList.id = documentRef.documentID
        taskList.createdAt = Date()
        
        try await documentRef.setData(try Firestore.Encoder().encode(taskList))
        
        return taskList
    }
    
    // MARK: - TaskList Reading
    
    static func getTaskList(id: String, phaseId: String, projectId: String) async throws -> TaskList? {
        let taskListDoc = getTaskListCollection(phaseId: phaseId, projectId: projectId).document(id)
        let snapshot = try await taskListDoc.getDocument()
        
        guard snapshot.exists else { return nil }
        return try snapshot.data(as: TaskList.self)
    }
    
    static func getTaskLists(phaseId: String, projectId: String) async throws -> [TaskList] {
        let taskListsCollection = getTaskListCollection(phaseId: phaseId, projectId: projectId)
        let snapshot = try await taskListsCollection.order(by: "order").getDocuments()
        
        return try snapshot.documents.compactMap { document in
            try document.data(as: TaskList.self)
        }
    }
    
    // Legacy method for backward compatibility
    static func getTaskLists(familyId: String) async throws -> [TaskList] {
        let taskListsCollection = Firestore.firestore().collection("families").document(familyId).collection("taskLists")
        let snapshot = try await taskListsCollection.getDocuments()
        
        return try snapshot.documents.compactMap { document in
            try document.data(as: TaskList.self)
        }
    }
    
    // MARK: - TaskList Updating
    
    static func updateTaskList(_ taskList: TaskList) async throws -> TaskList {
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
        
        return taskList
    }
    
    // MARK: - TaskList Deletion
    
    @MainActor
    static func deleteTaskList(id: String, phaseId: String, projectId: String) async throws {
        // Delete all tasks in this task list first
        let enhancedTaskManager = EnhancedTaskManager()
        let tasks = try await enhancedTaskManager.getTasks(listId: id, phaseId: phaseId, projectId: projectId)
        
        for task in tasks {
            try await enhancedTaskManager.deleteTask(id: task.id ?? "", listId: id, phaseId: phaseId, projectId: projectId)
        }
        
        // Delete the task list
        let taskListDoc = getTaskListCollection(phaseId: phaseId, projectId: projectId).document(id)
        try await taskListDoc.delete()
        
        // Reorder remaining task lists
        try await TaskListOrderingService.reorderTaskLists(phaseId: phaseId, projectId: projectId)
    }
    
    // Legacy method for backward compatibility
    static func deleteTaskList(id: String, familyId: String) async throws {
        let taskListDoc = Firestore.firestore().collection("families").document(familyId).collection("taskLists").document(id)
        try await taskListDoc.delete()
    }
    
    // MARK: - Helper Methods
    
    static func getTaskListCollection(phaseId: String, projectId: String) -> CollectionReference {
        return Firestore.firestore()
            .collection("projects").document(projectId)
            .collection("phases").document(phaseId)
            .collection("lists")
    }
}