//
//  MainTabView.swift
//  shigodeki
//
//  Refactored for CLAUDE.md compliance - Lightweight tab coordinator
//  Tab navigation extracted to TabNavigationManager.swift
//  Settings components extracted to SettingsViewSections.swift and SettingsDataService.swift
//

import SwiftUI

struct MainTabView: View {
    @StateObject private var sharedManagers = SharedManagerStore.shared
    @StateObject private var familyViewModel = FamilyViewModel(authManager: AuthenticationManager.shared)
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var tabNavigationManager = TabNavigationManager()
    
    var body: some View {
        TabView(selection: $tabNavigationManager.selectedTab) {
            ProjectListView()
                .tabItem {
                    Image(systemName: "folder.fill")
                    Text("プロジェクト")
                }
                .tag(tabNavigationManager.projectTabIndex)
            
            FamilyView()
                .tabItem {
                    Image(systemName: "person.3.fill")
                    Text("チーム")
                }
                .environmentObject(familyViewModel)
                .tag(tabNavigationManager.familyTabIndex)
            
            #if DEBUG
            AuthTestView()
                .tabItem {
                    Image(systemName: "flask")
                    Text("テスト")
                }
                .tag(tabNavigationManager.testTabIndex)
            #endif
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("設定")
                }
                .tag(tabNavigationManager.settingsTabIndex)
        }
        .accentColor(.primaryBlue)
        .preferredColorScheme(themeManager.currentTheme.colorScheme)
        .environmentObject(themeManager)
        .environmentObject(sharedManagers)
        .environmentObject(tabNavigationManager)
        .withIntegratedPerformanceMonitoring()
        .onMemoryWarning {
            Task {
                await sharedManagers.cleanupUnusedManagers()
            }
        }
        .task {
            // Fix: Initialize SharedManagerStore preload to prevent IntegratedPerformanceMonitor infinite loop
            await sharedManagers.preload()
        }
        .onChange(of: tabNavigationManager.selectedTab) { oldVal, newVal in
            print("📊 Issue #50 Debug: SharedManagerStore preload status: \(sharedManagers.isPreloaded)")
            print("🔊 Issue #50 Debug: Active Firebase listeners: \(FirebaseListenerManager.shared.listenerStats.totalActive)")
            
            tabNavigationManager.handleTabChange(oldValue: oldVal, newValue: newVal)
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @EnvironmentObject var sharedManagers: SharedManagerStore
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var dataService = SettingsDataService(sharedManagers: SharedManagerStore.shared)
    
    @State private var showAISettings = false
    @State private var showTaskImprovement = false
    @State private var showEditUsername = false
    @State private var editingUsername = ""
    
    var body: some View {
        NavigationView {
            ScrollViewReader { proxy in
                List {
                    // Top anchor for scroll-to-top
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 1)
                        .id("top")
                        .listRowSeparator(.hidden)
                    
                    // User Profile Section
                    UserProfileSection(
                        authManager: dataService.authManager,
                        isUpdatingUsername: $dataService.isUpdatingUsername,
                        onEditUsername: {
                            editingUsername = dataService.authManager?.currentUser?.name ?? ""
                            showEditUsername = true
                        }
                    )
                    
                    // AI Features Section
                    AIFeaturesSection(
                        onShowAISettings: { showAISettings = true },
                        onShowTaskImprovement: { showTaskImprovement = true }
                    )
                    
                    // Appearance Section
                    AppearanceSection(themeManager: themeManager)
                    
                    // Actions Section
                    SettingsActionsSection(authManager: dataService.authManager)
                }
                .navigationTitle("設定")
                .navigationBarTitleDisplayMode(.large)
                .task {
                    await dataService.initializeManagers()
                }
                .sheet(isPresented: $showAISettings) {
                    APISettingsView()
                }
                .sheet(isPresented: $showTaskImprovement) {
                    TaskImprovementSuggestionView(userId: dataService.authManager?.currentUserId ?? "")
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
                            await dataService.updateUsername(editingUsername)
                            editingUsername = ""
                        }
                    }
                    .disabled(editingUsername.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                } message: {
                    Text("新しいユーザー名を入力してください")
                }
                .onReceive(NotificationCenter.default.publisher(for: .settingsTabSelected)) { _ in
                    withAnimation(.easeInOut(duration: 0.5)) {
                        proxy.scrollTo("top", anchor: .top)
                    }
                }
            }
        }
    }
}

#Preview {
    MainTabView()
}
