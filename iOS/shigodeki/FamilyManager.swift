//
//  FamilyManager.swift
//  shigodeki
//
//  Created by Claude on 2025-08-28.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

@MainActor
class FamilyManager: ObservableObject {
    @Published var families: [Family] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    private var familyListeners: [ListenerRegistration] = []
    private let listenerQueue = DispatchQueue(label: "com.shigodeki.familyManager.listeners", qos: .userInteractive)
    
    // MARK: - Family Creation
    
    func createFamily(name: String, creatorUserId: String) async throws -> String {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw FamilyError.invalidName
        }
        
        // Create family document
        var family = Family(name: name.trimmingCharacters(in: .whitespacesAndNewlines), members: [creatorUserId])
        family.createdAt = Date()
        
        let familyData: [String: Any] = [
            "name": family.name,
            "members": family.members,
            "createdAt": FieldValue.serverTimestamp()
        ]
        
        do {
            let familyRef = try await db.collection("families").addDocument(data: familyData)
            let familyId = familyRef.documentID
            
            // Update user's familyIds array
            try await updateUserFamilyIds(userId: creatorUserId, familyId: familyId, action: .add)
            
            // Create invitation code for this family
            try await generateInvitationCode(familyId: familyId, familyName: family.name)
            
            print("Family created successfully with ID: \(familyId)")
            return familyId
            
        } catch {
            print("Error creating family: \(error)")
            errorMessage = "家族グループの作成に失敗しました"
            throw FamilyError.creationFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Family Data Loading
    
    func loadFamiliesForUser(userId: String) async {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        do {
            // First, get user document to find their family IDs
            let userDoc = try await db.collection("users").document(userId).getDocument()
            
            guard let userData = userDoc.data(),
                  let familyIds = userData["familyIds"] as? [String] else {
                families = []
                return
            }
            
            if familyIds.isEmpty {
                families = []
                return
            }
            
            // Load all families the user belongs to
            var loadedFamilies: [Family] = []
            
            for familyId in familyIds {
                if let family = try await loadFamily(familyId: familyId) {
                    loadedFamilies.append(family)
                }
            }
            
            families = loadedFamilies
            
        } catch {
            print("Error loading families: \(error)")
            errorMessage = "家族グループの読み込みに失敗しました"
        }
    }
    
    private func loadFamily(familyId: String) async throws -> Family? {
        let familyDoc = try await db.collection("families").document(familyId).getDocument()
        
        guard familyDoc.exists, let data = familyDoc.data() else {
            return nil
        }
        
        var family = Family(
            name: data["name"] as? String ?? "",
            members: data["members"] as? [String] ?? []
        )
        family.id = familyId
        family.createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
        
        return family
    }
    
    // MARK: - Real-time Listeners
    
    func startListeningToFamilies(userId: String) {
        stopListeningToFamilies()
        
        Task { @MainActor in
            do {
                // Get user's family IDs
                let userDoc = try await db.collection("users").document(userId).getDocument()
                guard let userData = userDoc.data(),
                      let familyIds = userData["familyIds"] as? [String] else {
                    return
                }
                
                // Set up listeners for each family
                for familyId in familyIds {
                    let listener = db.collection("families").document(familyId)
                        .addSnapshotListener { [weak self] documentSnapshot, error in
                            Task { @MainActor in
                                guard let self = self else { return }
                                
                                if let error = error {
                                    print("Family listener error: \(error)")
                                    self.errorMessage = "家族データの同期中にエラーが発生しました"
                                    return
                                }
                                
                                guard let document = documentSnapshot,
                                      let data = document.data() else {
                                    return
                                }
                                
                                var family = Family(
                                    name: data["name"] as? String ?? "",
                                    members: data["members"] as? [String] ?? []
                                )
                                family.id = document.documentID
                                family.createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
                                
                                // Update families array thread-safely
                                self.updateFamilyInArray(family)
                            }
                        }
                    
                    familyListeners.append(listener)
                }
                
            } catch {
                print("Error setting up family listeners: \(error)")
                errorMessage = "家族データの監視設定に失敗しました"
            }
        }
    }
    
    func stopListeningToFamilies() {
        familyListeners.forEach { $0.remove() }
        familyListeners.removeAll()
    }
    
    // MARK: - Invitation System
    
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
    
    func joinFamilyWithCode(_ code: String, userId: String) async throws -> String {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
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
        
        // Add user to family members
        try await db.collection("families").document(familyId).updateData([
            "members": FieldValue.arrayUnion([userId])
        ])
        
        // Update user's familyIds
        try await updateUserFamilyIds(userId: userId, familyId: familyId, action: .add)
        
        // Mark invitation as used (optional - could keep active for multiple uses)
        // try await db.collection("invitations").document(code).updateData(["isActive": false])
        
        return familyName
    }
    
    private func generateRandomCode() -> String {
        let characters = "0123456789"
        return String((0..<6).map { _ in characters.randomElement()! })
    }
    
    // MARK: - Member Management
    
    func removeMemberFromFamily(familyId: String, userId: String) async throws {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        // Remove user from family members
        try await db.collection("families").document(familyId).updateData([
            "members": FieldValue.arrayRemove([userId])
        ])
        
        // Update user's familyIds
        try await updateUserFamilyIds(userId: userId, familyId: familyId, action: .remove)
    }
    
    func leaveFamily(familyId: String, userId: String) async throws {
        try await removeMemberFromFamily(familyId: familyId, userId: userId)
    }
    
    // MARK: - Helper Methods
    
    private func updateFamilyInArray(_ family: Family) {
        if let index = families.firstIndex(where: { $0.id == family.id }) {
            families[index] = family
        } else {
            families.append(family)
        }
    }
    
    private enum FamilyIdAction {
        case add, remove
    }
    
    private func updateUserFamilyIds(userId: String, familyId: String, action: FamilyIdAction) async throws {
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
    
    // MARK: - Cleanup
    
    func cleanupInactiveListeners() {
        // Remove listeners for families that no longer exist in the current list
        let activeFamilyIds = Set(families.compactMap { $0.id })
        familyListeners.removeAll { listener in
            // This would require more sophisticated tracking to identify which listener belongs to which family
            // For now, we'll keep all listeners active
            false
        }
    }
    
    deinit {
        familyListeners.forEach { $0.remove() }
        familyListeners.removeAll()
    }
}

// MARK: - Error Types

enum FamilyError: LocalizedError {
    case invalidName
    case creationFailed(String)
    case invalidInvitationCode
    case expiredInvitationCode
    case notFound
    case permissionDenied
    
    var errorDescription: String? {
        switch self {
        case .invalidName:
            return "家族グループ名が無効です"
        case .creationFailed(let message):
            return "家族グループの作成に失敗しました: \(message)"
        case .invalidInvitationCode:
            return "無効な招待コードです"
        case .expiredInvitationCode:
            return "招待コードの有効期限が切れています"
        case .notFound:
            return "家族グループが見つかりません"
        case .permissionDenied:
            return "この操作の権限がありません"
        }
    }
}