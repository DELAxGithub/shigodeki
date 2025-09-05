//
//  ProjectInvitationManager.swift
//  shigodeki
//
//  Created by Codex on 2025-08-30.
//

import Foundation
import FirebaseFirestore

@MainActor
class ProjectInvitationManager: ObservableObject {
    @Published var isLoading = false
    @Published var error: FirebaseError?
    
    private let db = Firestore.firestore()
    private let encoder = Firestore.Encoder()
    private let decoder = Firestore.Decoder()
    
    func createInvitation(for project: Project, role: Role, invitedByUserId: String, invitedByName: String) async throws -> ProjectInvitation {
        isLoading = true
        defer { isLoading = false }
        do {
            let code = generateCode()
            var invitation = ProjectInvitation(
                inviteCode: code,
                projectId: project.id ?? "",
                projectName: project.name,
                invitedBy: invitedByUserId,
                invitedByName: invitedByName,
                role: role
            )
            invitation.createdAt = Date()
            try await db.collection("projectInvitations").document(code).setData(try encoder.encode(invitation))
            return invitation
        } catch {
            let fe = FirebaseError.from(error)
            self.error = fe
            throw fe
        }
    }
    
    func acceptInvitation(code: String, userId: String, displayName: String?) async throws -> Project {
        isLoading = true
        defer { isLoading = false }
        do {
            let doc = try await db.collection("projectInvitations").document(code).getDocument()
            guard let data = doc.data() else { throw FirebaseError.documentNotFound }
            let invitation = try decoder.decode(ProjectInvitation.self, from: data)
            guard invitation.isValid else { throw FirebaseError.operationFailed("招待は無効です") }
            // Add member to project
            let projectRef = db.collection("projects").document(invitation.projectId)
            // Update project memberIds
            try await projectRef.updateData(["memberIds": FieldValue.arrayUnion([userId])])
            // Create member document with displayName
            let member = ProjectMember(userId: userId, projectId: invitation.projectId, role: invitation.role, invitedBy: invitation.invitedBy, displayName: displayName)
            try await projectRef.collection("members").document(userId).setData(try encoder.encode(member), merge: true)
            // Mark invitation used
            try await db.collection("projectInvitations").document(code).updateData([
                "isActive": false,
                "usedAt": Date(),
                "usedBy": userId
            ])
            // Return project for convenience
            let project: Project = try await db.collection("projects").document(invitation.projectId)
                .getDocument()
                .data(as: Project.self, decoder: decoder)
            return project
        } catch {
            let fe = FirebaseError.from(error)
            self.error = fe
            throw fe
        }
    }
    
    private func generateCode() -> String {
        let chars = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<6).map { _ in chars.randomElement()! })
    }
}
