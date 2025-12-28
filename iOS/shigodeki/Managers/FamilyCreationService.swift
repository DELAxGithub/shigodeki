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
        // 統一招待システムを使用（3重保存廃止）
        let unifiedService = UnifiedInvitationService()
        let code = try await unifiedService.createInvitation(targetId: familyId, type: .family)
        
        // families/{id}.latestInviteCode に正規化コード保存（冪等）
        let normalizedCode = try InvitationCodeNormalizer.normalize(code)
        try await db.collection("families").document(familyId).updateData([
            "latestInviteCode": normalizedCode
        ])
        
        let displayCode = "\(InviteCodeSpec.displayPrefix)\(normalizedCode)"
        print("📝 [FamilyCreationService] Unified invitation: \(displayCode) familyId=\(familyId)")
        
        return displayCode
    }
    
    
    private func updateUserFamilyIds(userId: String, familyId: String, action: FamilyMembershipService.FamilyIdAction) async throws {
        let userRef = db.collection("users").document(userId)
        
        switch action {
        case .add:
            _ = try await db.runTransaction { transaction, errorPointer in
                do {
                    let userDoc = try transaction.getDocument(userRef)
                    var familyIds = (userDoc.data()?["familyIds"] as? [String]) ?? []
                    if familyIds.contains(familyId) {
                        return nil
                    }
                    familyIds.append(familyId)
                    transaction.updateData(["familyIds": familyIds], forDocument: userRef)
                    return nil
                } catch {
                    errorPointer?.pointee = error as NSError
                    return nil
                }
            }
        case .remove:
            try await userRef.updateData([
                "familyIds": FieldValue.arrayRemove([familyId])
            ])
        }
    }
}
