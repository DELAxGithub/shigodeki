//
//  ProjectListViewModel.swift
//  shigodeki
//
//  Created by Claude on 2025-09-01.
//  [Foundation Consolidation] Phase 2.1: ViewModel as Data Proxy
//

import Foundation
import Combine

enum OwnerFilter: String, CaseIterable { 
    case all = "すべて"
    case individual = "個人" 
    case family = "家族"
}

@MainActor
class ProjectListViewModel: ObservableObject {
    // --- Output ---
    // Viewが購読するためのプロパティ
    @Published var projects: [Project] = []
    @Published var isLoading: Bool = false
    @Published var error: FirebaseError? = nil
    @Published var filteredProjects: [Project] = []
    @Published var ownerFilter: OwnerFilter = .all {
        didSet {
            applyFilter()
        }
    }
    @Published var bootstrapped = false
    @Published var isWaitingForAuth = false
    @Published var shouldShowEmptyState = false
    
    // --- Dependencies ---
    private let projectManager: ProjectManager
    private let authManager: AuthenticationManager
    private var cancellables = Set<AnyCancellable>()
    
    // --- Private Business Logic State ---
    private var retryCount = 0
    private let maxRetries = 3
    private var lastLoadTime: Date? = nil
    private let loadCooldownInterval: TimeInterval = 1.0
    private var lastAuthStateChange: Date? = nil
    private let authChangeCooldown: TimeInterval = 2.0
    
    // MARK: - Access to ProjectManager for Views that need it
    var projectManagerForViews: ProjectManager {
        return projectManager
    }

    init(projectManager: ProjectManager, authManager: AuthenticationManager) {
        self.projectManager = projectManager
        self.authManager = authManager

        // ProjectManagerからのデータストリームを購読し、自身のプロパティに中継する
        setupBindings()
        setupAuthenticationObserver()
    }

    private func setupBindings() {
        // projectManagerのprojectsを自身のprojectsに繋ぎ込む
        projectManager.$projects
            .receive(on: DispatchQueue.main)
            .sink { [weak self] projects in
                print("🔄 ProjectListViewModel: Projects updated to \(projects.count)")
                print("📋 ProjectListViewModel: Project names: \(projects.map { $0.name })")
                self?.projects = projects
                self?.applyFilter() // プロジェクトが更新されたらフィルタを再適用
            }
            .store(in: &cancellables)

        // projectManagerのisLoadingを自身のisLoadingに繋ぎ込む
        projectManager.$isLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLoading in
                self?.isLoading = isLoading
                self?.applyFilter() // isLoadingが変わったらempty stateも更新
            }
            .store(in: &cancellables)
        
        // projectManagerのerrorを自身のerrorに繋ぎ込む
        projectManager.$error
            .receive(on: DispatchQueue.main)
            .assign(to: &$error)
    }
    
    private func applyFilter() {
        switch ownerFilter {
        case .all: 
            filteredProjects = projects
        case .individual: 
            filteredProjects = projects.filter { $0.ownerType == .individual }
        case .family: 
            filteredProjects = projects.filter { $0.ownerType == .family }
        }
        
        // Update shouldShowEmptyState
        shouldShowEmptyState = bootstrapped && filteredProjects.isEmpty && !isLoading && !isWaitingForAuth
    }
    
    private func setupAuthenticationObserver() {
        authManager.$isAuthenticated
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isAuthenticated in
                self?.handleAuthStateChange(isAuthenticated)
            }
            .store(in: &cancellables)
    }
    
    private func handleAuthStateChange(_ isAuthenticated: Bool) {
        let now = Date()
        
        // 🆕 認証状態変更のデバウンス処理
        if let lastChange = lastAuthStateChange,
           now.timeIntervalSince(lastChange) < authChangeCooldown {
            #if DEBUG
            print("🚫 ProjectListViewModel: Auth state change ignored due to cooldown")
            #endif
            return
        }
        
        lastAuthStateChange = now
        
        #if DEBUG
        print("📱 ProjectListViewModel: Authentication state changed: \(isAuthenticated)")
        #endif
        
        if isAuthenticated {
            // 🔧 既にプロジェクトが読み込まれている場合は重複ロードを避ける
            if projects.isEmpty {
                #if DEBUG
                print("🔄 ProjectListViewModel: User authenticated, loading projects")
                #endif
                retryCount = 0
                loadUserProjectsWithDebounce()
            } else {
                #if DEBUG
                print("✅ ProjectListViewModel: Projects already loaded, skipping duplicate load")
                #endif
            }
        } else {
            // Reset states when user signs out
            retryCount = 0
            isWaitingForAuth = false
        }
    }
    
    // MARK: - Public Interface
    
    func onAppear() async {
        // Initialize managers when the view appears  
        #if DEBUG
        print("📱 ProjectListViewModel: onAppear triggered")
        #endif
        
        loadUserProjectsWithDebounce()
        bootstrapped = true
        applyFilter() // bootstrappedが変わったらempty stateも更新
    }
    
    func onDisappear() {
        #if DEBUG
        print("👋 ProjectListViewModel: Disappearing, cleaning up listeners")
        #endif
        removeAllListeners()
    }
    
    func deleteProjects(at offsets: IndexSet) {
        guard !projects.isEmpty else { return }
        
        let projectsToDelete = offsets.compactMap { index -> Project? in
            let projects = self.filteredProjects
            guard index < projects.count else { return nil }
            return projects[index]
        }
        
        for project in projectsToDelete {
            guard let projectId = project.id else { continue }
            
            Task {
                do {
                    try await deleteProject(id: projectId)
                } catch {
                    print("❌ ProjectListViewModel: Error deleting project: \(error)")
                    // Error is now handled through ViewModel's @Published error property
                }
            }
        }
    }
    
    func refreshProjects() async {
        // 🔧 修正: リアルタイムリスナーを使用しているため、手動リフレッシュは不要
        // Firebase リスナーが自動的にデータを更新するため、重複呼び出しを避ける
        print("🔄 ProjectListViewModel: Refresh requested - using real-time listener (no additional API call)")
        
        guard let userId = authManager.currentUser?.id else {
            print("⚠️ ProjectListViewModel: No authenticated user for refresh")
            return
        }
        
        // Force reload if needed
        loadUserProjects()
    }
    
    // MARK: - Private Business Logic (移動してきたメソッド)
    
    private func loadUserProjectsWithDebounce() {
        let now = Date()
        
        // クールダウン期間チェック
        if let lastLoad = lastLoadTime, now.timeIntervalSince(lastLoad) < loadCooldownInterval {
            #if DEBUG
            print("🚫 ProjectListViewModel: Load request ignored due to cooldown (last: \(lastLoad))")
            #endif
            return
        }
        
        lastLoadTime = now
        loadUserProjects()
    }
    
    private func loadUserProjects() {
        guard let userId = authManager.currentUser?.id else {
            isWaitingForAuth = true
            print("⚠️ ProjectListViewModel: No authenticated user yet, setting waiting state")
            return
        }
        
        isWaitingForAuth = false // Clear waiting state
        
        print("👤 ProjectListViewModel: Loading projects for user: \(userId)")
        
        Task {
            do {
                print("🔄 ProjectListViewModel: Starting project listener")
                self.startListeningForUserProjects(userId: userId)
                // 🔧 リスナーが設定されるとデータは自動的に受信されるため、getUserProjects呼び出しは不要
                
                await MainActor.run {
                    print("✨ ProjectListViewModel: Project listener started successfully")
                }
                retryCount = 0  // 成功時にリセット
            } catch {
                await MainActor.run {
                    retryCount += 1
                    print("❌ ProjectListViewModel: Error loading projects (attempt \(retryCount)/\(maxRetries)): \(error)")
                    
                    if retryCount < maxRetries {
                        let delay = exponentialBackoffDelay(for: retryCount - 1)
                        print("🔄 ProjectListViewModel: Retrying in \(delay) seconds...")
                        
                        Task {
                            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                            await MainActor.run {
                                self.loadUserProjects()  // Retry
                            }
                        }
                    } else {
                        print("💥 ProjectListViewModel: Max retries exceeded")
                        self.error = FirebaseError.from(error)
                    }
                }
            }
        }
    }
    
    private func exponentialBackoffDelay(for attempt: Int) -> TimeInterval {
        let baseDelay: TimeInterval = 1.0
        let maxDelay: TimeInterval = 16.0
        let delay = baseDelay * pow(2.0, Double(attempt))
        return min(delay, maxDelay)
    }
    
    // MARK: - Proxy Methods
    // ProjectManagerのメソッドをそのまま委譲するプロキシメソッド
    
    func removeAllListeners() {
        projectManager.removeAllListeners()
    }
    
    func startListeningForUserProjects(userId: String) {
        projectManager.startListeningForUserProjects(userId: userId)
    }
    
    func deleteProject(id: String) async throws {
        do {
            try await projectManager.deleteProject(id: id)
        } catch {
            await MainActor.run {
                self.error = FirebaseError.from(error)
            }
            throw error
        }
    }
    
    func clearError() {
        projectManager.error = nil
    }
}