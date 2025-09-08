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
            // 統一システム委譲：複雑なレガシーフォールバックを廃止
            let unifiedService = UnifiedInvitationService()
            try await unifiedService.joinWithInvitationCode(invitationCode)
            
            // 結果取得のため検証を実施（統一システム経由）
            let result = try await unifiedService.validateInvitationCode(invitationCode)
            
            print("✅ [FirestoreFamilyRepository] Delegation completed: \(invitationCode) -> familyId=\(result.targetId) familyName=\(result.targetName)")
            
            return JoinResult(
                familyId: result.targetId,
                familyName: result.targetName,
                message: "Successfully joined via unified system"
            )
            
        } catch let error as InvitationError {
            // 統一エラーを旧API形式にマッピング（互換性維持）
            print("❌ [FirestoreFamilyRepository] Unified system error: \(error.localizedDescription)")
            let firebaseError = mapToFirebaseError(error)
            throw firebaseError
        } catch {
            print("❌ [FirestoreFamilyRepository] 予期しないエラー: \(error)")
            throw FirebaseError.from(error)
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
    
    /// 統一エラーをFirebaseErrorにマッピング（API互換性維持）
    private func mapToFirebaseError(_ error: InvitationError) -> FirebaseError {
        switch error {
        case .userNotAuthenticated:
            return .operationFailed("認証が必要です")
        case .invalidCode(let reason):
            return .operationFailed("無効な招待コード: \(reason)")
        case .invalidOrExpired:
            return .operationFailed("無効または期限切れの招待コードです")
        case .corruptedData:
            return .operationFailed("招待データが破損しています")
        case .joinFailed(let reason):
            return .operationFailed("参加に失敗しました: \(reason)")
        }
    }
    
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
