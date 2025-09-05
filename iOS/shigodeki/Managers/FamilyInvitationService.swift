import Foundation
import FirebaseFirestore
import FirebaseAuth

class FamilyInvitationService {
    private let db = Firestore.firestore()
    
    func generateInvitationCode(familyId: String, familyName: String) async throws {
        let invitationCode = generateRandomCode()
        
        let invitationData: [String: Any] = [
            "familyId": familyId,
            "familyName": familyName,
            "code": invitationCode,
            "isActive": true,
            "createdAt": FieldValue.serverTimestamp(),
            "expiresAt": Timestamp(date: Date().addingTimeInterval(7 * 24 * 60 * 60)) // 7 days
        ]
        
        try await db.collection("invitations").document(invitationCode).setData(invitationData)
        print("Invitation code generated: \(invitationCode)")
    }
    
    func joinFamilyWithCodeOnServer(code: String, familyId: String, familyName: String, userId: String) async throws {
        // Add user to family members
        try await db.collection("families").document(familyId).updateData([
            "members": FieldValue.arrayUnion([userId])
        ])
        
        // Update user's familyIds
        try await updateUserFamilyIds(userId: userId, familyId: familyId, action: .add)
        
        // 🔗 同期: 家族所有の全プロジェクトにプロジェクトメンバーとして追加
        do {
            let projectsSnap = try await db.collection("projects").whereField("ownerId", isEqualTo: familyId).getDocuments()
            let encoder = Firestore.Encoder()
            var displayName: String? = nil
            do {
                let userDoc = try await db.collection("users").document(userId).getDocument()
                if let data = userDoc.data() { displayName = data["name"] as? String }
            } catch {
                // ignore permission issues
            }
            for doc in projectsSnap.documents {
                // Only family-owned projects
                if let ownerType = doc.data()["ownerType"] as? String, ownerType == "family" {
                    // Add to memberIds array
                    try await doc.reference.updateData(["memberIds": FieldValue.arrayUnion([userId])])
                    // Create/merge ProjectMember subdocument
                    let member = ProjectMember(userId: userId, projectId: doc.documentID, role: .editor, invitedBy: userId, displayName: displayName)
                    try await doc.reference.collection("members").document(userId).setData(try encoder.encode(member), merge: true)
                }
            }
        } catch {
            // 同期に失敗してもファミリー参加自体は成功扱いとする
            print("Family join sync warning: \(error)")
        }
    }
    
    func validateInvitationCode(_ code: String) async throws -> (familyId: String, familyName: String) {
        let codeDoc = try await db.collection("invitations").document(code).getDocument()
        
        guard codeDoc.exists, let data = codeDoc.data(),
              let isActive = data["isActive"] as? Bool, isActive,
              let familyId = data["familyId"] as? String,
              let familyName = data["familyName"] as? String else {
            throw FamilyError.invalidInvitationCode
        }
        
        // Check if invitation hasn't expired
        if let expiresAt = data["expiresAt"] as? Timestamp,
           expiresAt.dateValue() < Date() {
            throw FamilyError.expiredInvitationCode
        }
        
        return (familyId: familyId, familyName: familyName)
    }
    
    private func generateRandomCode() -> String {
        let characters = "0123456789"
        return String((0..<6).map { _ in characters.randomElement()! })
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