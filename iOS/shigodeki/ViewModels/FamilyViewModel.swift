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
    @Published var showCreateSuccess = false
    @Published var showJoinSuccess = false
    @Published var joinSuccessMessage = ""
    @Published var newFamilyInvitationCode: String?
    
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
        shouldShowEmptyState = !isLoading && families.isEmpty && authManager.currentUser?.id != nil
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
                
                // Small delay to let user see the optimistic family in list before success dialog
                Task {
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second
                    showCreateSuccess = true
                }
            }
            
            return true
            
        } catch {
            await MainActor.run {
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
        
        isJoiningFamily = true
        defer { isJoiningFamily = false }
        
        do {
            // Issue #43: Use optimistic updates for immediate family list reflection
            let familyName = try await familyManager.joinFamilyWithCodeOptimistic(invitationCode, userId: userId)
            
            await MainActor.run {
                joinSuccessMessage = "「\(familyName)」に参加しました！"
                showJoinSuccess = true
                print("✅ [Issue #43] FamilyViewModel: Successfully joined family: \(familyName) (optimistic)")
            }
            
            return true
            
        } catch {
            await MainActor.run {
                self.error = FirebaseError.from(error)
                print("❌ FamilyViewModel: Error joining family: \(error)")
            }
            return false
        }
    }
    
    func resetSuccessStates() {
        showCreateSuccess = false
        showJoinSuccess = false
        joinSuccessMessage = ""
        newFamilyInvitationCode = nil
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
}