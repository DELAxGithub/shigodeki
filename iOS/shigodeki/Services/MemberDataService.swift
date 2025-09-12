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
    @Published var phasesByProject: [String: [Phase]] = [:]
    
    private let db = Firestore.firestore()
    private var userProjectsListener: ListenerRegistration?
    
    // MARK: - Public Methods
    
    func loadMemberData(userId: String) async -> (projects: [Project], tasks: [ShigodekiTask]) {
        async let projectsResult = loadUserProjects(userId: userId)
        async let tasksResult = loadAssignedTasks(userId: userId)
        let projects = await projectsResult
        let tasks = await tasksResult
        self.userProjects = projects
        self.assignedTasks = tasks
        // Preload phases for the projects referenced by tasks (for grouping/UI labels)
        let pids = Set(tasks.map { $0.projectId }.filter { !$0.isEmpty })
        await ensurePhasesLoaded(forProjectIds: pids)
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
        
        func performQuery() async throws -> [Project] {
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
        }

        do {
            return try await performQuery()
        } catch {
            let nsError = error as NSError
            print("Error loading user projects (attempt1): code=\(nsError.code) domain=\(nsError.domain)")
            // Quick retry for startup races (unauth or permission timing)
            if nsError.code == 7 || nsError.code == 16 { // permission-denied / unauthenticated
                try? await Task.sleep(nanoseconds: 200_000_000)
                do { return try await performQuery() } catch { /* fallthrough */ }
            }
            errorMessage = "プロジェクトの読み込みに失敗しました"
            return []
        }
    }
    
    // MARK: - Realtime listener for user projects
    func startListeningUserProjects(userId: String) {
        // Cancel previous listener if any
        userProjectsListener?.remove()
        guard !userId.isEmpty else { return }
        
        let query = db.collection("projects").whereField("memberIds", arrayContains: userId)
        userProjectsListener = query.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            if let error = error {
                print("❌ MemberDataService: project listener error=\(error)")
                return
            }
            guard let docs = snapshot?.documents else {
                self.userProjects = []
                return
            }
            var projects: [Project] = docs.compactMap { doc in
                var p = try? doc.data(as: Project.self, decoder: Firestore.Decoder())
                p?.id = doc.documentID
                return p
            }
            projects.sort { (a, b) in (a.createdAt ?? .distantPast) > (b.createdAt ?? .distantPast) }
            self.userProjects = projects
            print("👂 MemberDataService: realtime projects=\(projects.count) for user \(userId)")
        }
    }
    
    deinit {
        userProjectsListener?.remove()
    }
    
    func loadAssignedTasks(userId: String) async -> [ShigodekiTask] {
        isLoadingTasks = true
        errorMessage = nil
        defer { isLoadingTasks = false }

        guard !userId.isEmpty else {
            errorMessage = "Invalid user ID"
            return []
        }

        var tasks: [String: ShigodekiTask] = [:]
        var anyQuerySucceeded = false

        // Try new schema field first: assignedTo
        do {
            let q1 = db.collectionGroup("tasks")
                .whereField("assignedTo", isEqualTo: userId)
                .limit(to: 200)
            let s1 = try await q1.getDocuments()
            for document in s1.documents {
                if let t = parseTask(from: document) { tasks[t.id ?? document.documentID] = t }
            }
            anyQuerySucceeded = true
        } catch {
            let nsError = error as NSError
            print("Assigned tasks (assignedTo) query failed: code=\(nsError.code) domain=\(nsError.domain) userInfo=\(nsError.userInfo)")
            // Continue to legacy query even if this one fails (e.g., missing index)
        }

        // Try legacy field: assigneeId
        do {
            let q2 = db.collectionGroup("tasks")
                .whereField("assigneeId", isEqualTo: userId)
                .limit(to: 200)
            let s2 = try await q2.getDocuments()
            for document in s2.documents {
                if let t = parseTask(from: document) { tasks[t.id ?? document.documentID] = t }
            }
            anyQuerySucceeded = true
        } catch {
            let nsError = error as NSError
            print("Assigned tasks (assigneeId) query failed: code=\(nsError.code) domain=\(nsError.domain) userInfo=\(nsError.userInfo)")
        }

        var loaded = Array(tasks.values)
        loaded.sort { (a, b) in (a.createdAt ?? .distantPast) > (b.createdAt ?? .distantPast) }
        // Drop obviously orphan/invalid tasks (no project linkage)
        loaded = loaded.filter { !$0.projectId.isEmpty }

        if !anyQuerySucceeded {
            // Quick retry for startup races (unauth or permission timing)
            try? await Task.sleep(nanoseconds: 200_000_000)

            var retryTasks: [String: ShigodekiTask] = [:]
            var retrySucceeded = false
            // Retry new
            do {
                let q1 = db.collectionGroup("tasks").whereField("assignedTo", isEqualTo: userId).limit(to: 200)
                let s1 = try await q1.getDocuments()
                for document in s1.documents { if let t = parseTask(from: document) { retryTasks[t.id ?? document.documentID] = t } }
                retrySucceeded = true
            } catch { /* keep */ }
            // Retry legacy
            do {
                let q2 = db.collectionGroup("tasks").whereField("assigneeId", isEqualTo: userId).limit(to: 200)
                let s2 = try await q2.getDocuments()
                for document in s2.documents { if let t = parseTask(from: document) { retryTasks[t.id ?? document.documentID] = t } }
                retrySucceeded = true || retrySucceeded
            } catch { /* keep */ }

            if retrySucceeded {
                var final = Array(retryTasks.values).sorted { (a, b) in (a.createdAt ?? .distantPast) > (b.createdAt ?? .distantPast) }
                final = final.filter { !$0.projectId.isEmpty }
                print("Found \(final.count) assigned tasks for user \(userId) after retry")
                return final
            }

            // Both queries failed – surface a single, user-friendly error
            errorMessage = "アサイン済みタスクの読み込みに失敗しました"
            print("Error loading assigned tasks: both queries failed for user \(userId)")
            return []
        }

        print("Found \(loaded.count) assigned tasks for user \(userId)")
        return loaded
    }
    
    // MARK: - Phase Preload (for grouping by Project > Phase)
    func ensurePhasesLoaded(forProjectIds projectIds: Set<String>) async {
        guard !projectIds.isEmpty else { return }
        let missing = projectIds.filter { phasesByProject[$0] == nil }
        guard !missing.isEmpty else { return }
        do {
            var fetched: [String: [Phase]] = [:]
            for pid in missing {
                let phasesCollection = db.collection("projects").document(pid).collection("phases")
                let snapshot = try await phasesCollection.order(by: "order").getDocuments()
                let phases: [Phase] = try snapshot.documents.map { doc in
                    var p = try doc.data(as: Phase.self, decoder: Firestore.Decoder())
                    p.id = doc.documentID
                    return p
                }
                fetched[pid] = phases
            }
            // Merge into published state
            for (pid, phases) in fetched { self.phasesByProject[pid] = phases }
        } catch {
            print("⚠️ Failed to preload phases for projects: \(projectIds) error=\(error)")
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
