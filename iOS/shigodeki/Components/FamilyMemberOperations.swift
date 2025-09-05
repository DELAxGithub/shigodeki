//
//  FamilyMemberOperations.swift  
//  shigodeki
//
//  Extracted from FamilyDetailView.swift for better code organization
//  Handles family member loading, retry logic, and removal operations
//

import SwiftUI
import FirebaseFirestore

@MainActor
class FamilyMemberOperations: ObservableObject {
    private let familyManager: FamilyManager
    private let authManager: AuthenticationManager
    
    @Published var familyMembers: [User] = []
    @Published var isLoadingMembers = false
    @Published var retryingMembers: Set<String> = []
    
    init(familyManager: FamilyManager, authManager: AuthenticationManager) {
        self.familyManager = familyManager
        self.authManager = authManager
    }
    
    func updateManagers(familyManager: FamilyManager, authManager: AuthenticationManager) {
        // Note: In a production app, you'd want to implement proper manager updating
        // For now, this is a placeholder to satisfy the interface
    }
    
    func loadFamilyMembers(family: Family) {
        Task {
            isLoadingMembers = true
            await loadMembersInternal(memberIds: family.members)
            isLoadingMembers = false
        }
    }
    
    private func loadMembersInternal(memberIds: [String]) async {
        var loadedMembers: [User] = []
        
        for memberId in memberIds {
            do {
                // Check if we already have this member loaded correctly
                if let existingMember = familyMembers.first(where: { $0.id == memberId }),
                   !existingMember.name.contains("エラー") && !existingMember.name.contains("Load Error") {
                    loadedMembers.append(existingMember)
                    continue
                }
                
                // Try to load the member
                if let user = try await familyManager.fetchUser(id: memberId) {
                    loadedMembers.append(user)
                } else {
                    // Create error user if fetch returns nil
                    let errorUser = User(
                        id: memberId,
                        email: "Load Error: User not found",
                        name: "エラー: ユーザーが見つかりません (タップして再試行)",
                        createdAt: Date(),
                        familyIds: []
                    )
                    loadedMembers.append(errorUser)
                }
            } catch {
                print("❌ Error loading member \(memberId): \(error.localizedDescription)")
                
                // Create error user with detailed error info
                let errorMessage = "Load Error: \(error.localizedDescription)"
                let errorUser = User(
                    id: memberId,
                    email: errorMessage,
                    name: "エラー: \(error.localizedDescription.prefix(20))... (タップして再試行)",
                    createdAt: Date(),
                    familyIds: []
                )
                loadedMembers.append(errorUser)
            }
        }
        
        familyMembers = loadedMembers
    }
    
    func retryMemberLoad(memberId: String) {
        Task {
            retryingMembers.insert(memberId)
            await loadSingleMember(memberId: memberId)
            retryingMembers.remove(memberId)
        }
    }
    
    private func loadSingleMember(memberId: String) async {
        do {
            print("🔄 Retrying load for member: \(memberId)")
            
            if let user = try await familyManager.fetchUser(id: memberId) {
                // Successfully loaded - update the member in the list
                if let index = familyMembers.firstIndex(where: { $0.id == memberId }) {
                    familyMembers[index] = user
                    print("✅ Successfully reloaded member: \(user.name)")
                }
            } else {
                // Still failed - update error message
                let errorUser = User(
                    id: memberId,
                    email: "Retry Failed: User not found",
                    name: "再試行失敗: ユーザーが見つかりません (タップして再試行)",
                    createdAt: Date(),
                    familyIds: []
                )
                
                if let index = familyMembers.firstIndex(where: { $0.id == memberId }) {
                    familyMembers[index] = errorUser
                }
                print("❌ Retry failed for member: \(memberId)")
            }
        } catch {
            print("❌ Retry failed for member \(memberId): \(error.localizedDescription)")
            
            // Update error message for retry failure
            let errorMessage = "Retry Failed: \(error.localizedDescription)"
            let errorUser = User(
                id: memberId,
                email: errorMessage,
                name: "再試行失敗: \(error.localizedDescription.prefix(20))... (タップして再試行)",
                createdAt: Date(),
                familyIds: []
            )
            
            if let index = familyMembers.firstIndex(where: { $0.id == memberId }) {
                familyMembers[index] = errorUser
            }
        }
    }
    
    func removeMember(_ member: User, from family: Family) async throws {
        guard let memberId = member.id,
              let currentUserId = authManager.currentUser?.id else {
            throw NSError(domain: "FamilyDetailView", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid member or user data"])
        }
        
        // Check if user is trying to remove themselves
        if memberId == currentUserId {
            throw NSError(domain: "FamilyDetailView", code: -2, userInfo: [NSLocalizedDescriptionKey: "Cannot remove yourself from the family"])
        }
        
        try await familyManager.removeMemberFromFamily(familyId: family.id ?? "", userId: memberId)
        
        // Update local state
        familyMembers.removeAll { $0.id == memberId }
    }
}