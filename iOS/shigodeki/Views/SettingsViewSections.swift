//
//  SettingsViewSections.swift
//  shigodeki
//
//  Extracted from MainTabView.swift for CLAUDE.md compliance
//  Settings view section components
//

import SwiftUI

// Feature flags
private let taskImprovementEnabled = false // Hide unfinished Task Improvement feature

// MARK: - User Profile Section

struct UserProfileSection: View {
    let authManager: AuthenticationManager?
    @Binding var isUpdatingUsername: Bool
    let onEditUsername: () -> Void
    
    var body: some View {
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
                                    onEditUsername()
                                } label: {
                                    Image(systemName: "pencil")
                                        .font(.caption)
                                        .foregroundColor(.primaryBlue)
                                }
                                .disabled(isUpdatingUsername)
                            }
                            
                            if let email = displayableEmail(user.email) {
                                Text(email)
                                    .font(.subheadline)
                                    .foregroundColor(.secondaryText)
                            }
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
    }

    // MARK: - Helpers
    private func displayableEmail(_ raw: String) -> String? {
        return EmailDisplayUtility.displayableEmail(raw)
    }
}

// MARK: - AI Features Section

struct AIFeaturesSection: View {
    let onShowAISettings: () -> Void
    let onShowTaskImprovement: () -> Void
    
    var body: some View {
        Section("AI機能") {
            Button {
                onShowAISettings()
            } label: {
                SettingsRowView(
                    icon: "brain",
                    iconColor: .primaryBlue,
                    title: "AI設定"
                )
            }
            
            if taskImprovementEnabled {
                Button {
                    onShowTaskImprovement()
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
        }
    }
}

// MARK: - Appearance Section

struct AppearanceSection: View {
    @ObservedObject var themeManager: ThemeManager
    
    var body: some View {
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
                .labelsHidden()
                .pickerStyle(MenuPickerStyle())
            }
        }
    }
}

// MARK: - Actions Section

struct SettingsActionsSection: View {
    let authManager: AuthenticationManager?
    
    var body: some View {
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
}

// MARK: - Supporting Components

struct SettingsRowView: View {
    let icon: String
    let iconColor: Color
    let title: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .frame(width: 24)
            
            Text(title)
                .foregroundColor(.primaryText)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondaryText)
                .font(.caption)
        }
    }
}
