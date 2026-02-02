//
//  InvitationFlowPageObject.swift
//  shigodeki
//
//  Created by Claude on 2025-09-04.
//  🚨 CTO Requirement: Page Object Model for invitation flow operations
//

import Foundation
import XCTest
import FirebaseFirestore
@testable import shigodeki

/// Page Object for invitation flow operations following Page Object Model pattern
@MainActor
class InvitationFlowPageObject {
    
    private let unifiedManager: UnifiedInvitationManager
    private let testDataManager: TestDataManager
    
    init(unifiedManager: UnifiedInvitationManager, testDataManager: TestDataManager) {
        self.unifiedManager = unifiedManager
        self.testDataManager = testDataManager
    }
    
    // MARK: - Family Invitation Operations
    
    func createFamilyInvitation(familyId: String, inviterId: String, role: InvitationRole = .editor) async throws -> Invitation {
        return try await unifiedManager.createInvitation(
            targetId: familyId,
            role: role,
            invitedBy: inviterId
        )
    }
    
    func acceptFamilyInvitation(code: String, userId: String) async throws -> InvitationAcceptanceResult {
        return try await unifiedManager.acceptInvitation(code: code, userId: userId)
    }
    
    // MARK: - Project Invitation Operations
    
    func createProjectInvitation(projectId: String, inviterId: String, role: InvitationRole = .viewer) async throws -> Invitation {
        return try await unifiedManager.createInvitation(
            targetId: projectId,
            role: role,
            invitedBy: inviterId
        )
    }
    
    func acceptProjectInvitation(code: String, userId: String) async throws -> InvitationAcceptanceResult {
        return try await unifiedManager.acceptInvitation(code: code, userId: userId)
    }
    
    // MARK: - Validation Operations
    
    func validateInvitation(code: String) async throws -> Bool {
        return try await unifiedManager.validateInvitation(code: code)
    }
    
    // MARK: - Assertion Helpers
    
    func assertFamilyInvitationCreated(_ invitation: Invitation, familyId: String, inviterId: String, role: InvitationRole) {
        XCTAssertEqual(invitation.type, .family, "Invitation type should be family")
        XCTAssertEqual(invitation.targetId, familyId, "Target ID should match family ID")
        XCTAssertEqual(invitation.invitedBy, inviterId, "Inviter ID should match")
        XCTAssertEqual(invitation.role, role, "Role should match")
        XCTAssertTrue(invitation.isValid, "Invitation should be valid")
        XCTAssertFalse(invitation.code.isEmpty, "Invitation code should not be empty")
    }
    
    func assertProjectInvitationCreated(_ invitation: Invitation, projectId: String, inviterId: String, role: InvitationRole, projectName: String = "Test Project") {
        XCTAssertEqual(invitation.type, .project, "Invitation type should be project")
        XCTAssertEqual(invitation.targetId, projectId, "Target ID should match project ID")
        XCTAssertEqual(invitation.invitedBy, inviterId, "Inviter ID should match")
        XCTAssertEqual(invitation.role, role, "Role should match")
        XCTAssertEqual(invitation.targetName, projectName, "Target name should match")
    }
    
    func assertFamilyInvitationAccepted(_ result: InvitationAcceptanceResult, familyId: String, familyName: String, invitationCode: String) {
        XCTAssertTrue(result.success, "Invitation acceptance should succeed")
        XCTAssertNotNil(result.message, "Success message should be provided")
        XCTAssertEqual(result.invitation.code, invitationCode, "Invitation codes should match")
        
        if case .family(let family) = result.targetEntity {
            XCTAssertEqual(family.id, familyId, "Family ID should match")
            XCTAssertEqual(family.name, familyName, "Family name should match")
        } else {
            XCTFail("Target entity should be a family")
        }
    }
    
    func assertProjectInvitationAccepted(_ result: InvitationAcceptanceResult, projectId: String, projectName: String) {
        XCTAssertTrue(result.success, "Project invitation acceptance should succeed")
        
        if case .project(let project) = result.targetEntity {
            XCTAssertEqual(project.id, projectId, "Project ID should match")
            XCTAssertEqual(project.name, projectName, "Project name should match")
        } else {
            XCTFail("Target entity should be a project")
        }
    }
    
    func assertInvitationUsed(_ invitation: Invitation, userId: String, db: Firestore) async throws {
        let invitationDoc = try await db.collection("invitations").document(invitation.code).getDocument()
        let updatedInvitation = try invitationDoc.data(as: Invitation.self)
        XCTAssertFalse(updatedInvitation.isValid, "Invitation should be invalid after use")
        XCTAssertNotNil(updatedInvitation.usedBy, "UsedBy should be set")
        XCTAssertEqual(updatedInvitation.usedBy, userId, "UsedBy should match invitee ID")
    }
    
    func assertInvitationExistsInFirestore(_ invitation: Invitation, db: Firestore) async throws {
        let doc = try await db.collection("invitations").document(invitation.code).getDocument()
        XCTAssertTrue(doc.exists, "Invitation document should exist in Firestore")
    }
}