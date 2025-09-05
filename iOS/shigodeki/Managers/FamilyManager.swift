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
    
    // Service dependencies
    private let optimisticUpdates = FamilyOptimisticUpdatesManager()
    private let creationService = FamilyCreationService()
    private let invitationService = FamilyInvitationService()
    private let membershipService = FamilyMembershipService()
    private let listenerService = FamilyListenerService()
    
    // MARK: - Family Creation
    
    func createFamily(name: String, creatorUserId: String) async throws -> String {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw FamilyError.invalidName
        }
        
        // 1. Optimistic update: immediately reflect in UI
        let tempId = "temp_\(UUID().uuidString)"
        var optimisticFamily = Family(name: trimmedName, members: [creatorUserId])
        optimisticFamily.id = tempId
        optimisticFamily.createdAt = Date()
        
        families.append(optimisticFamily)
        
        // Record pending operation
        let pendingOp = optimisticUpdates.createPendingOperation(
            type: .createFamily(tempId: tempId),
            originalData: nil
        )
        optimisticUpdates.addPendingOperation(key: tempId, operation: pendingOp)
        
        do {
            // 2. Execute server operation
            let realFamilyId = try await creationService.createFamilyOnServer(name: trimmedName, creatorUserId: creatorUserId)
            
            // 3. Success: replace temp ID with real ID
            if let index = families.firstIndex(where: { $0.id == tempId }) {
                families[index].id = realFamilyId
                optimisticUpdates.removePendingOperation(key: tempId)
            }
            
            return realFamilyId
            
        } catch {
            // 4. Failure: rollback
            rollbackCreateFamily(tempId: tempId)
            errorMessage = "家族グループの作成に失敗しました"
            throw error
        }
    }
    
    private func rollbackCreateFamily(tempId: String) {
        optimisticUpdates.removePendingOperation(key: tempId)
        families.removeAll { $0.id == tempId }
        print("Rolled back optimistic family creation: \(tempId)")
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
        family.lastUpdatedAt = (data["lastUpdatedAt"] as? Timestamp)?.dateValue()
        family.devEnvironmentTest = data["devEnvironmentTest"] as? String
        
        return family
    }
    
    // MARK: - Real-time Listeners
    
    func startListeningToFamilies(userId: String) {
        listenerService.startListeningToFamilies(
            userId: userId,
            onFamiliesUpdated: { [weak self] updatedFamilies in
                self?.families = updatedFamilies
            },
            onError: { [weak self] errorMsg in
                self?.errorMessage = errorMsg
            }
        )
    }
    
    func stopListeningToFamilies() {
        listenerService.stopListeningToFamilies()
    }
    
    // MARK: - Invitation System
    
    func generateInvitationCode(familyId: String, familyName: String) async throws {
        try await invitationService.generateInvitationCode(familyId: familyId, familyName: familyName)
    }
    
    func joinFamilyWithCode(_ code: String, userId: String) async throws -> String {
        // 1. Validate invitation code
        let (familyId, familyName) = try await invitationService.validateInvitationCode(code)
        
        // 2. Optimistic update: add new family to UI
        let optimisticFamily = Family(name: familyName, members: [userId])
        let tempId = "joining_\(familyId)"
        var newFamily = optimisticFamily
        newFamily.id = familyId
        newFamily.createdAt = Date()
        
        families.append(newFamily)
        
        // Record pending operation
        let pendingOp = optimisticUpdates.createPendingOperation(
            type: .joinFamily(familyId: familyId, userId: userId),
            originalData: nil
        )
        optimisticUpdates.addPendingOperation(key: tempId, operation: pendingOp)
        
        do {
            // 3. Execute server operation
            try await invitationService.joinFamilyWithCodeOnServer(code: code, familyId: familyId, familyName: familyName, userId: userId)
            
            // 4. Success: clear pending operation
            optimisticUpdates.removePendingOperation(key: tempId)
            return familyName
            
        } catch {
            // 5. Failure: rollback
            rollbackJoinFamily(familyId: familyId)
            throw error
        }
    }
    
    private func rollbackJoinFamily(familyId: String) {
        let tempId = "joining_\(familyId)"
        optimisticUpdates.removePendingOperation(key: tempId)
        families.removeAll { $0.id == familyId }
        print("Rolled back optimistic family join: \(familyId)")
    }
    
    // MARK: - Member Management
    
    func removeMemberFromFamily(familyId: String, userId: String) async throws {
        guard let familyIndex = families.firstIndex(where: { $0.id == familyId }) else {
            throw FamilyError.notFound
        }
        
        let originalMembers = families[familyIndex].members
        let operationId = "\(familyId)_\(userId)"
        
        // Optimistic update: immediately remove member from UI
        families[familyIndex].members.removeAll { $0 == userId }
        
        // Record pending operation
        let pendingOp = optimisticUpdates.createPendingOperation(
            type: .removeMember(familyId: familyId, userId: userId),
            originalData: originalMembers
        )
        optimisticUpdates.addPendingOperation(key: operationId, operation: pendingOp)
        
        do {
            try await membershipService.removeMemberFromFamilyOnServer(familyId: familyId, userId: userId)
            optimisticUpdates.removePendingOperation(key: operationId)
        } catch {
            rollbackRemoveMember(familyId: familyId, userId: userId, originalMembers: originalMembers)
            throw error
        }
    }
    
    func leaveFamily(familyId: String, userId: String) async throws {
        guard let familyIndex = families.firstIndex(where: { $0.id == familyId }) else {
            throw FamilyError.notFound
        }
        
        let originalFamily = families[familyIndex]
        let operationId = "leave_\(familyId)_\(userId)"
        
        // Optimistic update: remove family from list
        families.remove(at: familyIndex)
        
        // Record pending operation
        let pendingOp = optimisticUpdates.createPendingOperation(
            type: .removeMember(familyId: familyId, userId: userId),
            originalData: originalFamily
        )
        optimisticUpdates.addPendingOperation(key: operationId, operation: pendingOp)
        
        do {
            // If last member (creator), delete entire family
            if originalFamily.members.count == 1 && originalFamily.members.first == userId {
                try await membershipService.updateUserFamilyIds(userId: userId, familyId: familyId, action: .remove)
                try await membershipService.deleteFamilyFromServer(familyId: familyId)
            } else {
                try await membershipService.removeMemberFromFamilyOnServer(familyId: familyId, userId: userId)
            }
            
            optimisticUpdates.removePendingOperation(key: operationId)
        } catch {
            rollbackLeaveFamily(familyId: familyId, userId: userId, originalFamily: originalFamily)
            throw error
        }
    }
    
    private func rollbackRemoveMember(familyId: String, userId: String, originalMembers: [String]) {
        let operationId = "\(familyId)_\(userId)"
        optimisticUpdates.removePendingOperation(key: operationId)
        
        if let familyIndex = families.firstIndex(where: { $0.id == familyId }) {
            families[familyIndex].members = originalMembers
        }
    }
    
    private func rollbackLeaveFamily(familyId: String, userId: String, originalFamily: Family) {
        let operationId = "leave_\(familyId)_\(userId)"
        optimisticUpdates.removePendingOperation(key: operationId)
        families.append(originalFamily)
    }
    
    // MARK: - Helper Methods
    
    private func updateFamilyInArray(_ family: Family) {
        if let index = families.firstIndex(where: { $0.id == family.id }) {
            families[index] = family
        } else {
            families.append(family)
        }
    }
    
    // MARK: - Cleanup
    
    func cleanupInactiveListeners() {
        listenerService.cleanupInactiveListeners()
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