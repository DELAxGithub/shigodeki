//
//  FamilyViewModelDI.swift
//  shigodeki
//
//  Created for CTO DI Architecture Implementation
//  Repository Pattern FamilyViewModel with Dependency Injection
//  Issues #42, #43, #50 Root Fix
//

import Foundation
import Combine
import SwiftUI

/// FamilyViewModel with Repository Pattern and Dependency Injection
/// CTO REQUIREMENT: Protocols over concrete classes, testable architecture
@MainActor
class FamilyViewModelDI: ObservableObject {
    
    // MARK: - Published Properties (UI State)
    
    @Published var families: [Family] = []
    @Published var isLoading: Bool = false
    @Published var error: FirebaseError? = nil
    @Published var shouldShowEmptyState = false
    
    // NavigationSplitView selection
    @Published var selectedFamily: Family? = nil
    
    // Family creation/join state
    @Published var isCreatingFamily = false
    @Published var isJoiningFamily = false
    @Published var shouldDismissCreateSheet = false
    @Published var showJoinSuccess = false
    @Published var joinSuccessMessage = ""
    @Published var newFamilyInvitationCode: String?
    
    // Success/Processing alerts
    @Published var showCreateSuccess = false
    @Published var createSuccessMessage = ""
    @Published var showCreateProcessing = false
    @Published var showJoinProcessing = false
    @Published var processingMessage = ""
    
    // MARK: - Dependencies (Protocol-based)
    
    private let repository: FamilyRepository
    private let authManager: AuthenticationManager
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Business Logic State
    
    // Duplicate prevention
    private var activeCreateRequests: Set<String> = []
    private var lastCreateRequest: (name: String, timestamp: Date)?
    private let duplicatePreventionWindow: TimeInterval = 2.0
    
    // MARK: - Initialization (CTO REQUIREMENT: Repository injection)
    
    /// Initialize with Repository dependency injection
    /// - Parameters:
    ///   - repository: FamilyRepository protocol implementation
    ///   - authManager: Authentication manager for user ID access
    init(repository: FamilyRepository, authManager: AuthenticationManager? = nil) {
        self.repository = repository
        self.authManager = authManager ?? AuthenticationManager.shared
        
        print("✅ FamilyViewModelDI: Initialized with Repository Pattern")
        
        setupAuthenticationObserver()
        setupRepositorySubscription()
    }
    
    // MARK: - Setup Methods
    
    private func setupAuthenticationObserver() {
        authManager.$currentUser
            .removeDuplicates()
            .sink { [weak self] user in
                Task { @MainActor in
                    await self?.handleUserChange(user)
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupRepositorySubscription() {
        // This will be triggered when user changes
        print("🔗 FamilyViewModelDI: Repository subscription ready")
    }
    
    private func handleUserChange(_ user: User?) async {
        if let user = user, let userId = user.id {
            print("🔄 FamilyViewModelDI: User authenticated (\(userId)), starting data subscription")
            await subscribeToFamilies(for: userId)
        } else {
            print("🔄 FamilyViewModelDI: User signed out, stopping data subscription")
            repository.stopListening()
            families = []
            updateEmptyState()
        }
    }
    
    private func subscribeToFamilies(for userId: String) async {
        repository.familiesPublisher(for: userId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    switch completion {
                    case .finished:
                        print("📡 FamilyViewModelDI: Families subscription completed")
                    case .failure(let error):
                        print("❌ FamilyViewModelDI: Families subscription error: \(error)")
                        self?.error = FirebaseError.from(error)
                    }
                },
                receiveValue: { [weak self] families in
                    print("📡 FamilyViewModelDI: Received \(families.count) families from repository")
                    self?.families = families
                    self?.updateEmptyState()
                }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods (CTO REQUIREMENT: All operations through Repository)
    
    func createFamily(name: String) async -> Bool {
        guard let userId = authManager.currentUser?.id else {
            error = FirebaseError.operationFailed("ユーザーが認証されていません")
            return false
        }
        
        // Duplicate prevention checks
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let requestKey = "\(userId)_\(trimmedName)"
        
        if activeCreateRequests.contains(requestKey) {
            print("🛑 FamilyViewModelDI: Ignoring duplicate create request for family: '\(trimmedName)'")
            return false
        }
        
        if let lastRequest = lastCreateRequest,
           lastRequest.name == trimmedName,
           Date().timeIntervalSince(lastRequest.timestamp) < duplicatePreventionWindow {
            print("🛑 FamilyViewModelDI: Ignoring rapid duplicate create request for family: '\(trimmedName)'")
            return false
        }
        
        // Track request
        activeCreateRequests.insert(requestKey)
        lastCreateRequest = (name: trimmedName, timestamp: Date())
        
        // Update UI state
        isCreatingFamily = true
        processingMessage = "家族グループを作成中..."
        showCreateProcessing = true
        
        defer {
            isCreatingFamily = false
            showCreateProcessing = false
            activeCreateRequests.remove(requestKey)
        }
        
        do {
            print("🔥 FamilyViewModelDI: Starting Repository createFamily operation for '\(trimmedName)'")
            let familyId = try await repository.createFamily(name: trimmedName, creatorUserId: userId)
            print("✅ FamilyViewModelDI: Repository operation completed successfully. ID: \(familyId)")
            
            // Generate invitation code
            let invitationCode = "INV\(String(familyId.suffix(6)))"
            newFamilyInvitationCode = invitationCode
            
            // Success state - Repository listener will automatically update families array
            showCreateSuccess = true
            createSuccessMessage = "家族グループ「\(trimmedName)」を作成しました！"
            
            return true
            
        } catch {
            print("❌ FamilyViewModelDI: Repository error during createFamily: \(error)")
            self.error = FirebaseError.from(error)
            return false
        }
    }
    
    func joinFamily(invitationCode: String) async -> Bool {
        guard let userId = authManager.currentUser?.id else {
            error = FirebaseError.operationFailed("ユーザーが認証されていません")
            return false
        }
        
        isJoiningFamily = true
        processingMessage = "家族グループに参加中..."
        showJoinProcessing = true
        
        defer {
            isJoiningFamily = false
            showJoinProcessing = false
        }
        
        do {
            print("🔥 FamilyViewModelDI: Starting Repository joinFamily operation")
            let result = try await repository.joinFamily(userId: userId, invitationCode: invitationCode)
            print("✅ FamilyViewModelDI: Repository join operation completed successfully")
            
            // Success state - Repository listener will automatically update families array
            joinSuccessMessage = result.message ?? "家族グループに参加しました！"
            showJoinSuccess = true
            
            return true
            
        } catch {
            print("❌ FamilyViewModelDI: Repository error during joinFamily: \(error)")
            self.error = FirebaseError.from(error)
            return false
        }
    }
    
    func leaveFamily(_ family: Family) async {
        guard let userId = authManager.currentUser?.id else {
            error = FirebaseError.operationFailed("ユーザーが認証されていません")
            return
        }
        
        guard let familyId = family.id else {
            error = FirebaseError.operationFailed("家族IDが見つかりません")
            return
        }
        
        do {
            print("🔥 FamilyViewModelDI: Starting Repository leaveFamily operation")
            try await repository.leaveFamily(familyId: familyId, userId: userId)
            print("✅ FamilyViewModelDI: Repository leave operation completed successfully")
            
            // Repository listener will automatically update families array
            
        } catch {
            print("❌ FamilyViewModelDI: Repository error during leaveFamily: \(error)")
            self.error = FirebaseError.from(error)
        }
    }
    
    // MARK: - UI State Management
    
    private func updateEmptyState() {
        shouldShowEmptyState = !isLoading && families.isEmpty && error == nil
    }
    
    func resetSuccessStates() {
        shouldDismissCreateSheet = false
        showJoinSuccess = false
        joinSuccessMessage = ""
        newFamilyInvitationCode = nil
        showCreateSuccess = false
        createSuccessMessage = ""
        showCreateProcessing = false
        showJoinProcessing = false
        processingMessage = ""
    }
    
    func dismissCreateSheetWithReload() {
        shouldDismissCreateSheet = true
        print("✅ FamilyViewModelDI: Dismissing create sheet - Repository listener handles data updates")
    }
    
    func dismissJoinViewWithReload() {
        print("✅ FamilyViewModelDI: Dismissing join view - Repository listener handles data updates")
    }
    
    func clearError() {
        error = nil
    }
    
    // MARK: - Cleanup
    
    deinit {
        repository.stopListening()
        cancellables.removeAll()
        print("🧹 FamilyViewModelDI: Cleaned up")
    }
}

// MARK: - Supporting Extensions
// Note: FirebaseError.from() extension is already defined in FirebaseError.swift