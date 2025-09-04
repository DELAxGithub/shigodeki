//
//  FirestoreFamilyRepository.swift
//  shigodeki
//
//  Created for CTO DI Architecture Implementation
//  Firestore concrete implementation of FamilyRepository protocol
//

import Foundation
import Combine
import FirebaseFirestore
import FirebaseAuth

/// Firestore implementation of FamilyRepository
/// Uses addSnapshotListener for real-time updates as per CTO requirement
class FirestoreFamilyRepository: FamilyRepository {
    
    private let db = Firestore.firestore()
    private var userFamilyIdsListener: ListenerRegistration?
    private var familyListeners: [String: ListenerRegistration] = [:]
    
    // Real-time data stream using Combine
    private let familiesSubject = CurrentValueSubject<[Family], Error>([])
    
    // MARK: - FamilyRepository Protocol Implementation
    
    /// CTO REQUIREMENT: Real-time family data stream using addSnapshotListener + AnyPublisher
    func familiesPublisher(for userId: String) -> AnyPublisher<[Family], Error> {
        startListeningToUserFamilies(userId: userId)
        return familiesSubject.eraseToAnyPublisher()
    }
    
    func createFamily(name: String, creatorUserId: String) async throws -> String {
        let familyData: [String: Any] = [
            "name": name,
            "members": [creatorUserId],
            "createdAt": FieldValue.serverTimestamp(),
            "lastUpdatedAt": FieldValue.serverTimestamp(),
            "devEnvironmentTest": "Created via Repository at \(Date().formatted())"
        ]
        
        do {
            let familyRef = try await db.collection("families").addDocument(data: familyData)
            let familyId = familyRef.documentID
            
            // Update user's familyIds array - this triggers the listener to pick up the new family
            try await updateUserFamilyIds(userId: creatorUserId, familyId: familyId, action: .add)
            
            print("✅ FirestoreFamilyRepository: Family created successfully with ID: \(familyId)")
            return familyId
            
        } catch {
            print("❌ FirestoreFamilyRepository: Error creating family: \(error)")
            throw FamilyError.creationFailed(error.localizedDescription)
        }
    }
    
    func joinFamily(userId: String, invitationCode: String) async throws -> JoinResult {
        do {
            // Validate invitation code first
            let codeDoc = try await db.collection("invitations").document(invitationCode).getDocument()
            
            guard codeDoc.exists, let data = codeDoc.data(),
                  let isActive = data["isActive"] as? Bool, isActive,
                  let familyId = data["familyId"] as? String,
                  let familyName = data["familyName"] as? String else {
                throw FirebaseError.operationFailed("Invalid invitation code")
            }
            
            // Check if invitation hasn't expired
            if let expiresAt = data["expiresAt"] as? Timestamp,
               expiresAt.dateValue() < Date() {
                throw FirebaseError.operationFailed("Invitation code has expired")
            }
            
            // Add user to family members
            try await db.collection("families").document(familyId).updateData([
                "members": FieldValue.arrayUnion([userId])
            ])
            
            // Add familyId to user's familyIds
            if let currentUser = Auth.auth().currentUser {
                try await db.collection("users").document(currentUser.uid).updateData([
                    "familyIds": FieldValue.arrayUnion([familyId])
                ])
            }
            
            return JoinResult(
                familyId: familyId,
                familyName: familyName,
                message: "Successfully joined \(familyName)"
            )
            
        } catch {
            print("❌ FirestoreFamilyRepository: Error joining family: \(error)")
            throw error
        }
    }
    
    func leaveFamily(familyId: String, userId: String) async throws {
        try await removeMemberFromFamily(familyId: familyId, userId: userId)
    }
    
    func stopListening() {
        userFamilyIdsListener?.remove()
        userFamilyIdsListener = nil
        
        familyListeners.values.forEach { $0.remove() }
        familyListeners.removeAll()
        
        print("🛑 FirestoreFamilyRepository: All listeners stopped")
    }
    
    // MARK: - Private Implementation (Firestore-specific)
    
    /// CTO REQUIREMENT: Dynamic listener management with user familyIds listener
    /// This solves Issues #42, #43 by automatically adding listeners for newly created/joined families
    private func startListeningToUserFamilies(userId: String) {
        stopListening() // Clean up existing listeners
        
        userFamilyIdsListener = db.collection("users").document(userId)
            .addSnapshotListener { [weak self] documentSnapshot, error in
                Task { @MainActor in
                    guard let self = self else { return }
                    
                    if let error = error {
                        print("❌ FirestoreFamilyRepository: User listener error: \(error)")
                        self.familiesSubject.send(completion: .failure(error))
                        return
                    }
                    
                    guard let document = documentSnapshot,
                          let data = document.data(),
                          let familyIds = data["familyIds"] as? [String] else {
                        print("👤 FirestoreFamilyRepository: No family IDs found, clearing families")
                        self.familiesSubject.send([])
                        return
                    }
                    
                    print("📋 FirestoreFamilyRepository: User familyIds updated to \(familyIds)")
                    await self.updateFamilyListeners(for: familyIds)
                }
            }
        
        print("✅ FirestoreFamilyRepository: Started listening to user familyIds for dynamic updates")
    }
    
    @MainActor
    private func updateFamilyListeners(for familyIds: [String]) async {
        let currentListenerIds = Set(familyListeners.keys)
        let newFamilyIds = Set(familyIds)
        
        // Remove listeners for families no longer in user's list
        for familyId in currentListenerIds.subtracting(newFamilyIds) {
            familyListeners[familyId]?.remove()
            familyListeners.removeValue(forKey: familyId)
            print("🗑️ FirestoreFamilyRepository: Removed listener for family \(familyId)")
        }
        
        // Add listeners for new families
        for familyId in newFamilyIds.subtracting(currentListenerIds) {
            await addFamilyListener(familyId: familyId)
        }
        
        print("🔄 FirestoreFamilyRepository: Updated listeners. Current: \(familyListeners.count)")
    }
    
    @MainActor
    private func addFamilyListener(familyId: String) async {
        let listener = db.collection("families").document(familyId)
            .addSnapshotListener { [weak self] documentSnapshot, error in
                Task { @MainActor in
                    guard let self = self else { return }
                    
                    if let error = error {
                        print("❌ FirestoreFamilyRepository: Family listener error for \(familyId): \(error)")
                        self.familiesSubject.send(completion: .failure(error))
                        return
                    }
                    
                    await self.updateFamiliesArray(from: documentSnapshot, familyId: familyId)
                }
            }
        
        familyListeners[familyId] = listener
        print("✅ FirestoreFamilyRepository: Added listener for family \(familyId)")
    }
    
    @MainActor
    private func updateFamiliesArray(from documentSnapshot: DocumentSnapshot?, familyId: String) async {
        var currentFamilies = familiesSubject.value
        
        guard let document = documentSnapshot else {
            // Document deleted - remove from families array
            currentFamilies.removeAll { $0.id == familyId }
            familiesSubject.send(currentFamilies)
            print("🗑️ FirestoreFamilyRepository: Removed deleted family \(familyId)")
            return
        }
        
        guard let data = document.data() else { return }
        
        var family = Family(
            name: data["name"] as? String ?? "",
            members: data["members"] as? [String] ?? []
        )
        family.id = document.documentID
        family.createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
        family.lastUpdatedAt = (data["lastUpdatedAt"] as? Timestamp)?.dateValue()
        family.devEnvironmentTest = data["devEnvironmentTest"] as? String
        
        // Update or add family in array
        if let index = currentFamilies.firstIndex(where: { $0.id == familyId }) {
            currentFamilies[index] = family
        } else {
            currentFamilies.append(family)
        }
        
        familiesSubject.send(currentFamilies)
        print("🔄 FirestoreFamilyRepository: Updated family: \(family.name) (\(familyId))")
    }
    
    // MARK: - Helper Methods (from existing FamilyManager)
    
    private func updateUserFamilyIds(userId: String, familyId: String, action: FamilyAction) async throws {
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
    
    private func removeMemberFromFamily(familyId: String, userId: String) async throws {
        // Remove user from family members
        try await db.collection("families").document(familyId).updateData([
            "members": FieldValue.arrayRemove([userId])
        ])
        
        // Update user's familyIds
        try await updateUserFamilyIds(userId: userId, familyId: familyId, action: .remove)
    }
}

// MARK: - Supporting Types

private enum FamilyAction {
    case add
    case remove
}
