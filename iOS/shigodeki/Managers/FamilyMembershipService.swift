import Foundation
import FirebaseFirestore
import FirebaseAuth

class FamilyMembershipService {
    private let db = Firestore.firestore()
    
    func removeMemberFromFamilyOnServer(familyId: String, userId: String) async throws {
        // Remove user from family members
        try await db.collection("families").document(familyId).updateData([
            "members": FieldValue.arrayRemove([userId])
        ])
        
        // Update user's familyIds
        try await updateUserFamilyIds(userId: userId, familyId: familyId, action: .remove)
    }
    
    func deleteFamilyFromServer(familyId: String) async throws {
        // 最後のメンバーが退出時は家族自体を削除
        try await db.collection("families").document(familyId).delete()
        print("🗑️ Family deleted from server: \(familyId)")
    }
    
    enum FamilyIdAction {
        case add, remove
    }
    
    func updateUserFamilyIds(userId: String, familyId: String, action: FamilyIdAction) async throws {
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
