//
//  ProjectManager.swift
//  shigodeki
//
//  Created by Claude on 2025-08-28.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

@MainActor
class ProjectManager: ObservableObject {
    @Published var projects: [Project] = []
    @Published var currentProject: Project?
    @Published var isLoading = false
    @Published var error: FirebaseError?
    
    // Template integration
    @Published var templates: [ProjectTemplate] = []
    @Published var isLoadingTemplates = false
    
    private let projectOperations = FirebaseOperationBase<Project>(collectionPath: "projects")
    private let memberOperations = FirebaseOperationBase<ProjectMember>(collectionPath: "projects")
    private let templateImporter = TemplateImporter()
    private let templateExporter = TemplateExporter()
    
    // 🆕 統合された Firebase リスナー管理
    private let listenerManager = FirebaseListenerManager.shared
    private var activeListenerIds: Set<String> = []
    private var currentUserId: String?
    // Pending create/update guard to avoid race where listener briefly reports 0 and clears UI
    private var pendingProjectTimestamps: [String: Date] = [:]
    private var lastLocalChangeAt: Date = .distantPast
    private let pendingTTL: TimeInterval = 5.0
    
    deinit {
        // 🆕 中央集中化されたリスナー管理で削除
        Task { @MainActor [weak self] in
            self?.removeAllListeners()
        }
    }
    
    // MARK: - Project CRUD Operations
    
    func createProject(name: String, description: String? = nil, ownerId: String, ownerType: ProjectOwnerType = .individual, createdByUserId: String) async throws -> Project {
        print("🚀 Starting project creation - Name: '\(name)', Owner: '\(ownerId)'")
        isLoading = true
        defer { isLoading = false }
        
        do {
            print("📝 Creating project object...")
            let project = Project(name: name, description: description, ownerId: ownerId, ownerType: ownerType)
            print("📝 Project object created: \(project)")
            
            print("✅ Validating project...")
            try project.validate()
            print("✅ Project validation passed")
            
            // 🚀 Optimistic UI Update: Add to local list immediately
            print("⚡ Adding project optimistically to UI")
            projects.append(project)
            
            // 🔍 Debug Firebase Auth state before Firestore operation
            print("🔍 Firebase Auth Debug before Firestore create:")
            if let currentUser = Auth.auth().currentUser {
                print("   Firebase Auth UID: \(currentUser.uid)")
                print("   Firebase Auth isAnonymous: \(currentUser.isAnonymous)")
                print("   Firebase Auth providerData count: \(currentUser.providerData.count)")
                
                // Get auth token to verify it's valid
                do {
                    let token = try await currentUser.getIDToken()
                    print("   Auth token obtained: \(token.prefix(20))...")
                    
                    // Force refresh token for TestFlight reliability
                    let freshToken = try await currentUser.getIDToken(forcingRefresh: true)
                    print("   Fresh auth token obtained: \(freshToken.prefix(20))...")
                } catch {
                    print("❌ Failed to get auth token: \(error)")
                    throw FirebaseError.operationFailed("認証トークンの取得に失敗しました。再度サインインしてください。")
                }
            } else {
                print("❌ No Firebase Auth currentUser found")
            }
            
            print("🔄 Creating project in Firestore...")
            let createdProject = try await projectOperations.create(project)
            print("🎉 Project created successfully with ID: \(createdProject.id ?? "NO_ID")")
            
            // Update the local project with the real ID from Firestore
            if let index = projects.firstIndex(where: { $0.name == project.name && $0.ownerId == ownerId }) {
                projects[index] = createdProject
            }
            // Mark pending to protect against empty listener snapshots for a short TTL
            if let pid = createdProject.id { pendingProjectTimestamps[pid] = Date(); lastLocalChangeAt = Date() }
            
            // Create initial project member entry
            if ownerType == .individual {
                print("👤 Creating owner member entry (individual)...")
                let displayName = AuthenticationManager.shared.currentUser?.name
                let ownerMember = ProjectMember(userId: ownerId, projectId: createdProject.id ?? "", role: .owner, invitedBy: createdByUserId, displayName: displayName)
                try await createProjectMember(ownerMember, in: createdProject.id ?? "")
                print("👤 Owner member created successfully")
            } else {
                // Family-owned projects: add all family members, mark creator as owner
                print("👥 Family-owned project: populating members from family \(ownerId)")
                let familyDoc = try await Firestore.firestore().collection("families").document(ownerId).getDocument()
                let familyMembers = (familyDoc.data()? ["members"] as? [String]) ?? []
                var updated = createdProject
                updated.memberIds = Array(Set(familyMembers))
                _ = try await updateProject(updated)
                // Create member docs
                for uid in familyMembers {
                    let role: Role = (uid == createdByUserId) ? .owner : .editor
                    let dn = (uid == createdByUserId) ? AuthenticationManager.shared.currentUser?.name : nil
                    let member = ProjectMember(userId: uid, projectId: createdProject.id ?? "", role: role, invitedBy: createdByUserId, displayName: dn)
                    try await createProjectMember(member, in: createdProject.id ?? "")
                }
                print("👥 Family-owned project membership populated: \(familyMembers.count) members")
            }
            
            print("✨ Project creation completed successfully!")
            return createdProject
        } catch {
            print("❌ Project creation failed: \(error)")
            print("❌ Error details: \(error.localizedDescription)")
            if let firestoreError = error as NSError? {
                print("❌ Firestore error code: \(firestoreError.code)")
                print("❌ Firestore error domain: \(firestoreError.domain)")
                print("❌ Firestore error userInfo: \(firestoreError.userInfo)")
            }
            
            // 🔄 Rollback: Remove optimistically added project on error
            print("🔄 Rolling back optimistic UI update")
            projects.removeAll { $0.name == name && $0.ownerId == ownerId }
            
            let firebaseError = FirebaseError.from(error)
            self.error = firebaseError
            throw firebaseError
        }
    }
    
    func getProject(id: String) async throws -> Project? {
        isLoading = true
        defer { isLoading = false }
        
        do {
            return try await projectOperations.read(id: id)
        } catch {
            let firebaseError = FirebaseError.from(error)
            self.error = firebaseError
            throw firebaseError
        }
    }
    
    func updateProject(_ project: Project) async throws -> Project {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try project.validate()
            let updatedProject = try await projectOperations.update(project)
            
            // Update current project if it's the same
            if currentProject?.id == project.id {
                currentProject = updatedProject
            }
            
            // Update in projects array
            if let index = projects.firstIndex(where: { $0.id == project.id }) {
                projects[index] = updatedProject
            }
            
            return updatedProject
        } catch {
            let firebaseError = FirebaseError.from(error)
            self.error = firebaseError
            throw firebaseError
        }
    }
    
    func deleteProject(id: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Delete all project members first
            let members = try await getProjectMembers(projectId: id)
            for member in members {
                try await deleteProjectMember(userId: member.userId, projectId: id)
            }
            
            // Delete the project
            try await projectOperations.delete(id: id)
            
            // Remove from local arrays
            projects.removeAll { $0.id == id }
            if currentProject?.id == id {
                currentProject = nil
            }
        } catch {
            let firebaseError = FirebaseError.from(error)
            self.error = firebaseError
            throw firebaseError
        }
    }
    
    func getUserProjects(userId: String) async throws -> [Project] {
        print("📋 Loading projects for user: '\(userId)'")
        isLoading = true
        defer { isLoading = false }
        
        do {
            print("🔍 Querying projects where memberIds array contains user...")
            let foundProjects = try await projectOperations.list(where: "memberIds", arrayContains: userId)
            print("📊 Found \(foundProjects.count) projects for user")
            
            for (index, project) in foundProjects.enumerated() {
                print("📄 Project \(index + 1): '\(project.name)' (ID: \(project.id ?? "NO_ID"))")
            }
            
            // 🔥 CRITICAL FIX: Update the @Published projects array
            await MainActor.run {
                self.projects = foundProjects
                print("🔄 Updated ProjectManager.projects array with \(foundProjects.count) projects")
            }
            
            return foundProjects
        } catch {
            print("❌ Failed to load user projects: \(error)")
            print("❌ Error details: \(error.localizedDescription)")
            let firebaseError = FirebaseError.from(error)
            self.error = firebaseError
            throw firebaseError
        }
    }
    
    // MARK: - Project Member Operations
    
    private func createProjectMember(_ member: ProjectMember, in projectId: String) async throws {
        let memberCollection = Firestore.firestore().collection("projects").document(projectId).collection("members")
        try await memberCollection.document(member.userId).setData(try Firestore.Encoder().encode(member))
    }
    
    func addMember(userId: String, to projectId: String, with role: Role, invitedBy: String) async throws -> ProjectMember {
        do {
            // Create project member
            var displayName: String? = nil
            // Try to resolve displayName from users collection (may fail due to rules)
            do {
                let userDoc = try await Firestore.firestore().collection("users").document(userId).getDocument()
                if let data = userDoc.data() {
                    displayName = data["name"] as? String
                }
            } catch {
                // Silently ignore permission or network errors; keep displayName nil
            }
            let member = ProjectMember(userId: userId, projectId: projectId, role: role, invitedBy: invitedBy, displayName: displayName)
            try member.validate()
            
            try await createProjectMember(member, in: projectId)
            
            // Update project memberIds
            if var project = try await projectOperations.read(id: projectId) {
                if !project.memberIds.contains(userId) {
                    project.memberIds.append(userId)
                    // Mark pending to protect UI from transient empty snapshots
                    pendingProjectTimestamps[projectId] = Date(); lastLocalChangeAt = Date()
                    _ = try await updateProject(project)
                }
            }
            
            return member
        } catch {
            let firebaseError = FirebaseError.from(error)
            self.error = firebaseError
            throw firebaseError
        }
    }
    
    func getProjectMembers(projectId: String) async throws -> [ProjectMember] {
        let memberCollection = Firestore.firestore().collection("projects").document(projectId).collection("members")
        
        do {
            let snapshot = try await memberCollection.getDocuments()
            return try snapshot.documents.compactMap { document in
                try document.data(as: ProjectMember.self)
            }
        } catch {
            let firebaseError = FirebaseError.from(error)
            self.error = firebaseError
            throw firebaseError
        }
    }
    
    func updateMemberRole(userId: String, projectId: String, newRole: Role) async throws {
        let memberDoc = Firestore.firestore().collection("projects").document(projectId).collection("members").document(userId)
        
        do {
            try await memberDoc.updateData(["role": newRole.rawValue])
        } catch {
            let firebaseError = FirebaseError.from(error)
            self.error = firebaseError
            throw firebaseError
        }
    }
    
    func removeMember(userId: String, from projectId: String) async throws {
        do {
            // Remove from project members collection
            try await deleteProjectMember(userId: userId, projectId: projectId)
            
            // Update project memberIds
            if var project = try await projectOperations.read(id: projectId) {
                project.memberIds.removeAll { $0 == userId }
                // Mark pending to protect UI from transient empty snapshots
                pendingProjectTimestamps[projectId] = Date(); lastLocalChangeAt = Date()
                _ = try await updateProject(project)
            }
        } catch {
            let firebaseError = FirebaseError.from(error)
            self.error = firebaseError
            throw firebaseError
        }
    }
    
    private func deleteProjectMember(userId: String, projectId: String) async throws {
        let memberDoc = Firestore.firestore().collection("projects").document(projectId).collection("members").document(userId)
        try await memberDoc.delete()
    }
    
    // MARK: - Statistics Updates
    
    func updateProjectStatistics(projectId: String, stats: ProjectStats) async throws {
        guard var project = try await projectOperations.read(id: projectId) else {
            throw FirebaseError.documentNotFound
        }
        
        project.statistics = stats
        project.lastModifiedAt = Date()
        
        _ = try await updateProject(project)
    }
    
    // MARK: - Real-time Listeners (🆕 統合版)
    
    func startListeningForUserProjects(userId: String) {
        guard !userId.isEmpty else {
            print("❌ ProjectManager: Invalid userId for listener")
            return
        }
        print("🎧 ProjectManager: Starting optimized listener for user: \(userId)")
        currentUserId = userId
        
        // 既存のユーザー向けリスナーを一旦解除（再構成のため）
        removeProjectListener()
        
        // 結果のマージ用ストレージ
        var map: [String: Project] = [:]
        func applyMerged() {
            let now = Date()
            let remoteList = Array(map.values)
            
            // Issue #53 Fix: Improved TTL guard logic
            // Only ignore empty snapshots if we have pending operations AND it's within TTL
            let hasPendingOperations = !pendingProjectTimestamps.isEmpty
            let withinTTL = now.timeIntervalSince(lastLocalChangeAt) < pendingTTL
            
            if remoteList.isEmpty && !projects.isEmpty && hasPendingOperations && withinTTL {
                print("⚠️ ProjectManager: Ignoring empty merged snapshot due to pending operations (TTL protection)")
                print("   Pending operations: \(pendingProjectTimestamps.keys.count)")
                print("   Time since last change: \(String(format: "%.2f", now.timeIntervalSince(lastLocalChangeAt)))s")
                return
            } else if remoteList.isEmpty && !projects.isEmpty {
                print("💥 ProjectManager: Applying empty snapshot - clearing local cache")
                print("   Reason: No pending operations or TTL expired")
                print("   Previous projects: \(projects.count)")
            }
            // 既存とのマージ（ペンディング優先）
            var remoteMap: [String: Project] = [:]
            for p in remoteList { if let id = p.id { remoteMap[id] = p } }
            var merged: [Project] = []
            var seen = Set<String>()
            for cur in projects {
                if let id = cur.id, var r = remoteMap[id] {
                    // Preserve local statistics if remote hasn't populated yet
                    if r.statistics == nil, let curStats = cur.statistics {
                        r.statistics = curStats
                    }
                    merged.append(r); seen.insert(id); remoteMap.removeValue(forKey: id)
                } else if let id = cur.id, let ts = pendingProjectTimestamps[id], now.timeIntervalSince(ts) < pendingTTL {
                    merged.append(cur)
                }
            }
            for (id, r) in remoteMap where !seen.contains(id) { merged.append(r) }
            if merged.isEmpty { merged = remoteList }
            projects = merged
            print("✅ ProjectManager: Merged project list -> count=\(projects.count)")
        }
        
        // 1) 自分がメンバーのプロジェクト
        let idMember = "projects_member_\(userId)"
        let qMember = Firestore.firestore().collection("projects").whereField("memberIds", arrayContains: userId)
        let lidMember = listenerManager.createListener(id: idMember, query: qMember, type: .project, priority: .high) { [weak self] (result: Result<[Project], FirebaseError>) in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                switch result {
                case .success(let list):
                    for p in list { if let id = p.id { map[id] = p } }
                    self.isLoading = false
                    applyMerged()
                case .failure(let err):
                    print("❌ ProjectManager: member-project listener error: \(err)")
                    self.error = err
                }
            }
        }
        activeListenerIds.insert(lidMember)
        
        // 2) 自分が所属するファミリーが所有するプロジェクト
        // ユーザーのfamilyIdsを取得（失敗時は無視）
        Task { @MainActor in
            do {
                let userDoc = try await Firestore.firestore().collection("users").document(userId).getDocument()
                let famIds = (userDoc.data()? ["familyIds"] as? [String]) ?? []
                for fid in famIds {
                    let idFam = "projects_family_\(fid)"
                    let qFam = Firestore.firestore().collection("projects").whereField("ownerId", isEqualTo: fid)
                    let lidFam = listenerManager.createListener(id: idFam, query: qFam, type: .project, priority: .medium) { [weak self] (res: Result<[Project], FirebaseError>) in
                        Task { @MainActor [weak self] in
                            guard let self = self else { return }
                            switch res {
                            case .success(let list):
                                // ownerTypeがfamilyのものだけ採用
                                for p in list where p.ownerType == .family { if let id = p.id { map[id] = p } }
                                self.isLoading = false
                                applyMerged()
                            case .failure(let err):
                                print("❌ ProjectManager: family-project listener error: \(err)")
                                self.error = err
                            }
                        }
                    }
                    self.activeListenerIds.insert(lidFam)
                }
            } catch {
                print("⚠️ ProjectManager: Could not load user's familyIds (permissions?). Proceeding with member-only listener")
            }
        }
    }
    
    func startListeningForProject(id: String) {
        guard !id.isEmpty else {
            print("❌ ProjectManager: Invalid project ID for listener")
            return
        }
        
        let listenerId = "project_detail_\(id)"
        if activeListenerIds.contains(listenerId) {
            print("⚠️ ProjectManager: Project listener already exists for: \(id)")
            return
        }
        
        print("🎧 ProjectManager: Starting optimized project listener: \(id)")
        
        // 🆕 統合されたリスナー管理システムを使用
        let document = Firestore.firestore().collection("projects").document(id)
        let actualListenerId = listenerManager.createDocumentListener(
            id: listenerId,
            document: document,
            type: .project,
            priority: .medium
        ) { [weak self] (result: Result<Project?, FirebaseError>) in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                switch result {
                case .success(let project):
                    print("🔄 ProjectManager: Optimized project listener received update")
                    self.currentProject = project
                case .failure(let error):
                    print("❌ ProjectManager: Optimized project listener error: \(error)")
                    self.error = error
                    self.currentProject = nil
                }
            }
        }
        
        activeListenerIds.insert(actualListenerId)
    }
    
    func removeAllListeners() {
        print("🔄 ProjectManager: Removing \(activeListenerIds.count) optimized listeners")
        
        // 🆕 統合されたリスナー管理システムで削除
        for listenerId in activeListenerIds {
            listenerManager.removeListener(id: listenerId)
        }
        
        activeListenerIds.removeAll()
        currentUserId = nil
        
        print("✅ ProjectManager: All optimized listeners removed")
        
        // デバッグ情報の出力
        listenerManager.logDebugInfo()
    }
    
    // MARK: - Issue #53 Fix: Cache Management
    
    /// Clear local cache when all data is deleted (e.g., test environment cleanup)
    /// This fixes Issue #53 where deleted data reappears after navigation
    func clearLocalCache(reason: String = "manual") {
        print("🗑️ ProjectManager: Clearing local cache - Reason: \(reason)")
        print("   Before clear: \(projects.count) projects, currentProject: \(currentProject?.name ?? "none")")
        
        // Clear all local project data
        projects.removeAll()
        currentProject = nil
        
        // Clear pending timestamps to prevent TTL protection
        pendingProjectTimestamps.removeAll()
        lastLocalChangeAt = .distantPast
        
        // Clear any error state
        error = nil
        
        print("✅ ProjectManager: Local cache cleared successfully")
        print("   After clear: \(projects.count) projects, currentProject: \(currentProject?.name ?? "none")")
    }
    
    /// Invalidate cache and force refresh from remote
    /// This ensures data consistency after external data changes
    func invalidateCacheAndRefresh(userId: String, reason: String = "cache_invalidation") {
        print("💥 ProjectManager: Invalidating cache and refreshing - Reason: \(reason)")
        
        // Clear local cache first
        clearLocalCache(reason: reason)
        
        // Restart listeners to get fresh data from Firestore
        if !userId.isEmpty {
            removeAllListeners() 
            startListeningForUserProjects(userId: userId)
        }
        
        print("🔄 ProjectManager: Cache invalidation and refresh completed")
    }
    
    // 🆕 特定のリスナーのみ削除
    func removeProjectListener() {
        if let userId = currentUserId {
            let listenerId = "projects_\(userId)"
            if activeListenerIds.contains(listenerId) {
                listenerManager.removeListener(id: listenerId)
                activeListenerIds.remove(listenerId)
                print("✅ ProjectManager: Project list listener removed for user: \(userId)")
            }
        }
    }
    
    // 🆕 現在のプロジェクト詳細リスナーのみ削除
    func removeCurrentProjectListener() {
        let listenersToRemove = activeListenerIds.filter { $0.hasPrefix("project_detail_") }
        for listenerId in listenersToRemove {
            listenerManager.removeListener(id: listenerId)
            activeListenerIds.remove(listenerId)
        }
        print("✅ ProjectManager: Project detail listeners removed")
    }
    
    // MARK: - Template Integration
    
    func loadBuiltInTemplates() async {
        isLoadingTemplates = true
        defer { isLoadingTemplates = false }
        
        // Load templates on background queue
        let builtInTemplates = BuiltInTemplates.allTemplates
        
        await MainActor.run {
            self.templates = builtInTemplates
            print("📚 Loaded \(builtInTemplates.count) built-in templates")
        }
    }
    
    func createProjectFromTemplate(_ template: ProjectTemplate, 
                                  projectName: String? = nil,
                                  ownerId: String,
                                  ownerType: ProjectOwnerType = .individual,
                                  createdByUserId: String,
                                  customizations: ProjectCustomizations? = nil) async throws -> Project {
        print("🎯 Creating project from template: '\(template.name)'")
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Import template and create project
            let finalProjectName = projectName ?? template.name
            let project = try await templateImporter.createProject(
                from: template,
                ownerId: ownerId,
                projectName: finalProjectName,
                customizations: customizations
            )
            
            // Create project in Firebase
            var createdProject = try await createProject(
                name: project.name,
                description: project.description,
                ownerId: ownerId,
                ownerType: ownerType,
                createdByUserId: createdByUserId
            )
            
            // Pre-populate statistics immediately from template for faster UI feedback
            let phaseCount = template.phases.count
            let taskCount = template.phases.flatMap { $0.taskLists }.reduce(0) { acc, list in acc + list.tasks.count }
            var statsUpdatedProject = createdProject
            statsUpdatedProject.statistics = ProjectStats(totalTasks: taskCount, completedTasks: 0, totalPhases: phaseCount, activeMembers: 0)
            statsUpdatedProject.lastModifiedAt = Date()
            createdProject = try await updateProject(statsUpdatedProject)
            // Also update local optimistic copy if present
            if let idx = projects.firstIndex(where: { $0.id == createdProject.id }) {
                projects[idx] = createdProject
            }
            
            // Create phases, task lists, and tasks from template
            try await createProjectStructureFromTemplate(
                template: template,
                projectId: createdProject.id ?? "",
                ownerId: ownerId,
                customizations: customizations
            )
            // 🛡️ Post-import stabilization: extend performance monitor grace period to avoid aggressive cleanup
            IntegratedPerformanceMonitor.shared.extendGracePeriod(seconds: 45)
            
            print("🎉 Project created from template successfully!")
            return createdProject
        } catch {
            print("❌ Failed to create project from template: \(error)")
            let firebaseError = FirebaseError.from(error)
            self.error = firebaseError
            throw firebaseError
        }
    }
    
    private func createProjectStructureFromTemplate(
        template: ProjectTemplate,
        projectId: String,
        ownerId: String,
        customizations: ProjectCustomizations? = nil
    ) async throws {
        let phaseManager = PhaseManager()
        _ = TaskListManager() // kept for export path elsewhere
        let taskManager = EnhancedTaskManager()
        let subtaskManager = SubtaskManager()
        var phaseCount = 0
        var listCount = 0
        var taskCount = 0
        var subtaskCount = 0
        
        // Create phases in order
        for phaseTemplate in template.phases.sorted(by: { $0.order < $1.order }) {
            let createdPhase = try await phaseManager.createPhase(
                name: phaseTemplate.title,
                description: phaseTemplate.description,
                projectId: projectId,
                createdBy: ownerId,
                order: phaseTemplate.order
            )
            guard let phaseId = createdPhase.id else { continue }
            phaseCount += 1
            print("🧱 Created phase: \(createdPhase.name) [\(phaseId)]")
            
            // Create sections for this phase and tasks under phase-level collection
            let sectionManager = PhaseSectionManager()
            for taskListTemplate in phaseTemplate.taskLists.sorted(by: { $0.order < $1.order }) {
                let sec = try await sectionManager.createSection(
                    name: taskListTemplate.name,
                    phaseId: phaseId,
                    projectId: projectId,
                    order: taskListTemplate.order,
                    colorHex: (customizations?.customPhaseColors[phaseTemplate.title]?.swiftUIColor.description)
                )
                listCount += 1
                print("📁 Created section: \(sec.name) [\(sec.id ?? "")] in phase \(phaseId)")
                for (taskIndex, taskTemplate) in taskListTemplate.tasks.enumerated() {
                    if taskTemplate.isOptional && (customizations?.skipOptionalTasks == true) { continue }
                    let priority = customizations?.taskPriorityOverrides[taskTemplate.title] ?? taskTemplate.priority
                    let createdTask = try await taskManager.createPhaseTask(
                        title: taskTemplate.title,
                        description: taskTemplate.description,
                        assignedTo: nil,
                        createdBy: ownerId,
                        dueDate: nil,
                        priority: priority,
                        sectionId: sec.id,
                        sectionName: sec.name,
                        phaseId: phaseId,
                        projectId: projectId,
                        order: taskIndex
                    )
                    guard let taskId = createdTask.id else { continue }
                    taskCount += 1
                    print("✅ Created task: \(createdTask.title) [\(taskId)] in section \(sec.id ?? "")")
                    for (subtaskIndex, subtaskTemplate) in taskTemplate.subtasks.enumerated() {
                        let createdSubtask = try await subtaskManager.createSubtask(
                            title: subtaskTemplate.title,
                            description: subtaskTemplate.description,
                            assignedTo: nil,
                            createdBy: ownerId,
                            dueDate: nil,
                            taskId: taskId,
                            listId: "",
                            phaseId: phaseId,
                            projectId: projectId,
                            order: subtaskIndex
                        )
                        subtaskCount += 1
                        print("• Created subtask: \(createdSubtask.title) [\(createdSubtask.id ?? "")] for task \(taskId)")
                    }
                }
            }
        }

        print("📈 Template creation summary → phases: \(phaseCount), lists: \(listCount), tasks: \(taskCount), subtasks: \(subtaskCount)")
        // 更新された統計情報をプロジェクトに保存
        let stats = ProjectStats(
            totalTasks: taskCount,
            completedTasks: 0,
            totalPhases: phaseCount,
            activeMembers: 1
        )
        do {
            try await updateProjectStatistics(projectId: projectId, stats: stats)
            print("🧮 Project statistics updated: phases=\(phaseCount), tasks=\(taskCount)")
        } catch {
            print("⚠️ Failed to update project statistics: \(error)")
        }
    }
    
    func exportProjectAsTemplate(_ project: Project) async throws -> ProjectTemplate {
        print("📤 Exporting project as template: '\(project.name)'")
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Get all project components
            let phaseManager = PhaseManager()
            let taskListManager = TaskListManager()
            _ = EnhancedTaskManager()
            let subtaskManager = SubtaskManager()
            
            guard let projectId = project.id else {
                throw FirebaseError.operationFailed("Project ID is required for export")
            }
            
            let phases = try await phaseManager.getPhases(projectId: projectId)
            var taskLists: [String: [TaskList]] = [:]
            var tasks: [String: [ShigodekiTask]] = [:]
            var subtasks: [String: [Subtask]] = [:]
            
            // Collect all task lists, tasks, and subtasks
            for phase in phases {
                guard let phaseId = phase.id else { continue }
                let phaseLists = try await taskListManager.getTaskLists(phaseId: phaseId, projectId: projectId)
                taskLists[phaseId] = phaseLists
                
                for taskList in phaseLists {
                    guard let taskListId = taskList.id else { continue }
                    // Load tasks for this task list
                    let enhancedTaskManager = EnhancedTaskManager()
                    let listTasks = try await enhancedTaskManager.getTasks(
                        listId: taskListId, 
                        phaseId: phaseId, 
                        projectId: projectId
                    )
                    tasks[taskListId] = listTasks
                    
                    for task in listTasks {
                        guard let taskId = task.id else { continue }
                        let taskSubtasks = try await subtaskManager.getSubtasks(
                            taskId: taskId,
                            listId: taskListId,
                            phaseId: phaseId,
                            projectId: projectId
                        )
                        subtasks[taskId] = taskSubtasks
                    }
                }
            }
            
            // Export to template
            let template = try await templateExporter.exportProject(
                project,
                phases: phases,
                taskLists: taskLists,
                tasks: tasks,
                subtasks: subtasks,
                options: .default
            )
            
            print("✅ Project exported as template successfully!")
            return template
        } catch {
            print("❌ Failed to export project as template: \(error)")
            let firebaseError = FirebaseError.from(error)
            self.error = firebaseError
            throw firebaseError
        }
    }
    
    // MARK: - Owner Change (individual ⇄ family)
    func changeOwner(projectId: String, to ownerType: ProjectOwnerType, ownerId: String, performedBy userId: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            guard var project = try await projectOperations.read(id: projectId) else {
                throw FirebaseError.documentNotFound
            }
            
            project.ownerType = ownerType
            project.ownerId = ownerId
            project.lastModifiedAt = Date()
            
            switch ownerType {
            case .individual:
                // Reduce membership to the owner only (and performedBy if different → editor)
                var newMembers: Set<String> = [ownerId]
                if userId != ownerId { newMembers.insert(userId) }
                project.memberIds = Array(newMembers)
                _ = try await projectOperations.update(project)
                
                // Reset member documents
                let existing = try await getProjectMembers(projectId: projectId)
                for m in existing { try await deleteProjectMember(userId: m.userId, projectId: projectId) }
                // Owner
                try await createProjectMember(ProjectMember(userId: ownerId, projectId: projectId, role: .owner), in: projectId)
                // If different performer, grant editor
                if userId != ownerId {
                    try await createProjectMember(ProjectMember(userId: userId, projectId: projectId, role: .editor), in: projectId)
                }
            case .family:
                // Pull family members
                let familyDoc = try await Firestore.firestore().collection("families").document(ownerId).getDocument()
                let familyMembers = (familyDoc.data()? ["members"] as? [String]) ?? []
                project.memberIds = Array(Set(familyMembers))
                _ = try await projectOperations.update(project)
                
                // Reset member documents and add all
                let existing = try await getProjectMembers(projectId: projectId)
                for m in existing { try await deleteProjectMember(userId: m.userId, projectId: projectId) }
                for uid in familyMembers {
                    let role: Role = (uid == userId) ? .owner : .editor
                    try await createProjectMember(ProjectMember(userId: uid, projectId: projectId, role: role), in: projectId)
                }
            }
            
            // Update local cache
            if let idx = projects.firstIndex(where: { $0.id == projectId }) {
                projects[idx] = project
            }
        } catch {
            throw FirebaseError.from(error)
        }
    }
    
    func importTemplateFromFile(url: URL) async throws -> ProjectTemplate {
        isLoadingTemplates = true
        defer { isLoadingTemplates = false }
        
        do {
            let result = try await templateImporter.importTemplateFromFile(url: url)
            return result.projectTemplate
        } catch {
            let firebaseError = FirebaseError.from(error)
            self.error = firebaseError
            throw firebaseError
        }
    }
    
    // MARK: - Validation Helpers
    
    func validateProjectHierarchy(project: Project) async throws {
        guard let projectId = project.id, !projectId.isEmpty else {
            throw FirebaseError.operationFailed("Project ID is required for hierarchy validation")
        }
        
        let phaseManager = PhaseManager()
        do {
            let phases = try await phaseManager.getPhases(projectId: projectId)
            try ModelRelationships.validateProjectHierarchy(project: project, phases: phases)
        } catch {
            throw FirebaseError.from(error)
        }
    }
}
