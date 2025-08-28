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
    
    deinit {
        Task { @MainActor in
            removeAllListeners()
        }
    }
    
    // MARK: - Project CRUD Operations
    
    func createProject(name: String, description: String? = nil, ownerId: String) async throws -> Project {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let project = Project(name: name, description: description, ownerId: ownerId)
            try project.validate()
            
            let createdProject = try await projectOperations.create(project)
            
            // Create initial project member entry for the owner
            let ownerMember = ProjectMember(userId: ownerId, projectId: createdProject.id ?? "", role: .owner)
            try await createProjectMember(ownerMember, in: createdProject.id ?? "")
            
            return createdProject
        } catch {
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
        isLoading = true
        defer { isLoading = false }
        
        do {
            return try await projectOperations.list(where: "memberIds", isEqualTo: userId)
        } catch {
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
        let listener = await projectOperations.listen(where: "memberIds", isEqualTo: userId) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let projects):
                    self?.projects = projects
                case .failure(let error):
                    self?.error = error
                }
            }
        }
        listeners.append(listener)
    }
    
    func startListeningForProject(id: String) {
        let projectCollection = Firestore.firestore().collection("projects")
        let listener = projectCollection.document(id).addSnapshotListener { [weak self] snapshot, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.error = FirebaseError.from(error)
                    return
                }
                
                guard let document = snapshot, document.exists else {
                    self?.currentProject = nil
                    return
                }
                
                do {
                    let project = try document.data(as: Project.self)
                    self?.currentProject = project
                } catch {
                    self?.error = FirebaseError.from(error)
                }
            }
        }
        listeners.append(listener)
    }
    
    func removeAllListeners() {
        listeners.forEach { $0.remove() }
        listeners.removeAll()
    }
    
    // MARK: - Validation Helpers
    
    func validateProjectHierarchy(project: Project) async throws {
        let phaseManager = PhaseManager()
        let phases = try await phaseManager.getPhases(projectId: project.id ?? "")
        try ModelRelationships.validateProjectHierarchy(project: project, phases: phases)
    }
}