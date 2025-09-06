//
//  FamilyViewModel.swift
//  shigodeki
//
//  Created by Claude on 2025-09-01.
//  🚨 CTO修正: 即時初期化、非同期注入パターンに全面改修
//

import Foundation
import Combine
import SwiftUI
import FirebaseFirestore

@MainActor
class FamilyViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var families: [Family] = []
    @Published var isLoading: Bool = false
    @Published var error: FirebaseError? = nil
    @Published var shouldShowEmptyState = false
    
    // 🚨 CTO Requirement: State for NavigationSplitView selection
    @Published var selectedFamily: Family? = nil
    
    /// マネージャーが注入され、ViewModelが完全に機能する状態かを示す
    @Published private(set) var isInitialized = false
    
    // Family creation state
    @Published var isCreatingFamily = false
    @Published var isJoiningFamily = false
    @Published var shouldDismissCreateSheet = false {
        didSet {
            print("📱 [DEBUG] FamilyViewModel: shouldDismissCreateSheet changed from \(oldValue) to \(shouldDismissCreateSheet)")
        }
    }
    @Published var showJoinSuccess = false {
        didSet {
            print("✅ [DEBUG] FamilyViewModel: showJoinSuccess changed from \(oldValue) to \(showJoinSuccess)")
        }
    }
    @Published var joinSuccessMessage = "" {
        didSet {
            print("📝 [DEBUG] FamilyViewModel: joinSuccessMessage changed to '\(joinSuccessMessage)'")
        }
    }
    @Published var newFamilyInvitationCode: String?
    
    // Success alerts for create/join operations
    @Published var showCreateSuccess = false {
        didSet {
            print("✅ [DEBUG] FamilyViewModel: showCreateSuccess changed from \(oldValue) to \(showCreateSuccess)")
        }
    }
    @Published var createSuccessMessage = "" {
        didSet {
            print("📝 [DEBUG] FamilyViewModel: createSuccessMessage changed to '\(createSuccessMessage)'")
        }
    }
    
    // Processing popups - show immediately when buttons are pressed
    @Published var showCreateProcessing = false {
        didSet {
            print("🔄 [DEBUG] FamilyViewModel: showCreateProcessing changed from \(oldValue) to \(showCreateProcessing)")
        }
    }
    @Published var showJoinProcessing = false {
        didSet {
            print("🔄 [DEBUG] FamilyViewModel: showJoinProcessing changed from \(oldValue) to \(showJoinProcessing)")
        }
    }
    @Published var processingMessage = "" {
        didSet {
            print("📝 [DEBUG] FamilyViewModel: processingMessage changed to '\(processingMessage)'")
        }
    }
    
    // MARK: - Private Properties
    private var familyManager: FamilyManager?
    private var authManager: AuthenticationManager?
    private var cancellables = Set<AnyCancellable>()
    
    // --- Private Business Logic State ---
    private var privateState = FamilyViewModelState.PrivateState()

    /// **【重要】同期イニシャライザ**  
    /// Viewの生成と同時に、依存関係なしで即座にインスタンス化される。
    init(authManager: AuthenticationManager = AuthenticationManager.shared) {
        print("⚡ FamilyViewModel: 同期初期化開始")
        self.privateState.authManager = authManager
        self.authManager = authManager
        setupAuthenticationObserver()
        print("✅ FamilyViewModel: 同期初期化完了 - 認証状態の監視を開始")
    }
    
    private func setupAuthenticationObserver() {
        if let cancellable = FamilyInitializationService.setupAuthenticationObserver(
            authManager: authManager,
            userChangeHandler: { [weak self] user in
                self?.handleUserChange(user)
            }
        ) {
            cancellables.insert(cancellable)
        }
    }
    
    /// **【重要】認証状態変化ハンドラー**
    /// ViewModelが自律的に認証状態を監視し、適切なタイミングでデータロードを実行
    private func handleUserChange(_ user: User?) {
        FamilyInitializationService.handleUserChange(
            user: user,
            familyManager: familyManager,
            families: &families,
            setupFamilyManagerCallback: { [weak self] in
                await self?.setupFamilyManagerIfNeeded()
            },
            loadFamiliesCallback: { [weak self] userId in
                await self?.loadFamilies(for: userId)
            }
        )
    }
    
    // MARK: - Access to Managers for Views that need it
    var familyManagerForViews: FamilyManager? {
        return familyManager
    }
    
    var authManagerForViews: AuthenticationManager? {
        return authManager
    }

    private func setupBindings() {
        guard let familyManager = familyManager else {
            print("⚠️ FamilyViewModel: setupBindings() called but familyManager is nil")
            return
        }
        
        let newCancellables = FamilyInitializationService.setupBindings(
            familyManager: familyManager,
            familiesBinding: { [weak self] families in
                self?.families = families
            },
            isLoadingBinding: { [weak self] isLoading in
                self?.isLoading = isLoading
            },
            errorBinding: { [weak self] errorMessage in
                if let errorMessage = errorMessage {
                    self?.error = FirebaseError.operationFailed(errorMessage)
                } else {
                    self?.error = nil
                }
            },
            updateEmptyStateCallback: { [weak self] in
                self?.updateEmptyState()
            }
        )
        
        for cancellable in newCancellables {
            cancellables.insert(cancellable)
        }
    }
    
    private func loadInitialData() async {
        await FamilyInitializationService.loadInitialData(
            authManager: authManager,
            familyManager: familyManager
        )
    }
    
    private func updateEmptyState() {
        var publishedState = FamilyViewModelState.PublishedState()
        publishedState.isLoading = isLoading
        publishedState.families = families
        
        FamilyStateService.updateEmptyState(&publishedState, authManager: authManager)
        shouldShowEmptyState = publishedState.shouldShowEmptyState
    }
    
    // MARK: - Public Interface
    
    func onAppear() async {
        FamilyStateService.onAppear()
    }
    
    func onDisappear() {
        FamilyStateService.onDisappear(familyManager: familyManager)
    }
    
    func createFamily(name: String) async -> Bool {
        guard let authManager = authManager, let familyManager = familyManager,
              let userId = authManager.currentUser?.id else {
            error = FirebaseError.operationFailed("システムが準備できていません")
            return false
        }
        
        var operationState = FamilyOperationService.OperationState()
        operationState.families = families
        operationState.showCreateSuccess = showCreateSuccess
        operationState.showCreateProcessing = showCreateProcessing
        operationState.processingMessage = processingMessage
        operationState.newFamilyInvitationCode = newFamilyInvitationCode
        
        let result = await FamilyOperationService.createFamily(
            name: name, userId: userId, familyManager: familyManager,
            privateState: &privateState, operationState: &operationState,
            isCreatingFamily: &isCreatingFamily, error: &error
        )
        
        families = operationState.families
        showCreateSuccess = operationState.showCreateSuccess
        showCreateProcessing = operationState.showCreateProcessing
        processingMessage = operationState.processingMessage
        newFamilyInvitationCode = operationState.newFamilyInvitationCode
        
        return result
    }
    
    func joinFamily(invitationCode: String) async -> Bool {
        guard let authManager = authManager, let familyManager = familyManager,
              let userId = authManager.currentUser?.id else {
            error = FirebaseError.operationFailed("システムが準備できていません")
            return false
        }
        
        var operationState = FamilyOperationService.OperationState()
        operationState.processingMessage = processingMessage
        operationState.showJoinProcessing = showJoinProcessing
        operationState.joinSuccessMessage = joinSuccessMessage
        operationState.showJoinSuccess = showJoinSuccess
        
        let result = await FamilyOperationService.joinFamily(
            invitationCode: invitationCode, userId: userId,
            familyManager: familyManager, authManager: authManager,
            operationState: &operationState, isJoiningFamily: &isJoiningFamily,
            error: &error
        )
        
        processingMessage = operationState.processingMessage
        showJoinProcessing = operationState.showJoinProcessing
        joinSuccessMessage = operationState.joinSuccessMessage
        showJoinSuccess = operationState.showJoinSuccess
        
        return result
    }
    
    func resetSuccessStates() {
        var publishedState = FamilyViewModelState.PublishedState()
        publishedState.shouldDismissCreateSheet = shouldDismissCreateSheet
        publishedState.showJoinSuccess = showJoinSuccess
        publishedState.joinSuccessMessage = joinSuccessMessage
        publishedState.newFamilyInvitationCode = newFamilyInvitationCode
        publishedState.showCreateSuccess = showCreateSuccess
        publishedState.createSuccessMessage = createSuccessMessage
        publishedState.showCreateProcessing = showCreateProcessing
        publishedState.showJoinProcessing = showJoinProcessing
        publishedState.processingMessage = processingMessage
        
        FamilyStateService.resetSuccessStates(&publishedState)
        
        shouldDismissCreateSheet = publishedState.shouldDismissCreateSheet
        showJoinSuccess = publishedState.showJoinSuccess
        joinSuccessMessage = publishedState.joinSuccessMessage
        newFamilyInvitationCode = publishedState.newFamilyInvitationCode
        showCreateSuccess = publishedState.showCreateSuccess
        createSuccessMessage = publishedState.createSuccessMessage
        showCreateProcessing = publishedState.showCreateProcessing
        showJoinProcessing = publishedState.showJoinProcessing
        processingMessage = publishedState.processingMessage
    }
    
    func dismissCreateSheetWithReload() {
        shouldDismissCreateSheet = FamilyStateService.dismissCreateSheetWithReload()
    }
    
    func dismissJoinViewWithReload() {
        FamilyStateService.dismissJoinViewWithReload()
    }
    
    // MARK: - Private Business Logic
    
    private func setupFamilyManagerIfNeeded() async {
        await FamilyInitializationService.setupFamilyManagerIfNeeded(
            privateState: &privateState,
            familyManager: &familyManager,
            isInitialized: &isInitialized,
            setupBindingsCallback: { [weak self] in
                self?.setupBindings()
            }
        )
    }
    
    private func loadFamilies(for userId: String) async {
        await FamilyInitializationService.loadFamilies(for: userId, privateState: privateState)
    }
    
    // MARK: - Proxy Methods
    // FamilyManagerのメソッドをそのまま委譲するプロキシメソッド
    
    func removeAllListeners() {
        FamilyStateService.removeAllListeners(familyManager: familyManager)
    }
    
    func clearError() {
        FamilyStateService.clearError(familyManager: familyManager, error: &error)
    }
    
}