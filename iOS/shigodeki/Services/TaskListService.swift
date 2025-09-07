//
//  TaskListService.swift
//  shigodeki
//
//  Created by Claude on 2025-09-06.
//

import Foundation
import FirebaseFirestore

struct TaskListService {
    // MARK: - TaskList Operations
    
    static func createTaskList(
        name: String, 
        familyId: String, 
        creatorUserId: String, 
        color: TaskListColor = .blue,
        db: Firestore
    ) async throws -> String {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TaskError.invalidName
        }
        
        var taskList = TaskList(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines), 
            familyId: familyId, 
            createdBy: creatorUserId, 
            color: color
        )
        taskList.createdAt = Date()
        
        let taskListData: [String: Any] = [
            "name": taskList.name,
            "familyId": taskList.familyId as Any,
            "createdBy": taskList.createdBy,
            "color": taskList.color.rawValue,
            "isArchived": taskList.isArchived,
            "createdAt": FieldValue.serverTimestamp()
        ]
        
        do {
            let taskListRef = try await db.collection("families").document(familyId)
                .collection("taskLists").addDocument(data: taskListData)
            let taskListId = taskListRef.documentID
            
            print("TaskList created successfully with ID: \(taskListId)")
            return taskListId
            
        } catch {
            print("Error creating task list: \(error)")
            throw TaskError.creationFailed(error.localizedDescription)
        }
    }
    
    static func loadTaskLists(
        familyId: String,
        db: Firestore
    ) async throws -> [TaskList] {
        do {
            let taskListsSnapshot = try await db.collection("families").document(familyId)
                .collection("taskLists")
                .whereField("isArchived", isEqualTo: false)
                .order(by: "createdAt", descending: false)
                .getDocuments()
            
            var loadedTaskLists: [TaskList] = []
            
            for document in taskListsSnapshot.documents {
                if let taskList = parseTaskList(from: document) {
                    loadedTaskLists.append(taskList)
                }
            }
            
            return loadedTaskLists
            
        } catch {
            print("Error loading task lists: \(error)")
            throw TaskError.notFound
        }
    }
    
    // MARK: - Helper Methods
    
    static func parseTaskList(from document: QueryDocumentSnapshot) -> TaskList? {
        let data = document.data()
        
        guard let name = data["name"] as? String,
              let familyId = data["familyId"] as? String,
              let createdBy = data["createdBy"] as? String else {
            return nil
        }
        
        var taskList = TaskList(
            name: name,
            familyId: familyId,
            createdBy: createdBy,
            color: TaskListColor(rawValue: data["color"] as? String ?? "blue") ?? .blue
        )
        
        taskList.id = document.documentID
        taskList.isArchived = data["isArchived"] as? Bool ?? false
        taskList.createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
        
        return taskList
    }
}