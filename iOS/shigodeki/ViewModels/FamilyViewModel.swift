//
//  FamilyViewModel.swift
//  shigodeki
//
//  Created by Claude on 2025-09-01.
//  [Pattern Propagation] Applying the golden pattern from ProjectListViewModel
//

import Foundation
import Combine

@MainActor
class FamilyViewModel: ObservableObject {
    // --- Output ---
    // Viewが購読するためのプロパティ
    @Published var families: [Family] = []
    @Published var isLoading: Bool = false
    @Published var error: FirebaseError? = nil
    @Published var shouldShowEmptyState = false
    
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
    
    // --- Dependencies ---
    private let familyManager: FamilyManager
    private let authManager: AuthenticationManager
    private var cancellables = Set<AnyCancellable>()
    
    // --- Private Business Logic State ---
    // Currently minimal, but ready for expansion
    
    // MARK: - Access to Managers for Views that need it
    var familyManagerForViews: FamilyManager {
        return familyManager
    }
    
    var authManagerForViews: AuthenticationManager {
        return authManager
    }

    init(familyManager: FamilyManager, authManager: AuthenticationManager) {
        self.familyManager = familyManager
        self.authManager = authManager

        // FamilyManagerからのデータストリームを購読し、自身のプロパティに中継する
        setupBindings()
    }

    private func setupBindings() {
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
    }
    
    private func updateEmptyState() {
        // Empty state logic: show when not loading and no families exist
        let newEmptyState = !isLoading && families.isEmpty && authManager.currentUser?.id != nil
        print("🔍 [DEBUG] updateEmptyState: loading=\(isLoading), familiesEmpty=\(families.isEmpty), userId=\(authManager.currentUser?.id ?? "nil") → shouldShowEmptyState=\(newEmptyState)")
        shouldShowEmptyState = newEmptyState
    }
    
    // MARK: - Public Interface
    
    func onAppear() async {
        // Initialize when view appears  
        #if DEBUG
        print("📱 FamilyViewModel: onAppear triggered")
        #endif
        
        await loadFamilies()
    }
    
    func onDisappear() {
        #if DEBUG
        print("👋 FamilyViewModel: Disappearing, cleaning up listeners")
        #endif
        familyManager.stopListeningToFamilies()
    }
    
    func createFamily(name: String) async -> Bool {
        guard let userId = authManager.currentUser?.id else {
            error = FirebaseError.operationFailed("ユーザーが認証されていません")
            return false
        }
        
        // Show processing popup immediately
        await MainActor.run {
            processingMessage = "家族グループを作成中..."
            showCreateProcessing = true
            print("🔄 [Debug] showCreateProcessing set to true")
        }
        
        // Give UI time to show the processing popup (minimum 500ms)
        try? await Task.sleep(nanoseconds: 500_000_000) // 500ms
        
        isCreatingFamily = true
        defer { isCreatingFamily = false }
        
        do {
            let familyId = try await familyManager.createFamily(name: name, creatorUserId: userId)
            // Get the invitation code - for now we'll generate a simple one
            let invitationCode = "INV\(String(familyId.suffix(6)))"
            
            await MainActor.run {
                newFamilyInvitationCode = invitationCode
                print("✅ [Issue #42] FamilyViewModel: Family created with optimistic update - ID: \(familyId)")
                print("📋 [Issue #42] Families array count: \(familyManager.families.count)")
                
                // Switch to success message in the same popup
                processingMessage = "家族グループが作成されました！"
                showCreateSuccess = true
                print("✅ [Debug] showCreateSuccess set to true, showCreateProcessing: \(showCreateProcessing)")
                
                // CRUCIAL: Refresh Firebase data in background immediately after success
                // This ensures the family appears in the list when user presses OK
                if let userId = authManager.currentUser?.id {
                    print("🔄 [Background] Refreshing Firebase listener after family creation")
                    familyManager.startListeningToFamilies(userId: userId)
                }
            }
            
            return true
            
        } catch {
            await MainActor.run {
                showCreateProcessing = false
                self.error = FirebaseError.from(error)
                print("❌ FamilyViewModel: Error creating family: \(error)")
            }
            return false
        }
    }
    
    func joinFamily(invitationCode: String) async -> Bool {
        guard let userId = authManager.currentUser?.id else {
            error = FirebaseError.operationFailed("ユーザーが認証されていません")
            return false
        }
        
        // Show processing popup immediately  
        await MainActor.run {
            processingMessage = "家族グループに参加中..."
            showJoinProcessing = true
            print("🔄 [Debug] showJoinProcessing set to true")
        }
        
        // Give UI time to show the processing popup (minimum 500ms)
        try? await Task.sleep(nanoseconds: 500_000_000) // 500ms
        
        isJoiningFamily = true
        defer { isJoiningFamily = false }
        
        do {
            // Issue #43: Use optimistic updates for immediate family list reflection
            let familyName = try await familyManager.joinFamilyWithCodeOptimistic(invitationCode, userId: userId)
            
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
        // Firebase refresh is already done in background during success message
        print("✅ [UI] Dismissing create sheet - Firebase data already refreshed")
    }
    
    func dismissJoinViewWithReload() {
        // Firebase refresh is already done in background during success message  
        print("✅ [UI] Dismissing join view - Firebase data already refreshed")
    }
    
    // MARK: - Private Business Logic
    
    private func loadFamilies() async {
        guard let userId = authManager.currentUser?.id else {
            print("⚠️ FamilyViewModel: No authenticated user yet")
            return
        }
        
        print("👤 FamilyViewModel: Loading families for user: \(userId)")
        
        // Start real-time listening instead of just loading
        familyManager.startListeningToFamilies(userId: userId)
        print("✨ FamilyViewModel: Started listening to families for user")
    }
    
    // MARK: - Proxy Methods
    // FamilyManagerのメソッドをそのまま委譲するプロキシメソッド
    
    func removeAllListeners() {
        familyManager.stopListeningToFamilies()
    }
    
    func clearError() {
        familyManager.errorMessage = nil
        error = nil
    }
    
    // MARK: - DEBUG: Simple test methods to verify alert display
    
    func triggerTestCreateProcessingAlert() {
        print("🧪 [DEBUG] FamilyViewModel: triggerTestCreateProcessingAlert called")
        processingMessage = "テスト処理中..."
        showCreateProcessing = true
        
        // After 2 seconds, switch to success
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.processingMessage = "テスト成功！"
            self?.showCreateSuccess = true
            print("🧪 [DEBUG] FamilyViewModel: Switched to success state after 2 seconds")
        }
    }
    
    func triggerTestJoinProcessingAlert() {
        print("🧪 [DEBUG] FamilyViewModel: triggerTestJoinProcessingAlert called")
        processingMessage = "テスト参加中..."
        showJoinProcessing = true
        
        // After 2 seconds, switch to success
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.joinSuccessMessage = "テスト参加成功！"
            self?.showJoinSuccess = true
            print("🧪 [DEBUG] FamilyViewModel: Switched to join success state after 2 seconds")
        }
    }
}