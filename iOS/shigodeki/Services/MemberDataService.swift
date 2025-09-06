//
//  MemberDataService.swift
//  shigodeki
//
//  Extracted from MemberDetailView.swift for CLAUDE.md compliance
//  Member data loading and management service
//

import Foundation
import FirebaseFirestore

@MainActor
class MemberDataService: ObservableObject {
    @Published var isLoadingProjects = false
    @Published var isLoadingTasks = false
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    
    // MARK: - Public Methods
    
    func loadMemberData(userId: String) async -> (projects: [Project], tasks: [ShigodekiTask]) {
        async let projectsResult = loadUserProjects(userId: userId)
        async let tasksResult = loadAssignedTasks(userId: userId)
        
        let projects = await projectsResult
        let tasks = await tasksResult
        
        return (projects: projects, tasks: tasks)
    }
    
    func loadUserProjects(userId: String) async -> [Project] {
        isLoadingProjects = true
        errorMessage = nil
        defer { isLoadingProjects = false }
        
        guard !userId.isEmpty else {
            errorMessage = "Invalid user ID"
            return []
        }
        
        do {
            // Get all family IDs that this user is part of
            let familyQuery = db.collection("families")
                .whereField("memberIds", arrayContains: userId)
            
            let familySnapshot = try await familyQuery.getDocuments()
            
            if familySnapshot.documents.isEmpty {
                await diagnoseMissingProjects(userId: userId)
                return []
            }
            
            let familyIds = familySnapshot.documents.map { $0.documentID }
            print("User \(userId) is member of families: \(familyIds)")
            
            var allProjects: [Project] = []
            
            // Get projects from each family
            for familyId in familyIds {
                let projectQuery = db.collection("families")
                    .document(familyId)
                    .collection("projects")
                    .order(by: "createdAt", descending: true)
                
                let projectSnapshot = try await projectQuery.getDocuments()
                
                for document in projectSnapshot.documents {
                    if let project = parseProject(from: document, familyId: familyId) {
                        // Only include projects where user is a member
                        if project.memberIds.contains(userId) {
                            allProjects.append(project)
                        }
                    }
                }
            }
            
            print("Found \(allProjects.count) projects for user \(userId)")
            return allProjects
            
        } catch {
            print("Error loading user projects: \(error)")
            errorMessage = "プロジェクトの読み込みに失敗しました"
            return []
        }
    }
    
    func loadAssignedTasks(userId: String) async -> [ShigodekiTask] {
        isLoadingTasks = true
        errorMessage = nil
        defer { isLoadingTasks = false }
        
        guard !userId.isEmpty else {
            errorMessage = "Invalid user ID"
            return []
        }
        
        do {
            // Use collection group query to find all tasks assigned to this user
            let taskQuery = db.collectionGroup("tasks")
                .whereField("assignedTo", isEqualTo: userId)
                .order(by: "createdAt", descending: true)
                .limit(to: 50) // Limit to avoid performance issues
            
            let taskSnapshot = try await taskQuery.getDocuments()
            
            var loadedTasks: [ShigodekiTask] = []
            
            for document in taskSnapshot.documents {
                if let task = parseTask(from: document) {
                    loadedTasks.append(task)
                }
            }
            
            print("Found \(loadedTasks.count) assigned tasks for user \(userId)")
            return loadedTasks
            
        } catch {
            print("Error loading assigned tasks: \(error)")
            errorMessage = "アサイン済みタスクの読み込みに失敗しました"
            return []
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func parseProject(from document: QueryDocumentSnapshot, familyId: String) -> Project? {
        let data = document.data()
        
        guard let name = data["name"] as? String,
              let createdBy = data["createdBy"] as? String else {
            return nil
        }
        
        let description = data["description"] as? String
        // TODO: ProjectStatus doesn't exist yet
        // let statusString = data["status"] as? String ?? "active"
        // let status = ProjectStatus(rawValue: statusString) ?? .active
        let memberIds = data["memberIds"] as? [String] ?? []
        let isArchived = data["isArchived"] as? Bool ?? false
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
        
        var project = Project(
            name: name,
            description: description,
            ownerId: createdBy
        )
        
        project.id = document.documentID
        // project.status = status // TODO: status property doesn't exist
        project.memberIds = memberIds
        project.isArchived = isArchived
        project.createdAt = createdAt
        
        return project
    }
    
    private func parseTask(from document: QueryDocumentSnapshot) -> ShigodekiTask? {
        let data = document.data()
        
        guard let title = data["title"] as? String,
              let createdBy = data["createdBy"] as? String else {
            return nil
        }
        
        let description = data["description"] as? String
        let assignedTo = data["assignedTo"] as? String
        let priorityString = data["priority"] as? String ?? "medium"
        let priority = TaskPriority(rawValue: priorityString) ?? .medium
        let isCompleted = data["isCompleted"] as? Bool ?? false
        let dueDate = (data["dueDate"] as? Timestamp)?.dateValue()
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
        let completedAt = (data["completedAt"] as? Timestamp)?.dateValue()
        
        var task = ShigodekiTask(
            title: title,
            description: description?.isEmpty == false ? description : nil,
            assignedTo: assignedTo?.isEmpty == false ? assignedTo : nil,
            createdBy: createdBy,
            dueDate: dueDate,
            priority: priority
        )
        
        task.id = document.documentID
        task.isCompleted = isCompleted
        task.createdAt = createdAt
        task.completedAt = completedAt
        
        return task
    }
    
    private func diagnoseMissingProjects(userId: String) async {
        print("🔍 Diagnosing missing projects for user: \(userId)")
        
        do {
            // Check if user exists in any family
            let familySnapshot = try await db.collection("families").getDocuments()
            var foundInAnyFamily = false
            
            for familyDoc in familySnapshot.documents {
                let memberIds = familyDoc.data()["memberIds"] as? [String] ?? []
                if memberIds.contains(userId) {
                    print("✅ User found in family: \(familyDoc.documentID)")
                    foundInAnyFamily = true
                    
                    // Check projects in this family
                    let projectSnapshot = try await familyDoc.reference.collection("projects").getDocuments()
                    print("   Family has \(projectSnapshot.documents.count) projects")
                    
                    for projectDoc in projectSnapshot.documents {
                        let projectMemberIds = projectDoc.data()["memberIds"] as? [String] ?? []
                        if projectMemberIds.contains(userId) {
                            print("   ✅ User is member of project: \(projectDoc.data()["name"] ?? "Unknown")")
                        }
                    }
                } else {
                    print("❌ User NOT found in family: \(familyDoc.documentID)")
                }
            }
            
            if !foundInAnyFamily {
                print("🚨 User is not a member of any family!")
            }
            
        } catch {
            print("Error during diagnosis: \(error)")
        }
    }
}