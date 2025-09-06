//
//  FamilyOperationService.swift
//  shigodeki
//
//  Created by Claude on 2025-01-04.
//

import Foundation

struct FamilyOperationService {
    
    // MARK: - Operation State
    
    struct OperationState {
        var families: [Family] = []
        var showCreateSuccess: Bool = false
        var showCreateProcessing: Bool = false
        var showJoinSuccess: Bool = false
        var showJoinProcessing: Bool = false
        var processingMessage: String = ""
        var joinSuccessMessage: String = ""
        var newFamilyInvitationCode: String?
    }
    
    // MARK: - Duplicate Prevention
    
    private static let duplicatePreventionWindow: TimeInterval = 2.0
    
    /// Checks if a create family request should be blocked due to duplication
    static func shouldBlockCreateRequest(
        trimmedName: String,
        userId: String,
        activeRequests: Set<String>,
        lastRequest: (name: String, timestamp: Date)?
    ) -> Bool {
        let requestKey = "\(userId)_\(trimmedName)"
        
        // Check for active requests with same key
        if activeRequests.contains(requestKey) {
            print("🛑 [DUPLICATE] FamilyOperationService: Ignoring duplicate create request for family: '\(trimmedName)'")
            return true
        }
        
        // Check for recent duplicate requests (within 2 seconds with same name)
        if let lastRequest = lastRequest,
           lastRequest.name == trimmedName,
           Date().timeIntervalSince(lastRequest.timestamp) < duplicatePreventionWindow {
            print("🛑 [DUPLICATE] FamilyOperationService: Ignoring rapid duplicate create request for family: '\(trimmedName)' (within \(duplicatePreventionWindow)s)")
            return true
        }
        
        return false
    }
    
    /// Creates a request key for tracking
    static func createRequestKey(userId: String, familyName: String) -> String {
        return "\(userId)_\(familyName.trimmingCharacters(in: .whitespacesAndNewlines))"
    }
    
    // MARK: - Optimistic Update Helper
    
    /// Creates a temporary family for optimistic UI updates
    static func createOptimisticFamily(name: String, userId: String) -> Family {
        let temporaryId = UUID().uuidString
        var optimisticFamily = Family(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            members: [userId]
        )
        optimisticFamily.id = temporaryId
        optimisticFamily.createdAt = Date()
        return optimisticFamily
    }
    
    /// Generates invitation code from family ID
    static func generateInvitationCode(from familyId: String) -> String {
        return "INV\(String(familyId.suffix(6)))"
    }
    
    // MARK: - Empty State Logic
    
    /// Determines if empty state should be shown
    static func shouldShowEmptyState(
        isLoading: Bool,
        families: [Family],
        hasUserId: Bool
    ) -> Bool {
        return !isLoading && families.isEmpty && hasUserId
    }
    
    // MARK: - Core Operation Methods
    
    /// Creates a new family with optimistic UI updates and error handling
    static func createFamily(
        name: String,
        userId: String,
        familyManager: FamilyManager,
        privateState: inout FamilyViewModelState.PrivateState,
        operationState: inout OperationState,
        isCreatingFamily: inout Bool,
        error: inout FirebaseError?
    ) async -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Validation
        guard !trimmedName.isEmpty else {
            error = FirebaseError.operationFailed("ファミリー名を入力してください")
            return false
        }
        
        // Duplicate prevention check
        if shouldBlockCreateRequest(
            trimmedName: trimmedName,
            userId: userId,
            activeRequests: privateState.activeCreateRequests,
            lastRequest: privateState.lastCreateRequest
        ) {
            return false
        }
        
        // Track request to prevent duplicates
        let requestKey = createRequestKey(userId: userId, familyName: trimmedName)
        privateState.activeCreateRequests.insert(requestKey)
        privateState.lastCreateRequest = (name: trimmedName, timestamp: Date())
        
        // Start loading state
        isCreatingFamily = true
        operationState.showCreateProcessing = true
        operationState.processingMessage = "ファミリーを作成中..."
        
        // Optimistic update
        let optimisticFamily = createOptimisticFamily(name: trimmedName, userId: userId)
        operationState.families.append(optimisticFamily)
        
        defer {
            isCreatingFamily = false
            operationState.showCreateProcessing = false
            privateState.activeCreateRequests.remove(requestKey)
        }
        
        do {
            let familyId = try await familyManager.createFamily(
                name: trimmedName,
                creatorUserId: userId
            )
            
            // Update optimistic family with real ID
            if let index = operationState.families.firstIndex(where: { $0.id == optimisticFamily.id }) {
                operationState.families[index].id = familyId
            }
            
            // Generate invitation code
            operationState.newFamilyInvitationCode = generateInvitationCode(from: familyId)
            
            // Show success
            operationState.showCreateSuccess = true
            
            print("✅ ファミリー '\(trimmedName)' の作成が完了しました。ID: \(familyId)")
            return true
            
        } catch {
            // Remove optimistic family on error
            operationState.families.removeAll { $0.id == optimisticFamily.id }
            
            if let firebaseError = error as? FirebaseError {
                self.error = firebaseError
            } else {
                self.error = FirebaseError.operationFailed("ファミリーの作成に失敗しました: \(error.localizedDescription)")
            }
            
            print("❌ ファミリー作成エラー: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Joins an existing family using invitation code
    static func joinFamily(
        invitationCode: String,
        userId: String,
        familyManager: FamilyManager,
        authManager: AuthenticationManager,
        operationState: inout OperationState,
        isJoiningFamily: inout Bool,
        error: inout FirebaseError?
    ) async -> Bool {
        let trimmedCode = invitationCode.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Validation
        guard !trimmedCode.isEmpty else {
            error = FirebaseError.operationFailed("招待コードを入力してください")
            return false
        }
        
        // Start loading state
        isJoiningFamily = true
        operationState.showJoinProcessing = true
        operationState.processingMessage = "ファミリーに参加中..."
        
        defer {
            isJoiningFamily = false
            operationState.showJoinProcessing = false
        }
        
        do {
            let familyName = try await familyManager.joinFamily(
                invitationCode: trimmedCode,
                userId: userId
            )
            
            // Show success message
            operationState.showJoinSuccess = true
            operationState.joinSuccessMessage = "'\(familyName)'に参加しました！"
            
            // Refresh families after successful join
            familyManager.startListeningToFamilies(userId: userId)
            
            print("✅ ファミリー '\(familyName)' への参加が完了しました")
            return true
            
        } catch {
            if let firebaseError = error as? FirebaseError {
                self.error = firebaseError
            } else {
                self.error = FirebaseError.operationFailed("ファミリーへの参加に失敗しました: \(error.localizedDescription)")
            }
            
            print("❌ ファミリー参加エラー: \(error.localizedDescription)")
            return false
        }
    }
}