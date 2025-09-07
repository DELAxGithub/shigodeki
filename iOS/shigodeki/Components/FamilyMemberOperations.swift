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
    private let userDataService = UserDataService()
    
    @Published var familyMembers: [User] = []
    @Published var isLoadingMembers = false
    @Published var retryingMembers: Set<String> = []
    
    // Cache to prevent repeated fetching
    private var memberCache: [String: User] = [:]
    
    init(familyManager: FamilyManager, authManager: AuthenticationManager) {
        self.familyManager = familyManager
        self.authManager = authManager
        print("🏗️ FamilyMemberOperations: initialized with uid-scoped member resolution")
        
        // Listen for auth changes to clear stale data
        NotificationCenter.default.addObserver(
            forName: .authUserChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleAuthUserChanged(notification)
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func updateManagers(familyManager: FamilyManager, authManager: AuthenticationManager) {
        // Clear cache when managers change to ensure fresh data
        memberCache.removeAll()
        print("🔄 FamilyMemberOperations: managers updated, cache cleared")
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
        print("📋 FamilyMemberOperations: Loading members for UIDs: \(memberIds)")
        
        for memberId in memberIds {
            guard !memberId.isEmpty else {
                print("⚠️ FamilyMemberOperations: Skipping empty member ID")
                continue
            }
            
            do {
                // Check cache first
                if let cachedMember = memberCache[memberId] {
                    print("🗄️ FamilyMemberOperations: Using cached member for uid=\(memberId)")
                    loadedMembers.append(cachedMember)
                    continue
                }
                
                // Fetch from Firestore using UserDataService
                if let user = await userDataService.loadUserData(uid: memberId) {
                    var memberUser = user
                    memberUser.id = memberId  // Ensure ID is set
                    
                    // Cache the result
                    memberCache[memberId] = memberUser
                    loadedMembers.append(memberUser)
                    
                    print("✅ FamilyMemberOperations: Loaded member uid=\(memberId), name=\(memberUser.name)")
                } else {
                    // User document not found - create a minimal user indicating missing data
                    let missingUser = User(
                        name: "ユーザー不明 (\(memberId.prefix(8)))",
                        email: "unknown@example.com",
                        familyIds: []
                    )
                    var userWithId = missingUser
                    userWithId.id = memberId
                    
                    loadedMembers.append(userWithId)
                    print("⚠️ FamilyMemberOperations: User document not found for uid=\(memberId)")
                }
                
            } catch {
                print("❌ FamilyMemberOperations: Error loading member uid=\(memberId): \(error.localizedDescription)")
                
                // Create error user with uid context
                let errorUser = User(
                    name: "エラー (\(memberId.prefix(8)))",
                    email: "error@example.com",
                    familyIds: []
                )
                var userWithId = errorUser
                userWithId.id = memberId
                
                loadedMembers.append(userWithId)
            }
        }
        
        familyMembers = loadedMembers
        print("📋 FamilyMemberOperations: Loaded \(loadedMembers.count) members total")
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
            print("🔄 FamilyMemberOperations: Retrying load for member uid=\(memberId)")
            
            // Remove from cache to force fresh fetch
            memberCache.removeValue(forKey: memberId)
            
            // Attempt to fetch user data again
            if let user = await userDataService.loadUserData(uid: memberId) {
                var memberUser = user
                memberUser.id = memberId
                
                // Cache the successful result
                memberCache[memberId] = memberUser
                
                // Update in the familyMembers array
                if let index = familyMembers.firstIndex(where: { $0.id == memberId }) {
                    familyMembers[index] = memberUser
                    print("✅ FamilyMemberOperations: Successfully reloaded member uid=\(memberId), name=\(memberUser.name)")
                }
            } else {
                // User document still not found
                let missingUser = User(
                    name: "ユーザー不明 (\(memberId.prefix(8)))",
                    email: "unknown@example.com",
                    familyIds: []
                )
                var userWithId = missingUser
                userWithId.id = memberId
                
                if let index = familyMembers.firstIndex(where: { $0.id == memberId }) {
                    familyMembers[index] = userWithId
                }
                print("⚠️ FamilyMemberOperations: Retry failed, user document still not found for uid=\(memberId)")
            }
        } catch {
            print("❌ FamilyMemberOperations: Retry failed for member uid=\(memberId): \(error.localizedDescription)")
            
            // Update error message for retry failure
            let errorUser = User(
                name: "再試行失敗 (\(memberId.prefix(8)))",
                email: "error@example.com",
                familyIds: []
            )
            var userWithId = errorUser
            userWithId.id = memberId
            
            if let index = familyMembers.firstIndex(where: { $0.id == memberId }) {
                familyMembers[index] = userWithId
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
        
        // Update local state and cache
        familyMembers.removeAll { $0.id == memberId }
        memberCache.removeValue(forKey: memberId)
        print("🗑️ FamilyMemberOperations: Removed member uid=\(memberId) from family and cache")
    }
    
    // MARK: - Cache Management
    
    /// Clear all cached member data - called on auth state changes
    func clearMemberCache() {
        memberCache.removeAll()
        familyMembers.removeAll()
        print("🗑️ FamilyMemberOperations: Cache cleared due to auth state change")
    }
    
    private func handleAuthUserChanged(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let action = userInfo["action"] as? String else { return }
        
        let newUserId = userInfo["newUserId"] as? String
        let previousUserId = userInfo["previousUserId"] as? String
        
        print("🔄 FamilyMemberOperations: Auth change detected - action=\(action), new=\(newUserId ?? "nil"), prev=\(previousUserId ?? "nil")")
        
        // Clear all member-related caches on any auth change
        clearMemberCache()
    }
}