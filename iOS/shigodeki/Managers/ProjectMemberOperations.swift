//
//  ProjectMemberOperations.swift
//  shigodeki
//
//  Extracted from ProjectManager.swift for better code organization
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

/// Handles all project member-related operations
@MainActor
class ProjectMemberOperations: ObservableObject {
    @Published var isLoading = false
    @Published var error: FirebaseError?
    
    private let projectOperations = FirebaseOperationBase<Project>(collectionPath: "projects")
    
    // MARK: - Project Member Operations
    
    func createProjectMember(_ member: ProjectMember, in projectId: String) async throws {
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
    
    func deleteProjectMember(userId: String, projectId: String) async throws {
        let memberDoc = Firestore.firestore().collection("projects").document(projectId).collection("members").document(userId)
        try await memberDoc.delete()
    }
    
    // MARK: - Owner Change Operations
    
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
        } catch {
            throw FirebaseError.from(error)
        }
    }
    
    // MARK: - Helper Methods
    
    private func updateProject(_ project: Project) async throws -> Project {
        try project.validate()
        return try await projectOperations.update(project)
    }
}