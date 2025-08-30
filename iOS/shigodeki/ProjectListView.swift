//
//  ProjectListView.swift
//  shigodeki
//
//  Created by Claude on 2025-08-28.
//

import SwiftUI
import Combine

// 🔧 ProjectManagerのラッパークラス - SwiftUIの監視システム統合
@MainActor
class ProjectManagerWrapper: ObservableObject {
    @Published var projectManager: ProjectManager?
    @Published var projects: [Project] = []
    
    private var cancellables = Set<AnyCancellable>()
    
    func setProjectManager(_ manager: ProjectManager?) {
        self.projectManager = manager
        
        // ProjectManagerの@Published projectsプロパティを監視
        if let manager = manager {
            manager.$projects
                .receive(on: DispatchQueue.main)
                .removeDuplicates { oldProjects, newProjects in
                    // 🔧 重複更新防止: 同じプロジェクトIDのセットなら更新スキップ
                    guard oldProjects.count == newProjects.count else { return false }
                    let oldIds = Set(oldProjects.compactMap { $0.id })
                    let newIds = Set(newProjects.compactMap { $0.id })
                    let isDuplicate = oldIds == newIds && oldIds.count == oldProjects.count
                    
                    if isDuplicate {
                        print("🚫 ProjectManagerWrapper: Duplicate update detected, skipping")
                    }
                    
                    return isDuplicate
                }
                .sink { [weak self] projects in
                    print("🔄 ProjectManagerWrapper: Projects updated to \(projects.count)")
                    print("📋 ProjectManagerWrapper: Project names: \(projects.map { $0.name })")
                    self?.projects = projects
                }
                .store(in: &cancellables)
        } else {
            cancellables.removeAll()
            projects = []
        }
    }
}

struct ProjectListView: View {
    // 🆕 統合されたManager使用（ObservedObjectパターン）
    @EnvironmentObject var sharedManagers: SharedManagerStore
    
    // 🔧 修正: @StateObjectで直接ProjectManagerを監視
    @StateObject private var projectManagerWrapper = ProjectManagerWrapper()
    @State private var authManager: AuthenticationManager?
    
    @State private var showingCreateProject = false
    @State private var selectedProject: Project?
    
    enum OwnerFilter: String, CaseIterable { case all = "すべて", individual = "個人", family = "家族" }
    @State private var ownerFilter: OwnerFilter = .all
    
    var body: some View {
        NavigationView {
            VStack {
                Picker("所有者", selection: $ownerFilter) {
                    ForEach(OwnerFilter.allCases, id: \.self) { f in
                        Text(f.rawValue).tag(f)
                    }
                }
                .pickerStyle(.segmented)
                .padding([.horizontal, .top])
                contentContainerView
            }
            .navigationTitle("プロジェクト")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingCreateProject = true
                    }) {
                        Image(systemName: "plus")
                    }
                    .accessibilityIdentifier("create_project_button")
                    .accessibilityLabel("新しいプロジェクトを作成")
                }
            }
            .task {
                // Initialize managers when the view appears
                let manager = await sharedManagers.getProjectManager()
                let auth = await sharedManagers.getAuthManager()
                
                #if DEBUG
                print("📱 ProjectListView: task triggered")
                print("🔧 ProjectListView: Setting ProjectManager in wrapper")
                #endif
                
                // 🔧 修正: ProjectManagerWrapperに設定
                projectManagerWrapper.setProjectManager(manager)
                authManager = auth
                
                loadUserProjectsWithDebounce()
            }
            .onChange(of: authManager?.isAuthenticated ?? false) { _, isAuthenticated in
                let now = Date()
                
                // 🆕 認証状態変更のデバウンス処理
                if let lastChange = lastAuthStateChange,
                   now.timeIntervalSince(lastChange) < authChangeCooldown {
                    #if DEBUG
                    print("🚫 ProjectListView: Auth state change ignored due to cooldown")
                    #endif
                    return
                }
                
                lastAuthStateChange = now
                
                #if DEBUG
                print("📱 ProjectListView: Authentication state changed: \(isAuthenticated)")
                #endif
                
                if isAuthenticated {
                    // 🔧 既にプロジェクトが読み込まれている場合は重複ロードを避ける
                    if projectManagerWrapper.projects.isEmpty {
                        #if DEBUG
                        print("🔄 ProjectListView: User authenticated, loading projects")
                        #endif
                        retryCount = 0
                        loadUserProjectsWithDebounce()
                    } else {
                        #if DEBUG
                        print("✅ ProjectListView: Projects already loaded, skipping duplicate load")
                        #endif
                    }
                } else {
                    // Reset states when user signs out
                    retryCount = 0
                    isWaitingForAuth = false
                }
            }
            .onDisappear {
                #if DEBUG
                print("👋 ProjectListView: Disappearing, cleaning up listeners")
                #endif
                projectManagerWrapper.projectManager?.removeAllListeners()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
                print("🔚 ProjectListView: App terminating, cleaning up")
                projectManagerWrapper.projectManager?.removeAllListeners()
            }
            .sheet(isPresented: $showingCreateProject) {
                if let projectManager = projectManagerWrapper.projectManager {
                    CreateProjectView(projectManager: projectManager)
                }
            }
            .alert("エラー", isPresented: Binding(
                get: { projectManagerWrapper.projectManager?.error != nil },
                set: { _ in projectManagerWrapper.projectManager?.error = nil }
            )) {
                Button("OK") {
                    projectManagerWrapper.projectManager?.error = nil
                }
            } message: {
                if let error = projectManagerWrapper.projectManager?.error {
                    Text(error.localizedDescription)
                } else {
                    Text("不明なエラーが発生しました")
                }
            }
        }
    }
    
    // MARK: - Computed Properties for View Decomposition
    
    @ViewBuilder
    private var contentContainerView: some View {
        VStack {
            mainContentView
            loadingStateView
        }
        .onChange(of: projectManagerWrapper.projects.count) { _, newCount in
            #if DEBUG
            print("📊 ProjectListView: UI Projects count changed: \(newCount)")
            print("📋 ProjectListView: UI Project names: \(projectManagerWrapper.projects.map { $0.name })")
            print("🎨 ProjectListView: SwiftUI triggering UI update")
            #endif
        }
    }
    
    @ViewBuilder
    private var mainContentView: some View {
        if shouldShowEmptyState {
            ProjectEmptyStateView {
                showingCreateProject = true
            }
        } else if let projectManager = projectManagerWrapper.projectManager {
            projectListView(projectManager: projectManager)
        }
    }
    
    @ViewBuilder
    private var loadingStateView: some View {
        if let authManager = authManager, authManager.isLoading {
            LoadingStateView(message: "認証中...")
                .padding()
        } else if isWaitingForAuth {
            LoadingStateView(message: "ユーザー情報を取得中...")
                .padding()
        } else if let projectManager = projectManagerWrapper.projectManager, projectManager.isLoading {
            LoadingStateView(message: "プロジェクトを読み込み中...")
                .padding()
        }
    }
    
    private var shouldShowEmptyState: Bool {
        guard let projectManager = projectManagerWrapper.projectManager else { return false }
        return filteredProjects.isEmpty && !projectManager.isLoading
    }
    
    @ViewBuilder
    private func projectListView(projectManager: ProjectManager) -> some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredProjects) { project in
                    NavigationLink(destination: ProjectDetailView(project: project, projectManager: projectManager)) {
                        OptimizedProjectRow(project: project)
                            .optimizedForList() // 🆕 描画最適化
                    }
                    .buttonStyle(PlainButtonStyle())
                    .id(project.id) // 🔧 明示的なID設定で重複防止
                }
            }
            .padding(.horizontal)
        }
        .refreshable {
            await refreshProjects(projectManager: projectManager)
        }
        .onMemoryWarning {
            // 🆕 統合されたキャッシュクリア
            CacheManager.shared.clearAll()
            ImageCache.shared.clearCache()
            InstrumentsSetup.shared.logMemoryUsage(context: "After Memory Warning - ProjectList")
        }
    }
    
    // MARK: - Owner filter helper
    private var filteredProjects: [Project] {
        switch ownerFilter {
        case .all: return projectManagerWrapper.projects
        case .individual: return projectManagerWrapper.projects.filter { $0.ownerType == .individual }
        case .family: return projectManagerWrapper.projects.filter { $0.ownerType == .family }
        }
    }
    
    private func refreshProjects(projectManager: ProjectManager) async {
        // 🔧 修正: リアルタイムリスナーを使用しているため、手動リフレッシュは不要
        // Firebase リスナーが自動的にデータを更新するため、重複呼び出しを避ける
        print("🔄 ProjectListView: Refresh requested - using real-time listener (no additional API call)")
        
        // リスナーが既にアクティブな場合は何もしない
        if let userId = authManager?.currentUserId {
            print("👤 ProjectListView: Real-time listener active for user: \(userId)")
        } else {
            print("⚠️ ProjectListView: No authenticated user for refresh")
        }
    }
    
    @State private var retryCount = 0
    @State private var isWaitingForAuth = false
    private let maxRetries = 3  // Reduced from 5 to 3
    @State private var lastLoadTime: Date? = nil
    private let loadCooldownInterval: TimeInterval = 1.0 // 1秒のクールダウン
    @State private var lastAuthStateChange: Date? = nil // 🆕 認証状態変更の頻度制御
    private let authChangeCooldown: TimeInterval = 2.0 // 🆕 認証状態変更2秒クールダウン
    
    // 🆕 パフォーマンス最適化関連のヘルパー
    private func loadMoreProjects() {
        // 大量データ対応（将来の拡張用）
        print("📊 ProjectListView: Loading more projects requested")
        // TODO: ページネーション実装時に使用
    }
    
    // デバウンス機能付きプロジェクトロード
    private func loadUserProjectsWithDebounce() {
        let now = Date()
        
        // クールダウン期間チェック
        if let lastLoad = lastLoadTime, now.timeIntervalSince(lastLoad) < loadCooldownInterval {
            #if DEBUG
            print("🚫 ProjectListView: Load request ignored due to cooldown (last: \(lastLoad))")
            #endif
            return
        }
        
        lastLoadTime = now
        loadUserProjects()
    }
    
    private func loadUserProjects() {
        #if DEBUG
        print("📱 ProjectListView: loadUserProjects called (attempt \(retryCount + 1))")
        #endif
        
        guard let userId = authManager?.currentUserId else {
            // If user is authenticated but userId is nil, wait briefly
            if authManager?.isAuthenticated == true && retryCount < maxRetries {
                isWaitingForAuth = true
                let delay = exponentialBackoffDelay(for: retryCount)
                print("⏳ ProjectListView: User authenticated but ID loading, retry in \(String(format: "%.1f", delay))s")
                retryCount += 1
                
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    print("🔄 ProjectListView: Retrying loadUserProjects after delay (\(self.retryCount)/\(self.maxRetries))")
                    self.loadUserProjects()
                }
                return
            } else if authManager?.isAuthenticated != true {
                print("🔐 ProjectListView: User not authenticated, waiting for sign in")
                isWaitingForAuth = false
                retryCount = 0
                return
            } else {
                print("❌ ProjectListView: Max retries reached, stopping")
                isWaitingForAuth = false
                return
            }
        }
        
        retryCount = 0 // Reset on successful user ID
        isWaitingForAuth = false // Clear waiting state
        
        print("👤 ProjectListView: Loading projects for user: \(userId)")
        
        Task {
            do {
                print("🔄 ProjectListView: Starting project listener")
                let manager = projectManagerWrapper.projectManager
                manager?.startListeningForUserProjects(userId: userId)
                // 🔧 リスナーが設定されるとデータは自動的に受信されるため、getUserProjects呼び出しは不要
                
                await MainActor.run {
                    print("✨ ProjectListView: Project listener started successfully")
                }
            } catch {
                print("❌ ProjectListView: Error starting project listener: \(error)")
                print("❌ ProjectListView: Error details: \(error.localizedDescription)")
            }
        }
    }
    
    /// Exponential backoff delay calculation
    private func exponentialBackoffDelay(for attempt: Int) -> TimeInterval {
        let baseDelay: TimeInterval = 0.1  // Start with 100ms (reduced from 250ms)
        let maxDelay: TimeInterval = 1.0   // Cap at 1 second (reduced from 2s)
        let delay = baseDelay * pow(2.0, Double(attempt))
        return min(delay, maxDelay)
    }
    
    private func deleteProjects(at offsets: IndexSet) {
        guard !projectManagerWrapper.projects.isEmpty else { return }
        
        let projectsToDelete = offsets.compactMap { index -> Project? in
            let projects = projectManagerWrapper.projects
            guard index < projects.count else { return nil }
            return projects[index]
        }
        
        for project in projectsToDelete {
            guard let projectId = project.id else { continue }
            
            Task {
                do {
                    try await projectManagerWrapper.projectManager?.deleteProject(id: projectId)
                } catch {
                    await MainActor.run {
                        projectManagerWrapper.projectManager?.error = FirebaseError.from(error)
                    }
                    print("❌ ProjectListView: Error deleting project: \(error)")
                }
            }
        }
    }
}


#Preview {
    ProjectListView()
}
