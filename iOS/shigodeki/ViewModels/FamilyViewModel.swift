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
    @Published var isWaitingForAuth = false
    @Published var bootstrapped = false
    
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
    init(authManager: AuthenticationManager? = nil) {
        print("⚡ FamilyViewModel: 同期初期化開始")
        let manager = authManager ?? AuthenticationManager.shared
        self.privateState.authManager = manager
        self.authManager = manager
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
        if let user = user, let userId = user.id {
            print("🔄 FamilyViewModel: 認証ユーザー変更を検知。ユーザーID: \(userId)。データロードを開始します。")
            isWaitingForAuth = false
            Task { [weak self] in
                await self?.setupFamilyManagerIfNeeded()
                await self?.loadFamilies(for: userId)
                await MainActor.run { self?.bootstrapped = true }
            }
        } else {
            print("🔄 FamilyViewModel: ユーザーがサインアウトしました。データをクリアします。")
            self.families = []
            self.familyManager?.stopListeningToFamilies()
            isWaitingForAuth = true
            bootstrapped = true // Bootstrap is complete, even if logged out.
        }
        updateEmptyState()
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
        
        FamilyStateService.updateEmptyState(publishedState: &publishedState, authManager: authManager)
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
        
        // Handle duplicate prevention directly
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            error = FirebaseError.operationFailed("ファミリー名を入力してください")
            return false
        }
        
        // Check for duplicate requests
        if FamilyOperationService.shouldBlockCreateRequest(
            trimmedName: trimmedName,
            userId: userId,
            activeRequests: privateState.activeCreateRequests,
            lastRequest: privateState.lastCreateRequest
        ) {
            return false
        }
        
        // Track request and start loading
        let requestKey = FamilyOperationService.createRequestKey(userId: userId, familyName: trimmedName)
        privateState.activeCreateRequests.insert(requestKey)
        privateState.lastCreateRequest = (name: trimmedName, timestamp: Date())
        
        isCreatingFamily = true
        operationState.showCreateProcessing = true
        operationState.processingMessage = "ファミリーを作成中..."
        
        // Optimistic update
        let optimisticFamily = FamilyOperationService.createOptimisticFamily(name: trimmedName, userId: userId)
        operationState.families.append(optimisticFamily)
        
        defer {
            isCreatingFamily = false
            operationState.showCreateProcessing = false
            privateState.activeCreateRequests.remove(requestKey)
        }
        
        do {
            let (familyId, inviteCode) = try await familyManager.createFamily(
                name: trimmedName,
                creatorUserId: userId
            )
            
            // Update optimistic family with real ID
            if let index = operationState.families.firstIndex(where: { $0.id == optimisticFamily.id }) {
                operationState.families[index].id = familyId
            }
            
            // Use the real invitation code if available, otherwise generate locally
            if let inviteCode = inviteCode {
                operationState.newFamilyInvitationCode = inviteCode
                print("✅ Using server-generated invitation code: \(inviteCode)")
            } else {
                operationState.newFamilyInvitationCode = FamilyOperationService.generateInvitationCode(from: familyId)
                print("⚠️ Using locally generated invitation code, server generation failed")
            }
            
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
        
        families = operationState.families
        showCreateSuccess = operationState.showCreateSuccess
        showCreateProcessing = operationState.showCreateProcessing
        processingMessage = operationState.processingMessage
        newFamilyInvitationCode = operationState.newFamilyInvitationCode
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
        
        // Handle join family with input normalization
        let normalizedCode: String
        do {
            normalizedCode = try InvitationCodeNormalizer.normalize(invitationCode)
        } catch {
            self.error = FirebaseError.operationFailed("無効な招待コード: \(error.localizedDescription)")
            return false
        }
        
        print("🔄 FamilyViewModel: Join family button tapped")
        print("🔍 FamilyViewModel: Original code: '\(invitationCode)', normalized: '\(normalizedCode)'")
        
        guard !normalizedCode.isEmpty else {
            let errorMessage = "招待コードを入力してください"
            error = FirebaseError.operationFailed(errorMessage)
            print("❌ FamilyViewModel: \(errorMessage)")
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
            print("⏳ FamilyViewModel: Starting join process with normalizedCode=\(normalizedCode), userId=\(userId)")
            let familyName = try await familyManager.joinFamilyWithCode(normalizedCode, userId: userId)
            
            // Show success message
            operationState.showJoinSuccess = true
            operationState.joinSuccessMessage = "'\(familyName)'に参加しました！"
            
            // Refresh families after successful join
            await familyManager.startListeningToFamilies(userId: userId)
            
            print("✅ FamilyViewModel: Join success familyId=..., added member uid=\(userId)")
            return true
            
        } catch {
            let errorMessage: String
            if let familyError = error as? FamilyError {
                errorMessage = familyError.localizedDescription
                print("❌ FamilyViewModel: Join failed - \(familyError)")
            } else if let firebaseError = error as? FirebaseError {
                errorMessage = firebaseError.localizedDescription
                self.error = firebaseError
                print("❌ FamilyViewModel: Join failed - Firebase error: \(firebaseError)")
            } else {
                errorMessage = "ファミリーへの参加に失敗しました: \(error.localizedDescription)"
                self.error = FirebaseError.operationFailed(errorMessage)
                print("❌ FamilyViewModel: Join failed - Unknown error: \(error)")
            }
            
            // Set appropriate error for UI display
            if error is FamilyError {
                self.error = FirebaseError.operationFailed(errorMessage)
            }
            
            return false
        }
        
        processingMessage = operationState.processingMessage
        showJoinProcessing = operationState.showJoinProcessing
        joinSuccessMessage = operationState.joinSuccessMessage
        showJoinSuccess = operationState.showJoinSuccess
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
        
        FamilyStateService.resetSuccessStates(publishedState: &publishedState)
        
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
        guard privateState.familyManager == nil else { return }
        print("⏳ FamilyViewModel: FamilyManagerが未注入のため、SharedManagerStoreから取得します。")
        privateState.familyManager = await SharedManagerStore.shared.getFamilyManager()
        familyManager = privateState.familyManager
        setupBindings() // Managerが注入されたので、バインディングを再設定
        isInitialized = true
        print("✅ FamilyViewModel: FamilyManagerの注入が完了しました。")
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
