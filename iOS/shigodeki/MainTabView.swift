//
//  MainTabView.swift
//  shigodeki
//
//  Created by Claude on 2025-08-27.
//

import SwiftUI

struct MainTabView: View {
    @StateObject private var authManager = AuthenticationManager()
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
                    Text("タスク")
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
    }
}

// MARK: - Placeholder Views

struct SettingsView: View {
    @StateObject private var authManager = AuthenticationManager()
    @StateObject private var taskManager = TaskManager()
    @StateObject private var aiGenerator = AITaskGenerator()
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showAISettings = false
    @State private var showTaskImprovement = false
    
    var body: some View {
        NavigationView {
            List {
                // User Profile Section
                Section {
                    if let user = authManager.currentUser {
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
                            await authManager.signOut()
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
            .onAppear {
                // Load tasks for improvement suggestions when settings appear
                if let userId = authManager.currentUser?.id {
                    Task {
                        // Load family tasks for improvement analysis
                        // This is a simplified approach - in production you'd want more targeted loading
                        await loadUserTasks(userId: userId)
                    }
                }
            }
            .sheet(isPresented: $showAISettings) {
                APISettingsView()
            }
            .sheet(isPresented: $showTaskImprovement) {
                TaskImprovementSuggestionView(taskManager: taskManager, aiGenerator: aiGenerator)
            }
        }
    }
    
    private func loadUserTasks(userId: String) async {
        // Simplified task loading for improvement suggestions
        // In a full implementation, you'd load from user's families and task lists
        let familyManager = FamilyManager()
        
        await familyManager.loadFamiliesForUser(userId: userId)
        
        // Access the loaded families from the family manager
        let families = familyManager.families
        
        for family in families {
            if let familyId = family.id {
                await taskManager.loadTaskLists(familyId: familyId)
                
                // Load tasks for first few task lists
                for taskList in taskManager.taskLists.prefix(5) {
                    if let taskListId = taskList.id {
                        await taskManager.loadTasks(taskListId: taskListId, familyId: familyId)
                    }
                }
            }
        }
    }
}

#Preview {
    MainTabView()
}