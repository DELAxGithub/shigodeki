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
    @EnvironmentObject var themeManager: ThemeManager
    
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
                        authManager.signOut()
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
        }
    }
}

#Preview {
    MainTabView()
}