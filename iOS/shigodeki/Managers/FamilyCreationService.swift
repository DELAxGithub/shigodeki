import Foundation
import FirebaseFirestore
import FirebaseAuth

class FamilyCreationService {
    private let db = Firestore.firestore()
    
    func createFamilyOnServer(name: String, creatorUserId: String) async throws -> (familyId: String, inviteCode: String?) {
        let familyData: [String: Any] = [
            "name": name,
            "members": [creatorUserId],
            "createdAt": FieldValue.serverTimestamp(),
            "lastUpdatedAt": FieldValue.serverTimestamp(),
            "devEnvironmentTest": "Created in DEV at \(Date().formatted())"
        ]
        
        do {
            // Step 1: Create family (critical path - must not fail)
            let familyRef = try await db.collection("families").addDocument(data: familyData)
            let familyId = familyRef.documentID
            
            // Step 2: Update user's familyIds array (critical path)
            try await updateUserFamilyIds(userId: creatorUserId, familyId: familyId, action: .add)
            
            print("✅ Family created successfully with ID: \(familyId)")
            
            // Step 3: Create invitation code (separate try/catch - failure won't rollback family)
            var generatedInviteCode: String? = nil
            do {
                generatedInviteCode = try await generateInvitationCode(familyId: familyId, familyName: name)
                print("✅ Invitation code generated for family: \(familyId) -> \(generatedInviteCode ?? "nil")")
            } catch {
                print("⚠️ [FamilyCreationService] InviteIssue failure for family \(familyId): \(error)")
                print("   Family creation succeeded, invitation can be generated later")
                // Don't throw - family creation should succeed even if invitation fails
            }
            
            return (familyId: familyId, inviteCode: generatedInviteCode)
            
        } catch {
            print("❌ Error creating family: \(error)")
            throw FamilyError.creationFailed(error.localizedDescription)
        }
    }
    
    private func generateInvitationCode(familyId: String, familyName: String) async throws -> String {
        let normalizedCode = generateRandomCode()
        let displayCode = "\(InviteCodeSpec.displayPrefix)\(normalizedCode)"
        
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw FamilyError.userNotAuthenticated
        }
        
        let invitationData: [String: Any] = [
            "familyId": familyId,
            "familyName": familyName,
            "code": displayCode,
            "normalizedCode": normalizedCode,
            "isActive": true,
            "createdBy": currentUserId,
            "createdAt": FieldValue.serverTimestamp(),
            "expiresAt": Timestamp(date: Date().addingTimeInterval(7 * 24 * 60 * 60)), // 7 days
            "remainingUses": 50,
            "maxUses": 50
        ]
        
        // Triple-save strategy for maximum compatibility and reliability
        // 1. Primary save by normalized code
        try await db.collection("invites_by_norm").document(normalizedCode).setData(invitationData)
        
        // 2. Mirror save by display format for compatibility  
        try await db.collection("invitations").document(displayCode).setData(invitationData)
        
        // 3. Family-scoped save for reliable family member access
        try await db.collection("families").document(familyId)
            .collection("invites").document(normalizedCode).setData(invitationData)
        
        print("📝 [FamilyCreationService] InviteIssue normalized=\(normalizedCode) shown=\(displayCode) familyId=\(familyId)")
        
        return displayCode
    }
    
    private func generateRandomCode() -> String {
        return String((0..<InviteCodeSpec.codeLength).map { _ in 
            InviteCodeSpec.safeCharacters.randomElement()! 
        })
    }
    
    private func updateUserFamilyIds(userId: String, familyId: String, action: FamilyMembershipService.FamilyIdAction) async throws {
        let userRef = db.collection("users").document(userId)
        
        switch action {
        case .add:
            try await userRef.updateData([
                "familyIds": FieldValue.arrayUnion([familyId])
            ])
        case .remove:
            try await userRef.updateData([
                "familyIds": FieldValue.arrayRemove([familyId])
            ])
        }
    }
}