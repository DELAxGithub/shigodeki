//
//  DataMigrationUtility.swift
//  shigodeki
//
//  Created by Claude on 2025-08-28.
//

import Foundation
import FirebaseFirestore

class DataMigrationUtility {
    static let shared = DataMigrationUtility()
    private let db = Firestore.firestore()
    
    private init() {}
    
    // MARK: - Family to Project Migration
    
    func migrateFamilyToProject(familyId: String, familyName: String, ownerId: String) async throws -> Project {
        // Create new project from family
        let project = Project(name: familyName, description: "Family: \(familyName) から移行", ownerId: ownerId)
        
        let projectManager = await ProjectManager()
        let createdProject = try await projectManager.createProject(
            name: project.name, 
            description: project.description, 
            ownerId: project.ownerId
        )
        
        // Create default phase
        let phaseManager = await PhaseManager()
        let defaultPhase = try await phaseManager.createPhase(
            name: "メインタスク", 
            description: "Family から移行されたタスク",
            projectId: createdProject.id ?? "",
            createdBy: ownerId,
            order: 0
        )
        
        // Migrate task lists
        try await migrateTaskLists(familyId: familyId, toPhaseId: defaultPhase.id ?? "", projectId: createdProject.id ?? "")
        
        return createdProject
    }
    
    private func migrateTaskLists(familyId: String, toPhaseId: String, projectId: String) async throws {
        let legacyTaskLists = try await getLegacyTaskLists(familyId: familyId)
        let taskListManager = await TaskListManager()
        
        for (index, legacyTaskList) in legacyTaskLists.enumerated() {
            let newTaskList = try await taskListManager.createTaskList(
                name: legacyTaskList.name,
                phaseId: toPhaseId,
                projectId: projectId,
                createdBy: legacyTaskList.createdBy,
                color: legacyTaskList.color,
                order: index
            )
            
            try await migrateTasks(fromLegacyListId: legacyTaskList.id ?? "", familyId: familyId, 
                                 toNewListId: newTaskList.id ?? "", phaseId: toPhaseId, projectId: projectId)
        }
    }
    
    private func getLegacyTaskLists(familyId: String) async throws -> [TaskList] {
        let snapshot = try await db.collection("families").document(familyId).collection("taskLists").getDocuments()
        return try snapshot.documents.compactMap { document in
            try document.data(as: TaskList.self)
        }
    }
    
    private func migrateTasks(fromLegacyListId: String, familyId: String, toNewListId: String, phaseId: String, projectId: String) async throws {
        let legacyTasks = try await getLegacyTasks(listId: fromLegacyListId, familyId: familyId)
        let taskManager = await EnhancedTaskManager()
        
        for (index, legacyTask) in legacyTasks.enumerated() {
            _ = try await taskManager.createTask(
                title: legacyTask.title,
                description: legacyTask.description,
                assignedTo: legacyTask.assignedTo,
                createdBy: legacyTask.createdBy,
                dueDate: legacyTask.dueDate,
                priority: legacyTask.priority,
                listId: toNewListId,
                phaseId: phaseId,
                projectId: projectId,
                order: index
            )
        }
    }
    
    private func getLegacyTasks(listId: String, familyId: String) async throws -> [ShigodekiTask] {
        let snapshot = try await db.collection("families").document(familyId)
            .collection("taskLists").document(listId)
            .collection("tasks").getDocuments()
        return try snapshot.documents.compactMap { document in
            try document.data(as: ShigodekiTask.self)
        }
    }
    
    // MARK: - Validation and Cleanup
    
    func validateMigration(originalFamilyId: String, migratedProjectId: String) async throws -> Bool {
        let legacyTaskLists = try await getLegacyTaskLists(familyId: originalFamilyId)
        let projectManager = await ProjectManager()
        guard (try await projectManager.getProject(id: migratedProjectId)) != nil else { return false }
        
        let phaseManager = await PhaseManager()
        let phases = try await phaseManager.getPhases(projectId: migratedProjectId)
        
        return legacyTaskLists.count > 0 && phases.count > 0
    }
}