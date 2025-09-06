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
        authManager?.$currentUser
            .removeDuplicates()
            .sink { [weak self] user in
                self?.handleUserChange(user)
            }
            .store(in: &cancellables)
    }
    
    /// **【重要】認証状態変化ハンドラー**
    /// ViewModelが自律的に認証状態を監視し、適切なタイミングでデータロードを実行
    private func handleUserChange(_ user: User?) {
        if let user = user, let userId = user.id {
            print("🔄 FamilyViewModel: 認証ユーザー変更を検知。ユーザーID: \(userId)。データロードを開始します。")
            Task {
                // Managerがまだ注入されていない場合は待機する
                await setupFamilyManagerIfNeeded()
                await loadFamilies(for: userId)
            }
        } else {
            print("🔄 FamilyViewModel: ユーザーがサインアウトしました。データをクリアします。")
            self.families = []
            self.familyManager?.stopListeningToFamilies()
        }
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
        
        // familyManagerのfamiliesを自身のfamiliesに繋ぎ込む
        familyManager.$families
            .receive(on: DispatchQueue.main)
            .sink { [weak self] families in
                print("🔄 FamilyViewModel: Families updated to \(families.count)")
                print("📋 FamilyViewModel: Family names: \(families.map { $0.name })")
                self?.families = families
                self?.updateEmptyState()
            }
            .store(in: &cancellables)

        // familyManagerのisLoadingを自身のisLoadingに繋ぎ込む
        familyManager.$isLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLoading in
                self?.isLoading = isLoading
                self?.updateEmptyState()
            }
            .store(in: &cancellables)
        
        // familyManagerのerrorMessageを自身のerrorに変換して繋ぎ込む
        familyManager.$errorMessage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] errorMessage in
                if let errorMessage = errorMessage {
                    self?.error = FirebaseError.operationFailed(errorMessage)
                } else {
                    self?.error = nil
                }
            }
            .store(in: &cancellables)
            
        print("🔗 FamilyViewModel: Manager bindingsが確立されました")
    }
    
    private func loadInitialData() async {
        guard let authManager = authManager,
              let familyManager = familyManager,
              let userId = authManager.currentUser?.id else {
            print("⚠️ FamilyViewModel: loadInitialData() - 必要なManagerまたはユーザーIDが不足")
            return
        }
        
        print("🔄 FamilyViewModel: 初期データ読み込み開始 - User: \(userId)")
        
        // 家族データの読み込みを開始
        familyManager.startListeningToFamilies(userId: userId)
        print("✨ FamilyViewModel: 家族データのリスニングを開始")
    }
    
    private func updateEmptyState() {
        var publishedState = FamilyViewModelState.PublishedState()
        publishedState.isLoading = isLoading
        publishedState.families = families
        
        FamilyViewModelState.updateEmptyState(&publishedState, authManager: authManager)
        shouldShowEmptyState = publishedState.shouldShowEmptyState
    }
    
    // MARK: - Public Interface
    
    func onAppear() async {
        #if DEBUG
        print("📱 FamilyViewModel: onAppear triggered")
        #endif
        // 認証状態の変更によって自動的にロードされるため、ここでの明示的なロードは不要
    }
    
    func onDisappear() {
        guard let familyManager = familyManager else { return }
        
        #if DEBUG
        print("👋 FamilyViewModel: Disappearing, cleaning up listeners")
        #endif
        familyManager.stopListeningToFamilies()
    }
    
    func createFamily(name: String) async -> Bool {
        guard let authManager = authManager,
              let familyManager = familyManager else {
            error = FirebaseError.operationFailed("システムが準備できていません")
            return false
        }
        
        guard let userId = authManager.currentUser?.id else {
            error = FirebaseError.operationFailed("ユーザーが認証されていません")
            return false
        }
        
        // Duplicate prevention checks
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if FamilyOperationService.shouldBlockCreateRequest(
            trimmedName: trimmedName,
            userId: userId,
            activeRequests: privateState.activeCreateRequests,
            lastRequest: privateState.lastCreateRequest
        ) {
            return false
        }
        
        // Track this request
        let requestKey = FamilyOperationService.createRequestKey(userId: userId, familyName: trimmedName)
        privateState.activeCreateRequests.insert(requestKey)
        privateState.lastCreateRequest = (name: trimmedName, timestamp: Date())
        
        defer {
            // Always clean up the active request tracking
            privateState.activeCreateRequests.remove(requestKey)
        }
        
        // 🚨 CTO修正: 楽観的更新 (Optimistic Update)
        let optimisticFamily = FamilyOperationService.createOptimisticFamily(name: trimmedName, userId: userId)
        let temporaryId = optimisticFamily.id!
        
        await MainActor.run {
            // @Publishedなfamilies配列に直接追加することで、UIが即座に更新される
            families.insert(optimisticFamily, at: 0)
            print("✅ [OPTIMISTIC] FamilyViewModel: Added temporary family '\(trimmedName)' to UI.")
            
            // 成功を即座に表示
            showCreateSuccess = true
            processingMessage = "家族グループが作成されました！"
        }
        
        isCreatingFamily = true
        defer { isCreatingFamily = false }
        
        do {
            print("🔥 [FIREBASE] FamilyViewModel: Starting Firebase createFamily operation for '\(trimmedName)'")
            let familyId = try await familyManager.createFamily(name: trimmedName, creatorUserId: userId)
            print("✅ [SUCCESS] FamilyViewModel: Firebase operation for createFamily completed successfully. ID: \(familyId)")
            
            // Get the invitation code
            let invitationCode = FamilyOperationService.generateInvitationCode(from: familyId)
            
            await MainActor.run {
                newFamilyInvitationCode = invitationCode
                print("✅ [OPTIMISTIC] FamilyViewModel: Firebase confirmed family creation - ID: \(familyId)")
                
                // 🚨 CTO修正: 固定遅延を完全に撤廃。
                // Firestoreリスナーが本物のデータを受信し、UIは自動的に更新される。
                // ユーザーが「OK」を押したタイミングで画面を閉じる。
            }
            
            return true
            
        } catch let error as NSError where error.domain == "FIRFirestoreErrorDomain" {
            // 🚨 CTO修正: 楽観的更新のロールバック
            await MainActor.run {
                FamilyErrorHandler.performOptimisticRollback(
                    families: &families,
                    temporaryId: temporaryId,
                    familyName: trimmedName,
                    showCreateSuccess: &showCreateSuccess,
                    showCreateProcessing: &showCreateProcessing,
                    processingMessage: &processingMessage
                )
                
                self.error = FamilyErrorHandler.handleFirestoreError(error)
            }
            return false
            
        } catch let error as NSError {
            // 🚨 CTO修正: 楽観的更新のロールバック
            await MainActor.run {
                FamilyErrorHandler.performOptimisticRollback(
                    families: &families,
                    temporaryId: temporaryId,
                    familyName: trimmedName,
                    showCreateSuccess: &showCreateSuccess,
                    showCreateProcessing: &showCreateProcessing,
                    processingMessage: &processingMessage
                )
                
                self.error = FamilyErrorHandler.handleNSError(error)
            }
            return false
            
        } catch {
            // 🚨 CTO修正: 楽観的更新のロールバック
            await MainActor.run {
                FamilyErrorHandler.performOptimisticRollback(
                    families: &families,
                    temporaryId: temporaryId,
                    familyName: trimmedName,
                    showCreateSuccess: &showCreateSuccess,
                    showCreateProcessing: &showCreateProcessing,
                    processingMessage: &processingMessage
                )
                
                self.error = FamilyErrorHandler.handleUnknownError(error)
            }
            return false
        }
    }
    
    func joinFamily(invitationCode: String) async -> Bool {
        guard let authManager = authManager,
              let familyManager = familyManager else {
            error = FirebaseError.operationFailed("システムが準備できていません")
            return false
        }
        
        guard let userId = authManager.currentUser?.id else {
            error = FirebaseError.operationFailed("ユーザーが認証されていません")
            return false
        }
        
        // 🚨 CTO修正: 楽観的更新パターンの適用
        // 500ms遅延を撤廃し、即座に楽観的な参加状態を表示
        await MainActor.run {
            processingMessage = "家族グループに参加中..."
            showJoinProcessing = true
            print("🔄 [OPTIMISTIC] showJoinProcessing set to true")
        }
        
        isJoiningFamily = true
        defer { isJoiningFamily = false }
        
        do {
            // Issue #43: Use optimistic updates for immediate family list reflection
            let familyName = try await familyManager.joinFamilyWithCode(invitationCode, userId: userId)
            
            await MainActor.run {
                // Switch to success message in the same popup
                processingMessage = "「\(familyName)」に参加しました！"
                joinSuccessMessage = "「\(familyName)」に参加しました！"
                showJoinSuccess = true
                print("✅ [Issue #43] FamilyViewModel: Successfully joined family: \(familyName) (optimistic)")
                print("✅ [Debug] showJoinSuccess set to true, showJoinProcessing: \(showJoinProcessing)")
                
                // CRUCIAL: Refresh Firebase data in background immediately after success
                // This ensures the family appears in the list when user presses OK
                if let userId = authManager.currentUser?.id {
                    print("🔄 [Background] Refreshing Firebase listener after family join")
                    familyManager.startListeningToFamilies(userId: userId)
                }
            }
            
            return true
            
        } catch {
            await MainActor.run {
                showJoinProcessing = false
                self.error = FirebaseError.from(error)
                print("❌ FamilyViewModel: Error joining family: \(error)")
            }
            return false
        }
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
        
        FamilyViewModelState.resetSuccessStates(&publishedState)
        
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
        shouldDismissCreateSheet = true
        // Firebase refresh is already done in background during success message
        print("✅ [UI] Dismissing create sheet - Firebase data already refreshed")
    }
    
    func dismissJoinViewWithReload() {
        // Firebase refresh is already done in background during success message  
        print("✅ [UI] Dismissing join view - Firebase data already refreshed")
    }
    
    // MARK: - Private Business Logic
    
    private func setupFamilyManagerIfNeeded() async {
        guard self.privateState.familyManager == nil else { return }
        print("⏳ FamilyViewModel: FamilyManagerが未注入のため、SharedManagerStoreから取得します。")
        self.privateState.familyManager = await SharedManagerStore.shared.getFamilyManager()
        self.familyManager = privateState.familyManager
        setupBindings() // Managerが注入されたので、バインディングを再設定
        self.isInitialized = true
        print("✅ FamilyViewModel: FamilyManagerの注入が完了しました。")
    }
    
    private func loadFamilies(for userId: String) async {
        guard let familyManager = self.privateState.familyManager else {
            print("⚠️ FamilyViewModel: Manager not available for loadFamilies")
            return
        }
        
        print("👤 FamilyViewModel: 家族データの読み込みを開始 - User: \(userId)")
        
        // Start real-time listening instead of just loading
        familyManager.startListeningToFamilies(userId: userId)
        print("✨ FamilyViewModel: Started listening to families for user")
    }
    
    // MARK: - Proxy Methods
    // FamilyManagerのメソッドをそのまま委譲するプロキシメソッド
    
    func removeAllListeners() {
        guard let familyManager = familyManager else { return }
        familyManager.stopListeningToFamilies()
    }
    
    func clearError() {
        guard let familyManager = familyManager else { return }
        familyManager.errorMessage = nil
        error = nil
    }
    
    // MARK: - DEBUG: Test methods removed
    // 🚨 CTO修正: デバッグメソッドを削除 - 2秒遅延の不適切なテストメソッドを撤廃
    // 本番コードにテスト用の固定遅延を含めることは、パフォーマンス劣化の原因となるため禁止
}