//
//  ProjectListViewModel.swift
//  shigodeki
//
//  Created by Claude on 2025-09-01.
//  [Foundation Consolidation] Phase 2.1: ViewModel as Data Proxy
//

import Foundation
import Combine
import SwiftUI

enum OwnerFilter: String, CaseIterable { 
    case all = "すべて"
    case individual = "個人" 
    case family = "チーム"
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
    @Published var showError = false
    
    // iPad NavigationSplitView selection
    @Published var selectedProject: Project? {
        didSet {
            if let project = selectedProject {
                // Preload project-specific data when selected
                Task.detached(priority: .userInitiated) { [weak self] in
                    await self?.preloadProjectData(project)
                }
            }
        }
    }
    
    /// マネージャーが注入され、ViewModelが完全に機能する状態かを示す
    @Published private(set) var isInitialized = false
    
    // --- Dependencies ---
    private var projectManager: ProjectManager?
    private var authManager: AuthenticationManager?
    private var cancellables = Set<AnyCancellable>()
    
    // --- Private Business Logic State ---
    private var retryCount = 0
    private let maxRetries = 3
    private var lastLoadTime: Date? = nil
    private let loadCooldownInterval: TimeInterval = 1.0
    // Issue #50 Fix: Add task cancellation for tab validation operations
    private var tabValidationTask: Task<Void, Never>?
    
    // MARK: - Access to ProjectManager for Views that need it
    var projectManagerForViews: ProjectManager? {
        return projectManager
    }

    /// **【重要】同期イニシャライザ**  
    /// Viewの生成と同時に、依存関係なしで即座にインスタンス化される。
    init() {
        print("⚡ ProjectListViewModel: 同期初期化開始")
        self.authManager = AuthenticationManager.shared
        setupAuthenticationObserver()
        print("✅ ProjectListViewModel: 同期初期化完了 - 認証状態の監視を開始")
    }

    private func setupBindings() {
        guard let projectManager = projectManager else {
            print("⚠️ ProjectListViewModel: setupBindings() called but projectManager is nil")
            return
        }
        
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
            
        print("🔗 ProjectListViewModel: Manager bindingsが確立されました")
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
        // Manager注入前は常にfalse
        guard let authManager = authManager else {
            shouldShowEmptyState = false
            return
        }
        
        // Empty state logic: show when bootstrapped, not loading, and no projects exist
        let newEmptyState = bootstrapped && !isLoading && !isWaitingForAuth && filteredProjects.isEmpty && authManager.currentUser?.id != nil
        shouldShowEmptyState = newEmptyState
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
            print("🔄 ProjectListViewModel: 認証ユーザー変更を検知。ユーザーID: \(userId)。データロードを開始します。")
            isWaitingForAuth = false
            Task {
                // Managerがまだ注入されていない場合は待機する
                await setupProjectManagerIfNeeded()
                await loadProjects(for: userId)
                bootstrapped = true
            }
        } else {
            print("🔄 ProjectListViewModel: ユーザーがサインアウトしました。データをクリアします。")
            self.projects = []
            self.filteredProjects = []
            self.projectManager?.removeAllListeners()
            isWaitingForAuth = true
            bootstrapped = true // Bootstrap is complete, even if logged out.
        }
        applyFilter()
    }

    private func setupProjectManagerIfNeeded() async {
        guard self.projectManager == nil else { return }
        print("⏳ ProjectListViewModel: ProjectManagerが未注入のため、SharedManagerStoreから取得します。")
        self.projectManager = await SharedManagerStore.shared.getProjectManager()
        setupBindings() // Managerが注入されたので、バインディングを再設定
        self.isInitialized = true
        print("✅ ProjectListViewModel: ProjectManagerの注入が完了しました。")
        
        // Preload commonly used managers for faster project detail views
        Task.detached(priority: .utility) { [weak self] in
            await self?.preloadDetailViewManagers()
        }
    }
    
    /// Preload managers commonly used in ProjectDetailView for better performance
    private func preloadDetailViewManagers() async {
        print("🚀 ProjectListViewModel: Preloading managers for faster project detail views")
        
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                _ = await SharedManagerStore.shared.getPhaseManager()
                print("✅ ProjectListViewModel: PhaseManager preloaded")
            }
            
            group.addTask {
                _ = await SharedManagerStore.shared.getAiGenerator()
                print("✅ ProjectListViewModel: AITaskGenerator preloaded")
            }
            
            group.addTask {
                _ = await SharedManagerStore.shared.getFamilyManager()
                print("✅ ProjectListViewModel: FamilyManager preloaded")
            }
        }
        
        print("🎯 ProjectListViewModel: Manager preloading completed")
    }
    
    /// Preload project-specific data when a project is selected for immediate display
    private func preloadProjectData(_ project: Project) async {
        print("🔥 ProjectListViewModel: Preloading data for project: \(project.name)")
        
        guard project.id != nil else {
            print("⚠️ ProjectListViewModel: Project has no ID, skipping preload")
            return
        }
        
        // Get managers if not already available - this will warm the cache for faster access
        _ = await SharedManagerStore.shared.getPhaseManager()
        _ = await SharedManagerStore.shared.getAuthManager()
        
        // Additional project-specific preloading can be added here when methods are available
        print("🚀 ProjectListViewModel: Manager preloading initiated for: \(project.name)")
    }
    
    private func loadProjects(for userId: String) async {
        guard let projectManager = self.projectManager else {
            print("⚠️ ProjectListViewModel: Manager not available for loadProjects")
            return
        }
        
        print("👤 ProjectListViewModel: プロジェクトデータの読み込みを開始 - User: \(userId)")
        
        // Start real-time listening
        await MainActor.run {
            projectManager.startListeningForUserProjects(userId: userId)
        }
        print("✨ ProjectListViewModel: Started listening to projects for user")
    }
    
    // MARK: - Public Interface
    
    func onAppear() async {
        #if DEBUG
        print("📱 ProjectListViewModel: onAppear triggered")
        #endif
        // 認証状態の変更によって自動的にロードされるため、ここでの明示的なロードは不要
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

        guard (authManager?.currentUser?.id) != nil else {
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
        guard let userId = authManager?.currentUser?.id else {
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
        guard let projectManager = projectManager else { return }
        projectManager.removeAllListeners()
    }
    
    func startListeningForUserProjects(userId: String) {
        guard let projectManager = projectManager else { return }
        projectManager.startListeningForUserProjects(userId: userId)
    }
    
    func deleteProject(id: String) async throws {
        do {
            try await projectManager?.deleteProject(id: id)
        } catch {
            await MainActor.run {
                self.error = FirebaseError.from(error)
                self.showError = true
            }
            throw error
        }
    }
    
    func clearError() {
        projectManager?.error = nil
        showError = false
    }
}
