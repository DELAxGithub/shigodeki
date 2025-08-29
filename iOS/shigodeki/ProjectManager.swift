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
    
    private let projectOperations = FirebaseOperationBase<Project>(collectionPath: "projects")
    private let memberOperations = FirebaseOperationBase<ProjectMember>(collectionPath: "projects")
    private var listeners: [ListenerRegistration] = []
    private var activeUserIds: Set<String> = []
    
    deinit {
        // Clean up listeners - called from deinit, can't be async
        listeners.forEach { $0.remove() }
        listeners.removeAll()
    }
    
    // MARK: - Project CRUD Operations
    
    func createProject(name: String, description: String? = nil, ownerId: String) async throws -> Project {
        print("🚀 Starting project creation - Name: '\(name)', Owner: '\(ownerId)'")
        isLoading = true
        defer { isLoading = false }
        
        do {
            print("📝 Creating project object...")
            var project = Project(name: name, description: description, ownerId: ownerId)
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
    
    // MARK: - Real-time Listeners
    
    func startListeningForUserProjects(userId: String) async {
        guard !userId.isEmpty else {
            print("❌ ProjectManager: Invalid userId for listener")
            return
        }
        
        // Prevent duplicate listeners for same user
        if activeUserIds.contains(userId) {
            print("⚠️ ProjectManager: Listener already exists for user: \(userId)")
            return
        }
        
        print("🎧 ProjectManager: Starting listener for user: \(userId)")
        activeUserIds.insert(userId)
        let listener = await projectOperations.listen(where: "memberIds", isEqualTo: userId) { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                
                switch result {
                case .success(let projects):
                    print("🔄 ProjectManager: Listener received \(projects.count) projects")
                    self.projects = projects
                case .failure(let error):
                    print("❌ ProjectManager: Listener error: \(error)")
                    let firebaseError = FirebaseError.from(error)
                    self.error = firebaseError
                }
            }
        }
        listeners.append(listener)
    }
    
    func startListeningForProject(id: String) {
        guard !id.isEmpty else {
            print("❌ ProjectManager: Invalid project ID for listener")
            return
        }
        
        print("🎧 ProjectManager: Starting listener for project: \(id)")
        let projectCollection = Firestore.firestore().collection("projects")
        let listener = projectCollection.document(id).addSnapshotListener { [weak self] snapshot, error in
            Task { @MainActor in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ ProjectManager: Project listener error: \(error)")
                    self.error = FirebaseError.from(error)
                    return
                }
                
                guard let document = snapshot, document.exists else {
                    print("📎 ProjectManager: Project document does not exist")
                    self.currentProject = nil
                    return
                }
                
                do {
                    let project = try document.data(as: Project.self)
                    self.currentProject = project
                } catch {
                    self.error = FirebaseError.from(error)
                }
            }
        }
        listeners.append(listener)
    }
    
    func removeAllListeners() {
        print("🔄 ProjectManager: Removing \(listeners.count) listeners")
        listeners.forEach { listener in
            listener.remove()
        }
        listeners.removeAll()
        activeUserIds.removeAll()
        print("✅ ProjectManager: All listeners removed")
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