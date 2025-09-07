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
    
}