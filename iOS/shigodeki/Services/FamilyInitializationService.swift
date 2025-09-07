//
//  FamilyInitializationService.swift
//  shigodeki
//
//  Created by Claude on 2025-09-06.
//

import Foundation
import Combine

struct FamilyInitializationService {
    // MARK: - Authentication Observer Setup
    
    @MainActor
    static func setupAuthenticationObserver(
        authManager: AuthenticationManager?,
        userChangeHandler: @escaping (User?) -> Void
    ) -> AnyCancellable? {
        return authManager?.$currentUser
            .removeDuplicates()
            .sink { user in
                userChangeHandler(user)
            }
    }
    
    // MARK: - User Change Handling
    
    @MainActor
    static func handleUserChange(
        user: User?,
        familyManager: FamilyManager?,
        families: inout [Family],
        setupFamilyManagerCallback: @escaping () async -> Void,
        loadFamiliesCallback: @escaping (String) async -> Void
    ) {
        if let user = user, let userId = user.id {
            print("🔄 FamilyViewModel: 認証ユーザー変更を検知。ユーザーID: \(userId)。データロードを開始します。")
            Task {
                // Managerがまだ注入されていない場合は待機する
                await setupFamilyManagerCallback()
                await loadFamiliesCallback(userId)
            }
        } else {
            print("🔄 FamilyViewModel: ユーザーがサインアウトしました。データをクリアします。")
            families = []
            familyManager?.stopListeningToFamilies()
        }
    }
    
    // MARK: - Manager Bindings Setup
    
    @MainActor
    static func setupBindings(
        familyManager: FamilyManager,
        familiesBinding: @escaping ([Family]) -> Void,
        isLoadingBinding: @escaping (Bool) -> Void,
        errorBinding: @escaping (String?) -> Void,
        updateEmptyStateCallback: @escaping () -> Void
    ) -> [AnyCancellable] {
        var cancellables: [AnyCancellable] = []
        
        // familyManagerのfamiliesを自身のfamiliesに繋ぎ込む
        familyManager.$families
            .receive(on: DispatchQueue.main)
            .sink { families in
                print("🔄 FamilyViewModel: Families updated to \(families.count)")
                print("📋 FamilyViewModel: Family names: \(families.map { $0.name })")
                familiesBinding(families)
                updateEmptyStateCallback()
            }
            .store(in: &cancellables)

        // familyManagerのisLoadingを自身のisLoadingに繋ぎ込む
        familyManager.$isLoading
            .receive(on: DispatchQueue.main)
            .sink { isLoading in
                isLoadingBinding(isLoading)
                updateEmptyStateCallback()
            }
            .store(in: &cancellables)
        
        // familyManagerのerrorMessageを自身のerrorに変換して繋ぎ込む
        familyManager.$errorMessage
            .receive(on: DispatchQueue.main)
            .sink { errorMessage in
                errorBinding(errorMessage)
            }
            .store(in: &cancellables)
            
        print("🔗 FamilyViewModel: Manager bindingsが確立されました")
        return cancellables
    }
    
    // MARK: - Initial Data Loading
    
    static func loadInitialData(
        authManager: AuthenticationManager?,
        familyManager: FamilyManager?
    ) async {
        guard let authManager = authManager,
              let familyManager = familyManager,
              let userId = await authManager.currentUser?.id else {
            print("⚠️ FamilyViewModel: loadInitialData() - 必要なManagerまたはユーザーIDが不足")
            return
        }
        
        print("🔄 FamilyViewModel: 初期データ読み込み開始 - User: \(userId)")
        
        // 家族データの読み込みを開始
        await familyManager.startListeningToFamilies(userId: userId)
        print("✨ FamilyViewModel: 家族データのリスニングを開始")
    }
    
    // MARK: - Manager Setup
    
    @MainActor
    static func setupFamilyManagerIfNeeded(
        privateState: inout FamilyViewModelState.PrivateState,
        familyManager: inout FamilyManager?,
        isInitialized: inout Bool,
        setupBindingsCallback: @escaping () -> Void
    ) async {
        guard privateState.familyManager == nil else { return }
        print("⏳ FamilyViewModel: FamilyManagerが未注入のため、SharedManagerStoreから取得します。")
        privateState.familyManager = await SharedManagerStore.shared.getFamilyManager()
        familyManager = privateState.familyManager
        setupBindingsCallback() // Managerが注入されたので、バインディングを再設定
        isInitialized = true
        print("✅ FamilyViewModel: FamilyManagerの注入が完了しました。")
    }
    
    // MARK: - Family Loading
    
    static func loadFamilies(
        for userId: String,
        privateState: FamilyViewModelState.PrivateState
    ) async {
        guard let familyManager = privateState.familyManager else {
            print("⚠️ FamilyViewModel: Manager not available for loadFamilies")
            return
        }
        
        print("👤 FamilyViewModel: 家族データの読み込みを開始 - User: \(userId)")
        
        // Start real-time listening instead of just loading
        await familyManager.startListeningToFamilies(userId: userId)
        print("✨ FamilyViewModel: Started listening to families for user")
    }
}