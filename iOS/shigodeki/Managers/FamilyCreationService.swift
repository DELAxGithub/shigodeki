import Foundation
import FirebaseFirestore
import FirebaseAuth

class FamilyCreationService {
    private let db = Firestore.firestore()
    
    func createFamilyOnServer(name: String, creatorUserId: String) async throws -> String {
        let familyData: [String: Any] = [
            "name": name,
            "members": [creatorUserId],
            "createdAt": FieldValue.serverTimestamp(),
            "lastUpdatedAt": FieldValue.serverTimestamp(),
            "devEnvironmentTest": "Created in DEV at \(Date().formatted())"
        ]
        
        do {
            let familyRef = try await db.collection("families").addDocument(data: familyData)
            let familyId = familyRef.documentID
            
            // Update user's familyIds array
            try await updateUserFamilyIds(userId: creatorUserId, familyId: familyId, action: .add)
            
            // Create invitation code for this family
            try await generateInvitationCode(familyId: familyId, familyName: name)
            
            print("Family created successfully with ID: \(familyId)")
            return familyId
            
        } catch {
            print("Error creating family: \(error)")
            throw FamilyError.creationFailed(error.localizedDescription)
        }
    }
    
    private func generateInvitationCode(familyId: String, familyName: String) async throws {
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