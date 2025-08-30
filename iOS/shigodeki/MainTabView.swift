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
    @StateObject private var themeManager = ThemeManager()
    
    var body: some View {
        TabView {
            ProjectListView()
                .tabItem {
                    Image(systemName: "folder.fill")
                    Text("プロジェクト")
                }
            
            FamilyView()
                .tabItem {
                    Image(systemName: "person.3.fill")
                    Text("家族")
                }
            
            TaskListMainView()
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("家族タスク")
                }
            
            #if DEBUG
            AuthTestView()
                .tabItem {
                    Image(systemName: "flask")
                    Text("テスト")
                }
            #endif
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("設定")
                }
        }
        .accentColor(.primaryBlue)
        .preferredColorScheme(themeManager.currentTheme.colorScheme)
        .environmentObject(themeManager)
        .environmentObject(sharedManagers) // 🆕 統合されたManager Storeを提供
        .withIntegratedPerformanceMonitoring() // 🆕 統合パフォーマンス監視
        .task {
            // ⚡ Optimized startup - immediate initialization without artificial delays
            #if DEBUG
            await MainActor.run {
                InstrumentsSetup.shared.logMemoryUsage(context: "MainTabView Startup")
                let startTime = CFAbsoluteTimeGetCurrent()
                defer {
                    let elapsedTime = CFAbsoluteTimeGetCurrent() - startTime
                    print("⚡ Performance: MainTabView initialization completed in \(Int(elapsedTime * 1000))ms")
                }
            }
            #endif
            
            // 🚀 Essential manager initialization - no artificial delays
            let authManager = await sharedManagers.getAuthManager()
            
            #if DEBUG
            await MainActor.run {
                sharedManagers.logDebugInfo()
                print("✅ SharedManagerStore: Optimized initialization completed")
            }
            #endif
        }
        .onMemoryWarning {
            // 🆕 メモリ警告時の自動クリーンアップ
            Task {
                await sharedManagers.cleanupUnusedManagers()
            }
        }
    }
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
    
    var body: some View {
        NavigationView {
            List {
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
                                    Text(user.name)
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primaryText)
                                    
                                    Text(user.email)
                                        .font(.subheadline)
                                        .foregroundColor(.secondaryText)
                                }
                                
                                Spacer()
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
                // TODO: TaskImprovementSuggestionView未実装 - 現在はプレースホルダー
                Text("タスク改善提案機能は開発中です")
                    .padding()
            }
        }
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
