//
//  FamilyStateService.swift
//  shigodeki
//
//  Created by Claude on 2025-09-06.
//

import Foundation

struct FamilyStateService {
    // MARK: - Empty State Management
    
    @MainActor
    static func updateEmptyState(
        publishedState: inout FamilyViewModelState.PublishedState,
        authManager: AuthenticationManager?
    ) {
        FamilyViewModelState.updateEmptyState(&publishedState, authManager: authManager)
    }
    
    // MARK: - Success State Management
    
    @MainActor
    static func resetSuccessStates(
        publishedState: inout FamilyViewModelState.PublishedState
    ) {
        FamilyViewModelState.resetSuccessStates(&publishedState)
    }
    
    // MARK: - UI Lifecycle Management
    
    static func onAppear() {
        #if DEBUG
        print("📱 FamilyViewModel: onAppear triggered")
        #endif
        // 認証状態の変更によって自動的にロードされるため、ここでの明示的なロードは不要
    }
    
    @MainActor
    static func onDisappear(familyManager: FamilyManager?) {
        #if DEBUG
        print("👋 FamilyViewModel: Disappearing, cleaning up listeners")
        #endif
        familyManager?.stopListeningToFamilies()
    }
    
    // MARK: - Sheet Dismissal Management
    
    static func dismissCreateSheetWithReload() -> Bool {
        // Firebase refresh is already done in background during success message
        print("✅ [UI] Dismissing create sheet - Firebase data already refreshed")
        return true
    }
    
    static func dismissJoinViewWithReload() {
        // Firebase refresh is already done in background during success message  
        print("✅ [UI] Dismissing join view - Firebase data already refreshed")
    }
    
    // MARK: - Proxy Methods
    
    @MainActor
    static func removeAllListeners(familyManager: FamilyManager?) {
        familyManager?.stopListeningToFamilies()
    }
    
    @MainActor
    static func clearError(
        familyManager: FamilyManager?,
        error: inout FirebaseError?
    ) {
        familyManager?.errorMessage = nil
        error = nil
    }
}