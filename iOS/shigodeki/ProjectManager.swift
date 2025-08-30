//
//  ProjectManager.swift
//  shigodeki
//
//  Created by Claude on 2025-08-28.
//

import Foundation
import FirebaseFirestore
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
    
    deinit {
        // 🆕 中央集中化されたリスナー管理で削除
        Task { @MainActor [weak self] in
            self?.removeAllListeners()
        }
    }
    
    // MARK: - Project CRUD Operations
    
    func createProject(name: String, description: String? = nil, ownerId: String) async throws -> Project {
        print("🚀 Starting project creation - Name: '\(name)', Owner: '\(ownerId)'")
        isLoading = true
        defer { isLoading = false }
        
        do {
            print("📝 Creating project object...")
            let project = Project(name: name, description: description, ownerId: ownerId)
            print("📝 Project object created: \(project)")
            
            print("✅ Validating project...")
            try project.validate()
            print("✅ Project validation passed")
            
            // 🚀 Optimistic UI Update: Add to local list immediately
            print("⚡ Adding project optimistically to UI")
            projects.append(project)
            
            print("🔄 Creating project in Firestore...")
            let createdProject = try await projectOperations.create(project)
            print("🎉 Project created successfully with ID: \(createdProject.id ?? "NO_ID")")
            
            // Update the local project with the real ID from Firestore
            if let index = projects.firstIndex(where: { $0.name == project.name && $0.ownerId == ownerId }) {
                projects[index] = createdProject
            }
            
            // Create initial project member entry for the owner
            print("👤 Creating owner member entry...")
            let ownerMember = ProjectMember(userId: ownerId, projectId: createdProject.id ?? "", role: .owner)
            try await createProjectMember(ownerMember, in: createdProject.id ?? "")
            print("👤 Owner member created successfully")
            
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
            let member = ProjectMember(userId: userId, projectId: projectId, role: role, invitedBy: invitedBy)
            try member.validate()
            
            try await createProjectMember(member, in: projectId)
            
            // Update project memberIds
            if var project = try await projectOperations.read(id: projectId) {
                if !project.memberIds.contains(userId) {
                    project.memberIds.append(userId)
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
        
        // 重複リスナーの防止
        let listenerId = "projects_\(userId)"
        if activeListenerIds.contains(listenerId) {
            print("⚠️ ProjectManager: Listener already exists for user: \(userId)")
            return
        }
        
        print("🎧 ProjectManager: Starting optimized listener for user: \(userId)")
        currentUserId = userId
        
        // 🆕 統合されたリスナー管理システムを使用
        let actualListenerId = listenerManager.createProjectListener(userId: userId) { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                switch result {
                case .success(let projects):
                    print("🔄 ProjectManager: Optimized listener received \(projects.count) projects")
                    print("📊 ProjectManager: Before update - self.projects.count: \(self.projects.count)")
                    self.isLoading = false // 🔧 リスナー成功時にローディング終了
                    self.projects = projects
                    print("✅ ProjectManager: After update - self.projects.count: \(self.projects.count)")
                    print("📋 ProjectManager: Updated projects: \(self.projects.map { $0.name })")
                case .failure(let error):
                    print("❌ ProjectManager: Optimized listener error: \(error)")
                    self.isLoading = false // 🔧 エラー時もローディング終了
                    self.error = error
                }
            }
        }
        
        activeListenerIds.insert(actualListenerId)
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
            let createdProject = try await createProject(
                name: project.name,
                description: project.description,
                ownerId: ownerId
            )
            
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
        let taskListManager = TaskListManager()
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
            
            // Create task lists for this phase
            for taskListTemplate in phaseTemplate.taskLists.sorted(by: { $0.order < $1.order }) {
                let createdTaskList = try await taskListManager.createTaskList(
                    name: taskListTemplate.name,
                    phaseId: phaseId,
                    projectId: projectId,
                    createdBy: ownerId,
                    color: customizations?.customPhaseColors[phaseTemplate.title] ?? taskListTemplate.color,
                    order: taskListTemplate.order
                )
                guard let taskListId = createdTaskList.id else { continue }
                listCount += 1
                print("📦 Created list: \(createdTaskList.name) [\(taskListId)] in phase \(phaseId)")
                
                // Create tasks for this task list
                for (taskIndex, taskTemplate) in taskListTemplate.tasks.enumerated() {
                    // Skip optional tasks if customizations specify to do so
                    if taskTemplate.isOptional && (customizations?.skipOptionalTasks == true) {
                        continue
                    }
                    
                    // Apply priority overrides if specified
                    let priority = customizations?.taskPriorityOverrides[taskTemplate.title] ?? taskTemplate.priority
                    
                    let createdTask = try await taskManager.createTask(
                        title: taskTemplate.title,
                        description: taskTemplate.description,
                        assignedTo: nil,
                        createdBy: ownerId,
                        dueDate: nil,
                        priority: priority,
                        listId: taskListId,
                        phaseId: phaseId,
                        projectId: projectId,
                        order: taskIndex
                    )
                    guard let taskId = createdTask.id else { continue }
                    taskCount += 1
                    print("✅ Created task: \(createdTask.title) [\(taskId)] in list \(taskListId)")
                    
                    // Create subtasks if present
                    for (subtaskIndex, subtaskTemplate) in taskTemplate.subtasks.enumerated() {
                        let createdSubtask = try await subtaskManager.createSubtask(
                            title: subtaskTemplate.title,
                            description: subtaskTemplate.description,
                            assignedTo: nil,
                            createdBy: ownerId,
                            dueDate: nil,
                            taskId: taskId,
                            listId: taskListId,
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
                    // Load tasks for this task list (assuming this is for export, we may need to adjust)
                    let listTasks: [ShigodekiTask] = [] // TODO: Implement proper task loading for export
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
