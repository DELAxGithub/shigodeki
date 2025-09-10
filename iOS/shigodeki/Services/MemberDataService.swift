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
    @Published var userProjects: [Project] = []
    @Published var assignedTasks: [ShigodekiTask] = []
    
    private let db = Firestore.firestore()
    
    // MARK: - Public Methods
    
    func loadMemberData(userId: String) async -> (projects: [Project], tasks: [ShigodekiTask]) {
        async let projectsResult = loadUserProjects(userId: userId)
        async let tasksResult = loadAssignedTasks(userId: userId)
        let projects = await projectsResult
        let tasks = await tasksResult
        self.userProjects = projects
        self.assignedTasks = tasks
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
            // New schema: projects at root with memberIds
            let query = db.collection("projects")
                .whereField("memberIds", arrayContains: userId)
            let snapshot = try await query.getDocuments()
            var projects: [Project] = snapshot.documents.compactMap { doc in
                var p = try? doc.data(as: Project.self, decoder: Firestore.Decoder())
                p?.id = doc.documentID
                return p
            }
            // Sort locally by createdAt desc
            projects.sort { (a, b) in
                let ad = a.createdAt ?? .distantPast
                let bd = b.createdAt ?? .distantPast
                return ad > bd
            }
            print("Found \(projects.count) projects for user \(userId)")
            return projects
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
            var tasks: [String: ShigodekiTask] = [:]

            // New field name
            let q1 = db.collectionGroup("tasks")
                .whereField("assignedTo", isEqualTo: userId)
                .limit(to: 200)
            let s1 = try await q1.getDocuments()
            for document in s1.documents {
                if let t = parseTask(from: document) { tasks[t.id ?? document.documentID] = t }
            }

            // Legacy field name
            let q2 = db.collectionGroup("tasks")
                .whereField("assigneeId", isEqualTo: userId)
                .limit(to: 200)
            let s2 = try await q2.getDocuments()
            for document in s2.documents {
                if let t = parseTask(from: document) { tasks[t.id ?? document.documentID] = t }
            }

            var loaded = Array(tasks.values)
            loaded.sort { (a, b) in (a.createdAt ?? .distantPast) > (b.createdAt ?? .distantPast) }
            print("Found \(loaded.count) assigned tasks for user \(userId)")
            return loaded
            
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
        // Try to extract hierarchy IDs from path
        let comps = document.reference.path.split(separator: "/").map(String.init)
        var projectId: String = (data["projectId"] as? String) ?? ""
        var phaseId: String = (data["phaseId"] as? String) ?? ""
        var listId: String = (data["listId"] as? String) ?? ""
        if comps.count >= 8 { // projects/{pid}/phases/{phid}/lists/{lid}/tasks/{tid}
            if comps[0] == "projects" { projectId = projectId.isEmpty ? comps[1] : projectId }
            if comps[2] == "phases" { phaseId = phaseId.isEmpty ? comps[3] : phaseId }
            if comps[4] == "lists" { listId = listId.isEmpty ? comps[5] : listId }
        }
        
        var task = ShigodekiTask(
            title: title,
            description: description?.isEmpty == false ? description : nil,
            assignedTo: assignedTo?.isEmpty == false ? assignedTo : nil,
            createdBy: createdBy,
            dueDate: dueDate,
            priority: priority,
            listId: listId,
            phaseId: phaseId,
            projectId: projectId,
            order: data["order"] as? Int ?? 0
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
