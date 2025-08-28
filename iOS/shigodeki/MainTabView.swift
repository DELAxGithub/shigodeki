//
//  MainTabView.swift
//  shigodeki
//
//  Created by Claude on 2025-08-27.
//

import SwiftUI

struct MainTabView: View {
    @StateObject private var authManager = AuthenticationManager()
    
    var body: some View {
        TabView {
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
        .accentColor(.blue)
    }
}

// MARK: - Placeholder Views

struct SettingsView: View {
    @StateObject private var authManager = AuthenticationManager()
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    if let user = authManager.currentUser {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                            
                            VStack(alignment: .leading) {
                                Text(user.name)
                                    .font(.headline)
                                Text(user.email)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                Section {
                    Button(action: {
                        authManager.signOut()
                    }) {
                        HStack {
                            Image(systemName: "arrow.right.square")
                                .foregroundColor(.red)
                            Text("サインアウト")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .navigationTitle("設定")
        }
    }
}

#Preview {
    MainTabView()
}