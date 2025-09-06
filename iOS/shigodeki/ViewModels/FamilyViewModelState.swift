//
//  FamilyViewModelState.swift
//  shigodeki
//
//  Created by Claude on 2025-01-04.
//

import Foundation

/// State management for FamilyViewModel
struct FamilyViewModelState {
    
    // MARK: - Published State Properties
    
    /// Published properties that can be observed by Views
    struct PublishedState {
        var families: [Family] = []
        var isLoading: Bool = false
        var error: FirebaseError? = nil
        var shouldShowEmptyState = false
        var selectedFamily: Family? = nil
        var isInitialized = false
        
        // Family creation state
        var isCreatingFamily = false
        var isJoiningFamily = false
        var shouldDismissCreateSheet = false
        var showJoinSuccess = false
        var joinSuccessMessage = ""
        var newFamilyInvitationCode: String?
        
        // Success alerts for create/join operations
        var showCreateSuccess = false
        var createSuccessMessage = ""
        
        // Processing popups
        var showCreateProcessing = false
        var showJoinProcessing = false
        var processingMessage = ""
    }
    
    // MARK: - Private State Properties
    
    /// Private state for internal business logic
    struct PrivateState {
        var familyManager: FamilyManager?
        var authManager: AuthenticationManager?
        
        // Duplicate prevention
        var activeCreateRequests: Set<String> = []
        var lastCreateRequest: (name: String, timestamp: Date)?
    }
    
    // MARK: - State Reset Operations
    
    /// Resets all success states
    static func resetSuccessStates(_ state: inout PublishedState) {
        state.shouldDismissCreateSheet = false
        state.showJoinSuccess = false
        state.joinSuccessMessage = ""
        state.newFamilyInvitationCode = nil
        state.showCreateSuccess = false
        state.createSuccessMessage = ""
        state.showCreateProcessing = false
        state.showJoinProcessing = false
        state.processingMessage = ""
    }
    
    /// Updates empty state based on current conditions
    @MainActor static func updateEmptyState(
        _ state: inout PublishedState,
        authManager: AuthenticationManager?
    ) {
        // Manager注入前は常にfalse
        guard let authManager = authManager else {
            state.shouldShowEmptyState = false
            return
        }
        
        // Empty state logic: show when not loading and no families exist
        let newEmptyState = FamilyOperationService.shouldShowEmptyState(
            isLoading: state.isLoading,
            families: state.families,
            hasUserId: authManager.currentUser?.id != nil
        )
        
        print("🔍 [DEBUG] updateEmptyState: loading=\(state.isLoading), familiesEmpty=\(state.families.isEmpty), userId=\(authManager.currentUser?.id ?? "nil") → shouldShowEmptyState=\(newEmptyState)")
        state.shouldShowEmptyState = newEmptyState
    }
}