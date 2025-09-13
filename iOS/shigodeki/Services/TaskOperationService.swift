//
//  TaskOperationService.swift
//  shigodeki
//
//  Created by Claude on 2025-09-06.
//

import Foundation
import FirebaseFirestore

struct TaskOperationService {
    // MARK: - Task Operations
    
    // MARK: - Phase-based Task Creation
    
    static func createPhaseTask(
        title: String, 
        description: String? = nil, 
        taskListId: String, 
        projectId: String, 
        phaseId: String, 
        creatorUserId: String, 
        assignedTo: String? = nil, 
        dueDate: Date? = nil, 
        priority: TaskPriority = .medium,
        db: Firestore
    ) async throws -> String {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TaskError.invalidTitle
        }
        
        var task = ShigodekiTask(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines), 
            description: description?.trimmingCharacters(in: .whitespacesAndNewlines),
            assignedTo: assignedTo,
            createdBy: creatorUserId,
            dueDate: dueDate,
            priority: priority
        )
        task.createdAt = Date()
        
        let taskData: [String: Any] = [
            "title": task.title,
            "description": task.description ?? "",
            "isCompleted": task.isCompleted,
            "assignedTo": task.assignedTo ?? "",
            "createdBy": task.createdBy,
            "priority": task.priority.rawValue,
            "createdAt": FieldValue.serverTimestamp(),
            "completedAt": NSNull(),
            "dueDate": task.dueDate != nil ? Timestamp(date: task.dueDate!) : NSNull()
        ]
        
        do {
            // Save to project-based path: projects/{projectId}/phases/{phaseId}/lists/{taskListId}/tasks
            let taskRef = try await db.collection("projects").document(projectId)
                .collection("phases").document(phaseId)
                .collection("lists").document(taskListId)
                .collection("tasks").addDocument(data: taskData)
            let taskId = taskRef.documentID
            
            print("Phase task created successfully with ID: \(taskId)")
            return taskId
            
        } catch {
            print("Error creating phase task: \(error)")
            throw TaskError.creationFailed(error.localizedDescription)
        }
    }

    static func createTask(
        title: String, 
        description: String? = nil, 
        taskListId: String, 
        familyId: String, 
        creatorUserId: String, 
        assignedTo: String? = nil, 
        dueDate: Date? = nil, 
        priority: TaskPriority = .medium, 
        tags: [String] = [],
        attachments: [String] = [],
        db: Firestore
    ) async throws -> String {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TaskError.invalidTitle
        }
        
        var task = ShigodekiTask(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines), 
            description: description?.trimmingCharacters(in: .whitespacesAndNewlines),
            assignedTo: assignedTo,
            createdBy: creatorUserId,
            dueDate: dueDate,
            priority: priority
        )
        task.createdAt = Date()
        task.tags = tags
        
        let taskData: [String: Any] = [
            "title": task.title,
            "description": task.description ?? "",
            "isCompleted": task.isCompleted,
            "assignedTo": task.assignedTo ?? "",
            "createdBy": task.createdBy,
            "priority": task.priority.rawValue,
            "tags": task.tags,
            "attachments": attachments,
            "createdAt": FieldValue.serverTimestamp(),
            "completedAt": NSNull(),
            "dueDate": task.dueDate != nil ? Timestamp(date: task.dueDate!) : NSNull()
        ]
        
        do {
            let taskRef = try await db.collection("families").document(familyId)
                .collection("taskLists").document(taskListId)
                .collection("tasks").addDocument(data: taskData)
            let taskId = taskRef.documentID
            
            print("Task created successfully with ID: \(taskId)")
            return taskId
            
        } catch {
            print("Error creating task: \(error)")
            throw TaskError.creationFailed(error.localizedDescription)
        }
    }
    
    static func toggleTaskCompletion(
        taskId: String, 
        taskListId: String, 
        familyId: String,
        db: Firestore
    ) async throws {
        let taskRef = db.collection("families").document(familyId)
            .collection("taskLists").document(taskListId)
            .collection("tasks").document(taskId)
        
        do {
            let taskDoc = try await taskRef.getDocument()
            guard let data = taskDoc.data(),
                  let isCompleted = data["isCompleted"] as? Bool else {
                throw TaskError.notFound
            }
            
            let newCompletedState = !isCompleted
            let updateData: [String: Any] = [
                "isCompleted": newCompletedState,
                "completedAt": newCompletedState ? FieldValue.serverTimestamp() : NSNull()
            ]
            
            try await taskRef.updateData(updateData)
            
        } catch {
            print("Error toggling task completion: \(error)")
            throw TaskError.updateFailed(error.localizedDescription)
        }
    }
    
    static func loadTasks(
        taskListId: String, 
        familyId: String,
        db: Firestore
    ) async throws -> [ShigodekiTask] {
        do {
            let tasksSnapshot = try await db.collection("families").document(familyId)
                .collection("taskLists").document(taskListId)
                .collection("tasks")
                .order(by: "createdAt", descending: false)
                .getDocuments()
            
            var loadedTasks: [ShigodekiTask] = []
            
            for document in tasksSnapshot.documents {
                if let task = parseTask(from: document) {
                    loadedTasks.append(task)
                }
            }
            
            return loadedTasks
            
        } catch {
            print("Error loading tasks: \(error)")
            throw TaskError.notFound
        }
    }
    
    // MARK: - Helper Methods
    
    static func parseTask(from document: QueryDocumentSnapshot) -> ShigodekiTask? {
        let data = document.data()
        
        guard let title = data["title"] as? String,
              let createdBy = data["createdBy"] as? String else {
            return nil
        }
        
        let description = data["description"] as? String
        let assignedTo = data["assignedTo"] as? String
        let dueDate = (data["dueDate"] as? Timestamp)?.dateValue()
        let priority = TaskPriority(rawValue: data["priority"] as? String ?? "medium") ?? .medium
        
        var task = ShigodekiTask(
            title: title,
            description: description?.isEmpty == false ? description : nil,
            assignedTo: assignedTo?.isEmpty == false ? assignedTo : nil,
            createdBy: createdBy,
            dueDate: dueDate,
            priority: priority
        )

        task.id = document.documentID
        task.isCompleted = data["isCompleted"] as? Bool ?? false
        task.createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
        task.completedAt = (data["completedAt"] as? Timestamp)?.dateValue()
        if let atts = data["attachments"] as? [String], !atts.isEmpty {
            task.attachments = atts
        }

        return task
    }
}
