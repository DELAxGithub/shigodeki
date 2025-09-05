//
//  ProjectManager.swift
//  shigodeki
//
//  Refactored to follow CLAUDE.md principles: Single Responsibility & <300 lines
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
    
    // 🆕 Composition over inheritance: delegate to specialized managers
    private let memberOperations = ProjectMemberOperations()
    private let templateOperations = ProjectTemplateOperations()
    private let listenerManager = ProjectListenerManager()
    private let validationHelpers = ProjectValidationHelpers()
    
    // Pending create/update guard to avoid race where listener briefly reports 0 and clears UI
    private var pendingProjectTimestamps: [String: Date] = [:]
    private var lastLocalChangeAt: Date = .distantPast
    private let pendingTTL: TimeInterval = 5.0
    
    deinit {
        Task { @MainActor [weak self] in
            self?.removeAllListeners()
        }
    }
    
    // MARK: - Project CRUD Operations
    
    func createProject(name: String, description: String? = nil, ownerId: String, ownerType: ProjectOwnerType = .individual, createdByUserId: String) async throws -> Project {
        print("🚀 Starting project creation - Name: '\(name)', Owner: '\(ownerId)'")
        isLoading = true
        defer { isLoading = false }
        
        let (optimisticProject, temporaryId) = ProjectCreationHelpers.createOptimisticProject(
            name: name, description: description, ownerId: ownerId, ownerType: ownerType
        )
        
        do {
            try optimisticProject.validate()
            print("⚡ Adding project optimistically to UI")
            projects.insert(optimisticProject, at: 0)
            
            try await ProjectCreationHelpers.debugFirebaseAuthState()
            
            print("🔄 Creating project in Firestore...")
            var createdProject = try await projectOperations.create(optimisticProject)
            print("🎉 Project created successfully with ID: \(createdProject.id ?? "NO_ID")")
            
            ProjectCreationHelpers.replaceOptimisticProject(in: &projects, temporaryId: temporaryId, with: createdProject)
            
            if ownerType == .individual {
                let displayName = AuthenticationManager.shared.currentUser?.name
                let ownerMember = ProjectMember(userId: ownerId, projectId: createdProject.id ?? "", role: .owner, invitedBy: createdByUserId, displayName: displayName)
                try await memberOperations.createProjectMember(ownerMember, in: createdProject.id ?? "")
            } else {
                let familyDoc = try await Firestore.firestore().collection("families").document(ownerId).getDocument()
                let familyMembers = (familyDoc.data()? ["members"] as? [String]) ?? []
                var updated = createdProject
                updated.memberIds = Array(Set(familyMembers))
                _ = try await updateProject(updated)
                for uid in familyMembers {
                    let role: Role = (uid == createdByUserId) ? .owner : .editor
                    let dn = (uid == createdByUserId) ? AuthenticationManager.shared.currentUser?.name : nil
                    let member = ProjectMember(userId: uid, projectId: createdProject.id ?? "", role: role, invitedBy: createdByUserId, displayName: dn)
                    try await memberOperations.createProjectMember(member, in: createdProject.id ?? "")
                }
            }
            
            print("✨ Project creation completed successfully!")
            return createdProject
        } catch {
            print("❌ Project creation failed: \(error)")
            
            // 🔄 Rollback: Remove optimistically added project on error
            ProjectCreationHelpers.rollbackOptimisticProject(from: &projects, temporaryId: temporaryId)
            
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
                try await memberOperations.deleteProjectMember(userId: member.userId, projectId: id)
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
            let foundProjects = try await projectOperations.list(where: "memberIds", arrayContains: userId)
            print("📊 Found \(foundProjects.count) projects for user")
            
            // 🔥 CRITICAL FIX: Update the @Published projects array
            await MainActor.run {
                self.projects = foundProjects
                print("🔄 Updated ProjectManager.projects array with \(foundProjects.count) projects")
            }
            
            return foundProjects
        } catch {
            print("❌ Failed to load user projects: \(error)")
            let firebaseError = FirebaseError.from(error)
            self.error = firebaseError
            throw firebaseError
        }
    }
    
    // MARK: - Project Member Operations (Delegated)
    
    func addMember(userId: String, to projectId: String, with role: Role, invitedBy: String) async throws -> ProjectMember {
        // Mark pending to protect UI from transient empty snapshots
        pendingProjectTimestamps[projectId] = Date(); lastLocalChangeAt = Date()
        return try await memberOperations.addMember(userId: userId, to: projectId, with: role, invitedBy: invitedBy)
    }
    
    func getProjectMembers(projectId: String) async throws -> [ProjectMember] {
        return try await memberOperations.getProjectMembers(projectId: projectId)
    }
    
    func updateMemberRole(userId: String, projectId: String, newRole: Role) async throws {
        try await memberOperations.updateMemberRole(userId: userId, projectId: projectId, newRole: newRole)
    }
    
    func removeMember(userId: String, from projectId: String) async throws {
        // Mark pending to protect UI from transient empty snapshots
        pendingProjectTimestamps[projectId] = Date(); lastLocalChangeAt = Date()
        try await memberOperations.removeMember(userId: userId, from: projectId)
    }
    
    func changeOwner(projectId: String, to ownerType: ProjectOwnerType, ownerId: String, performedBy userId: String) async throws {
        try await memberOperations.changeOwner(projectId: projectId, to: ownerType, ownerId: ownerId, performedBy: userId)
        // Update local cache
        if let updatedProject = try? await getProject(id: projectId),
           let idx = projects.firstIndex(where: { $0.id == projectId }) {
            projects[idx] = updatedProject
        }
    }
    
    // MARK: - Statistics Updates (Delegated)
    
    func updateProjectStatistics(projectId: String, stats: ProjectStats) async throws {
        try await validationHelpers.updateProjectStatistics(projectId: projectId, stats: stats)
    }
    
    // MARK: - Real-time Listeners (Delegated)
    
    func startListeningForUserProjects(userId: String) {
        listenerManager.startListeningForUserProjects(userId: userId) { [weak self] updatedProjects in
            self?.projects = updatedProjects
        }
    }
    
    func startListeningForProject(id: String) {
        listenerManager.startListeningForProject(id: id) { [weak self] project in
            self?.currentProject = project
        }
    }
    
    func removeAllListeners() {
        listenerManager.removeAllListeners()
    }
    
    func removeProjectListener() {
        listenerManager.removeProjectListener()
    }
    
    func removeCurrentProjectListener() {
        listenerManager.removeCurrentProjectListener()
    }
    
    // MARK: - Template Integration (Delegated)
    
    func loadBuiltInTemplates() async {
        await templateOperations.loadBuiltInTemplates()
        templates = templateOperations.templates
        isLoadingTemplates = templateOperations.isLoadingTemplates
    }
    
    func createProjectFromTemplate(_ template: ProjectTemplate, 
                                  projectName: String? = nil,
                                  ownerId: String,
                                  ownerType: ProjectOwnerType = .individual,
                                  createdByUserId: String,
                                  customizations: ProjectCustomizations? = nil) async throws -> Project {
        return try await templateOperations.createProjectFromTemplate(
            template,
            projectName: projectName,
            ownerId: ownerId,
            ownerType: ownerType,
            createdByUserId: createdByUserId,
            customizations: customizations
        ) { project in
            // Create project in Firebase via callback
            return try await self.createProject(
                name: project.name,
                description: project.description,
                ownerId: ownerId,
                ownerType: ownerType,
                createdByUserId: createdByUserId
            )
        }
    }
    
    func exportProjectAsTemplate(_ project: Project) async throws -> ProjectTemplate {
        return try await templateOperations.exportProjectAsTemplate(project)
    }
    
    func importTemplateFromFile(url: URL) async throws -> ProjectTemplate {
        return try await templateOperations.importTemplateFromFile(url: url)
    }
    
    
    // MARK: - Synchronization Helpers (Delegated)
    
    private func waitForDataSynchronization(projectId: String) async throws {
        try await validationHelpers.waitForDataSynchronization(projectId: projectId, currentProjects: projects)
    }
    
    // MARK: - Validation Helpers (Delegated)
    
    func validateProjectHierarchy(project: Project) async throws {
        try await validationHelpers.validateProjectHierarchy(project: project)
    }
}
