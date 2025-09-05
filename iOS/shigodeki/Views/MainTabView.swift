//
//  MainTabView.swift
//  shigodeki
//
//  Created by Claude on 2025-08-27.
//

import SwiftUI

struct MainTabView: View {
    // 🆕 統合されたManager管理（従来の8個→2個に削減）
    @StateObject private var sharedManagers = SharedManagerStore.shared
    // 🚨 CTO修正: FamilyViewModelを同期的に初期化して起動を高速化
    @StateObject private var familyViewModel = FamilyViewModel(authManager: AuthenticationManager.shared)
    @StateObject private var themeManager = ThemeManager()
    
    @State private var selectedTab: Int = 0
    // Issue #50 Fix: Add debounced tab switching to prevent loading instability
    @State private var tabSwitchDebounceTask: Task<Void, Never>?
    private let projectTabIndex = 0
    private let familyTabIndex = 1
    #if DEBUG
    private let testTabIndex = 2
    private let settingsTabIndex = 3
    #else
    private let settingsTabIndex = 2
    #endif
    
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ProjectListView()
                .tabItem {
                    Image(systemName: "folder.fill")
                    Text("プロジェクト")
                }
                .tag(projectTabIndex)
            
            FamilyView()
                .tabItem {
                    Image(systemName: "person.3.fill")
                    Text("チーム")
                }
                .environmentObject(familyViewModel)
                .tag(familyTabIndex)
            
            #if DEBUG
            AuthTestView()
                .tabItem {
                    Image(systemName: "flask")
                    Text("テスト")
                }
                .tag(testTabIndex)
            #endif
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("設定")
                }
                .tag(settingsTabIndex)
        }
        .accentColor(.primaryBlue)
        .preferredColorScheme(themeManager.currentTheme.colorScheme)
        .environmentObject(themeManager)
        .environmentObject(sharedManagers) // 🆕 統合されたManager Storeを提供
        .withIntegratedPerformanceMonitoring() // 🆕 統合パフォーマンス監視
        // 🚨 CTO修正: ViewModelが自律的に認証状態を監視し、必要に応じて自身でManagerを取得するため、
        // MainTabViewでの中央集権的なManager事前読み込みは不要となった。
        .onMemoryWarning {
            // 🆕 メモリ警告時の自動クリーンアップ
            Task {
                await sharedManagers.cleanupUnusedManagers()
            }
        }
        .onChange(of: selectedTab) { oldVal, newVal in
            let timestamp = Date()
            print("🔄 Issue #50 Debug: Tab changed from \(oldVal) to \(newVal) at \(timestamp)")
            print("📊 Issue #50 Debug: SharedManagerStore preload status: \(sharedManagers.isPreloaded)")
            print("🔊 Issue #50 Debug: Active Firebase listeners: \(FirebaseListenerManager.shared.listenerStats.totalActive)")
            
            // Issue #50 Fix: Cancel previous debounce task to prevent overlapping operations
            if tabSwitchDebounceTask != nil {
                print("⏹️ Issue #50 Debug: Cancelling previous tab switch task")
                tabSwitchDebounceTask?.cancel()
            }
            
            // Issue #50 Fix: Debounce tab notifications to prevent rapid-fire data loading
            tabSwitchDebounceTask = Task {
                let debounceStart = Date()
                // 🚨 CTO修正: 150msタブ切り替え遅延を撤廃し、即座に反応するUIを実装
                // デバウンス処理は保持するが、遅延なしで即座に実行
                print("⚡ Issue #50 優化: 即座にタブ切り替え通知を送信 at \(debounceStart)")
                
                // Check if task was cancelled (without delay)
                guard !Task.isCancelled else {
                    print("🔄 Issue #50 Debug: Tab notification cancelled due to new tab switch")
                    return
                }
                
                let debounceEnd = Date()
                print("✅ Issue #50 優化: 即座実行完了 at \(debounceEnd), elapsed: \(Int((debounceEnd.timeIntervalSince(debounceStart)) * 1000))ms")
                
                await MainActor.run {
                    // Issue #46 Fix: Only reset navigation when re-selecting same tab (iOS standard)
                    if oldVal == newVal && newVal == projectTabIndex { 
                        print("📱 Issue #46: Same Project tab re-selected, resetting navigation")
                        NotificationCenter.default.post(name: .projectTabSelected, object: nil) 
                    }
                    if oldVal == newVal && newVal == familyTabIndex { 
                        print("📱 Issue #46: Same Family tab re-selected, resetting navigation")
                        NotificationCenter.default.post(name: .familyTabSelected, object: nil) 
                    }
                    if oldVal == newVal && newVal == settingsTabIndex { 
                        print("📱 Issue #46: Same Settings tab re-selected, resetting navigation")
                        NotificationCenter.default.post(name: .settingsTabSelected, object: nil) 
                    }
                    #if DEBUG
                    if oldVal == newVal && newVal == testTabIndex { 
                        print("📱 Issue #46: Same Test tab re-selected, resetting navigation")
                        NotificationCenter.default.post(name: .testTabSelected, object: nil) 
                    }
                    #endif
                }
            }
        }
    }
}

extension Notification.Name {
    static let projectTabSelected = Notification.Name("ProjectTabSelectedNotification")
    static let familyTabSelected = Notification.Name("FamilyTabSelectedNotification")
    static let settingsTabSelected = Notification.Name("SettingsTabSelectedNotification")
    static let testTabSelected = Notification.Name("TestTabSelectedNotification")
}

// MARK: - Placeholder Views

struct SettingsView: View {
    @EnvironmentObject var sharedManagers: SharedManagerStore
    @EnvironmentObject var themeManager: ThemeManager
    
    // 🆕 共有Managerを使用（重複作成を防止） - 非同期アクセス用State
    @State private var authManager: AuthenticationManager?
    @State private var taskListManager: TaskListManager?
    @State private var aiGenerator: AITaskGenerator?
    @State private var showAISettings = false
    @State private var showTaskImprovement = false
    
    // Username editing states
    @State private var showEditUsername = false
    @State private var editingUsername = ""
    @State private var isUpdatingUsername = false
    
    @State private var navigationResetId = UUID()
    
    var body: some View {
        NavigationView {
            // Issue #84: Add ScrollViewReader for scroll-to-top functionality
            ScrollViewReader { proxy in
                List {
                    // Issue #84: Add top anchor for scroll-to-top functionality
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 1)
                        .id("top")
                        .listRowSeparator(.hidden)
                    
                    // User Profile Section
                    Section {
                    if let authManager = authManager, let user = authManager.currentUser {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 16) {
                                // Profile Avatar
                                ZStack {
                                    Circle()
                                        .fill(Color.primaryBlue.opacity(0.1))
                                        .frame(width: 60, height: 60)
                                    
                                    Image(systemName: "person.fill")
                                        .font(.title)
                                        .foregroundColor(.primaryBlue)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(user.name)
                                            .font(.title3)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.primaryText)
                                        
                                        Button {
                                            editingUsername = user.name
                                            showEditUsername = true
                                        } label: {
                                            Image(systemName: "pencil")
                                                .font(.caption)
                                                .foregroundColor(.primaryBlue)
                                        }
                                        .disabled(isUpdatingUsername)
                                    }
                                    
                                    Text(user.email)
                                        .font(.subheadline)
                                        .foregroundColor(.secondaryText)
                                }
                                
                                Spacer()
                                
                                if isUpdatingUsername {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                }
                            }
                        }
                        .primaryCard()
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    }
                }
                
                // AI Features Section
                Section("AI機能") {
                    Button {
                        showAISettings = true
                    } label: {
                        HStack {
                            Image(systemName: "brain")
                                .foregroundColor(.primaryBlue)
                                .frame(width: 24)
                            
                            Text("AI設定")
                                .foregroundColor(.primaryText)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondaryText)
                                .font(.caption)
                        }
                    }
                    
                    Button {
                        showTaskImprovement = true
                    } label: {
                        HStack {
                            Image(systemName: "lightbulb.fill")
                                .foregroundColor(.yellow)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("タスク改善提案")
                                    .foregroundColor(.primaryText)
                                
                                Text("AIがタスクの改善案を提案")
                                    .font(.caption)
                                    .foregroundColor(.secondaryText)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondaryText)
                                .font(.caption)
                        }
                    }
                }
                
                // Appearance Section
                Section("外観") {
                    HStack {
                        Image(systemName: "paintbrush.fill")
                            .foregroundColor(.primaryBlue)
                            .frame(width: 24)
                        
                        Text("テーマ")
                            .foregroundColor(.primaryText)
                        
                        Spacer()
                        
                        Picker("テーマ", selection: $themeManager.currentTheme) {
                            ForEach(ThemeManager.AppTheme.allCases, id: \.self) { theme in
                                Text(theme.displayName)
                                    .tag(theme)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                }
                
                // Actions Section
                Section {
                    Button(action: {
                        Task {
                            if let authManager = authManager {
                                await authManager.signOut()
                            }
                        }
                    }) {
                        HStack {
                            Image(systemName: "arrow.right.square")
                                .foregroundColor(.error)
                                .frame(width: 24)
                            
                            Text("サインアウト")
                                .foregroundColor(.error)
                                .fontWeight(.medium)
                        }
                    }
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.large)
            .task {
                // Initialize managers when the view appears
                authManager = await sharedManagers.getAuthManager()
                taskListManager = await sharedManagers.getTaskListManager()
                aiGenerator = await sharedManagers.getAiGenerator()
                
                // Load tasks for improvement suggestions when settings appear
                if let userId = authManager?.currentUser?.id {
                    // Load family tasks for improvement analysis
                    // This is a simplified approach - in production you'd want more targeted loading
                    await loadUserTasks(userId: userId)
                }
            }
            .sheet(isPresented: $showAISettings) {
                APISettingsView()
            }
            .sheet(isPresented: $showTaskImprovement) {
                TaskImprovementSuggestionView(userId: authManager?.currentUserId ?? "")
                    .environmentObject(sharedManagers)
            }
            .alert("ユーザー名を編集", isPresented: $showEditUsername) {
                TextField("ユーザー名", text: $editingUsername)
                    .textInputAutocapitalization(.words)
                
                Button("キャンセル", role: .cancel) {
                    editingUsername = ""
                }
                
                Button("保存") {
                    Task {
                        await updateUsername()
                    }
                }
                .disabled(editingUsername.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } message: {
                Text("新しいユーザー名を入力してください")
            }
            .onReceive(NotificationCenter.default.publisher(for: .settingsTabSelected)) { _ in
                // Issue #84: Scroll to top when settings tab is re-selected
                withAnimation(.easeInOut(duration: 0.5)) {
                    proxy.scrollTo("top", anchor: .top)
                }
            }
            }
        }
    }
    
    private func updateUsername() async {
        guard let authManager = authManager else { return }
        
        isUpdatingUsername = true
        await authManager.updateUserName(editingUsername)
        isUpdatingUsername = false
        editingUsername = ""
    }
    
    private func loadUserTasks(userId: String) async {
        // Simplified task loading for improvement suggestions
        // In a full implementation, you'd load from user's families and task lists
        let familyManager = await sharedManagers.getFamilyManager() // 🆕 共有Managerを使用（非同期）
        
        await familyManager.loadFamiliesForUser(userId: userId)
        
        // Access the loaded families from the family manager
        let families = familyManager.families
        
        for family in families {
            if let familyId = family.id, let taskListManager = taskListManager {
                do {
                    let taskLists = try await taskListManager.getTaskLists(familyId: familyId)
                    
                    // Load tasks for first few task lists (simplified for AI improvement suggestions)
                    print("✅ Loaded \(taskLists.count) task lists for AI improvement analysis")
                } catch {
                    print("❌ Failed to load task lists for family \(familyId): \(error)")
                }
            }
        }
    }
}

#Preview {
    MainTabView()
}
