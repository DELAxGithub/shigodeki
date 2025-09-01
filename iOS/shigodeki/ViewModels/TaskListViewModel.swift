//
//  TaskListViewModel.swift
//  shigodeki
//
//  Created by Claude on 2025-09-01.
//  [Operation: Unification] Applying the golden pattern from ProjectListViewModel and FamilyViewModel
//

import Foundation
import Combine

@MainActor
class TaskListViewModel: ObservableObject {
    // --- Output ---
    // Viewが購読するためのプロパティ
    @Published var families: [Family] = []
    @Published var selectedFamily: Family? = nil
    @Published var isLoading: Bool = false
    @Published var error: FirebaseError? = nil
    @Published var bootstrapped = false
    @Published var shouldShowEmptyState = false
    @Published var shouldShowNoFamiliesState = false
    @Published var shouldShowFamilySelection = false
    @Published var shouldShowTaskLists = false
    
    // UI State
    @Published var showingCreateTaskList = false
    @Published var showingQuickAIGeneration = false
    @Published var showingAISettings = false
    
    // --- Dependencies ---
    private let familyManager: FamilyManager
    private let authManager: AuthenticationManager
    private var cancellables = Set<AnyCancellable>()
    
    // --- Private Business Logic State ---
    private var retryCount = 0
    private let maxRetries = 3
    private var lastLoadTime: Date? = nil
    private let loadCooldownInterval: TimeInterval = 1.0
    
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
        setupAuthenticationObserver()
    }

    private func setupBindings() {
        // familyManagerのfamiliesを自身のfamiliesに繋ぎ込む
        familyManager.$families
            .receive(on: DispatchQueue.main)
            .sink { [weak self] families in
                print("🔄 TaskListViewModel: Families updated to \(families.count)")
                print("📋 TaskListViewModel: Family names: \(families.map { $0.name })")
                self?.families = families
                self?.updateViewState()
            }
            .store(in: &cancellables)

        // familyManagerのisLoadingを自身のisLoadingに繋ぎ込む
        familyManager.$isLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLoading in
                self?.isLoading = isLoading
                self?.updateViewState()
            }
            .store(in: &cancellables)
        
        // familyManagerのerrorMessageを自身のerrorに変換して繋ぎ込む
        familyManager.$errorMessage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] errorMessage in
                if let errorMessage = errorMessage {
                    self?.error = FirebaseError.operationFailed(errorMessage)
                } else if self?.error != nil {
                    // Only clear if it was a family manager error
                    self?.error = nil
                }
            }
            .store(in: &cancellables)
    }
    
    private func updateViewState() {
        // State machine logic based on current data
        guard bootstrapped else {
            shouldShowEmptyState = false
            shouldShowNoFamiliesState = false
            shouldShowFamilySelection = false
            shouldShowTaskLists = false
            return
        }
        
        if families.isEmpty && !isLoading {
            // No families - show empty state
            shouldShowNoFamiliesState = true
            shouldShowFamilySelection = false
            shouldShowTaskLists = false
            shouldShowEmptyState = false
        } else if selectedFamily != nil {
            // Family selected - show task lists
            shouldShowNoFamiliesState = false
            shouldShowFamilySelection = false
            shouldShowTaskLists = true
            shouldShowEmptyState = true // Simplified - always show empty for now
        } else if !families.isEmpty {
            // Families available - show selection
            shouldShowNoFamiliesState = false
            shouldShowFamilySelection = true
            shouldShowTaskLists = false
            shouldShowEmptyState = false
        } else {
            shouldShowEmptyState = false
            shouldShowNoFamiliesState = false
            shouldShowFamilySelection = false
            shouldShowTaskLists = false
        }
    }
    
    private func setupAuthenticationObserver() {
        authManager.$currentUser
            .compactMap { $0?.id }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] userId in
                self?.handleUserAuthChange(userId: userId)
            }
            .store(in: &cancellables)
    }
    
    private func handleUserAuthChange(userId: String) {
        #if DEBUG
        print("📱 TaskListViewModel: User authentication changed: \(userId)")
        #endif
        
        // Reset state
        selectedFamily = nil
        retryCount = 0
        
        // Load user's families
        loadUserData(userId: userId)
        bootstrapped = true
        updateViewState()
    }

    // MARK: - Public Interface
    
    func onAppear() async {
        // Initialize when the view appears  
        #if DEBUG
        print("📱 TaskListViewModel: onAppear triggered")
        #endif
        
        if let userId = authManager.currentUser?.id {
            loadUserData(userId: userId)
            bootstrapped = true
            updateViewState()
        }
    }
    
    func onDisappear() {
        #if DEBUG
        print("👋 TaskListViewModel: Disappearing, cleaning up listeners")
        #endif
        familyManager.stopListeningToFamilies()
    }
    
    func selectFamily(_ family: Family) {
        selectedFamily = family
        updateViewState()
    }
    
    func deselectFamily() {
        selectedFamily = nil
        updateViewState()
    }
    
    // MARK: - UI Actions
    
    func showCreateTaskList() {
        showingCreateTaskList = true
    }
    
    func hideCreateTaskList() {
        showingCreateTaskList = false
    }
    
    func showQuickAIGeneration() {
        showingQuickAIGeneration = true
    }
    
    func hideQuickAIGeneration() {
        showingQuickAIGeneration = false
    }
    
    func showAISettings() {
        showingAISettings = true
    }
    
    func hideAISettings() {
        showingAISettings = false
    }
    
    func handleAIAction(availableProviders: [KeychainManager.APIProvider]) {
        if availableProviders.isEmpty {
            showAISettings()
        } else {
            showQuickAIGeneration()
        }
    }
    
    // MARK: - Private Business Logic
    
    private func loadUserData(userId: String) {
        print("👤 TaskListViewModel: Loading user data for: \(userId)")
        
        // Start listening to families
        familyManager.startListeningToFamilies(userId: userId)
        
        // Also load families explicitly in case listener doesn't fire immediately
        Task {
            await familyManager.loadFamiliesForUser(userId: userId)
        }
    }
    
    // MARK: - Proxy Methods
    // Manager メソッドをそのまま委譲するプロキシメソッド
    
    func clearError() {
        familyManager.errorMessage = nil
        error = nil
    }
}