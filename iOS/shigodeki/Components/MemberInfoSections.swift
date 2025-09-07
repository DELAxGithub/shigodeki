//
//  MemberInfoSections.swift
//  shigodeki
//
//  Created from MemberDetailSections split for CLAUDE.md compliance
//  Member information display section components
//

import SwiftUI
import FirebaseFirestore

// MARK: - Member Info Section

struct MemberInfoSection: View {
    let member: User
    
    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    // プロフィールアイコン
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.2))
                            .frame(width: 60, height: 60)
                        
                        Text(String(member.name.prefix(1).uppercased()))
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(member.name)
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text(member.email)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if let joinDate = member.createdAt {
                            Text("参加日: \(DateFormatter.shortDate.string(from: joinDate))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                }
                .padding(.vertical, 8)
            }
        }
    }
}

// MARK: - Contact Info Section

struct ContactInfoSection: View {
    let member: User
    
    var body: some View {
        Section("連絡先") {
            HStack {
                Image(systemName: "envelope")
                    .foregroundColor(.blue)
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("メールアドレス")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(member.email)
                        .font(.body)
                }
                
                Spacer()
                
                Button(action: {
                    if let emailURL = URL(string: "mailto:\(member.email)") {
                        UIApplication.shared.open(emailURL)
                    }
                }) {
                    Image(systemName: "paperplane")
                        .foregroundColor(.blue)
                }
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Projects Section

struct MemberProjectsSection: View {
    let userProjects: [Project]
    let isLoadingProjects: Bool
    
    var body: some View {
        Section("参加プロジェクト (\(userProjects.count))") {
            if isLoadingProjects {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("プロジェクトを読み込み中...")
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.vertical, 8)
            } else if userProjects.isEmpty {
                HStack {
                    Image(systemName: "folder.badge.questionmark")
                        .foregroundColor(.secondary)
                    Text("参加プロジェクトがありません")
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.vertical, 8)
            } else {
                ForEach(userProjects) { project in
                    ProjectRowCompact(project: project)
                }
            }
        }
    }
}

// MARK: - Assigned Tasks Section

struct MemberAssignedTasksSection: View {
    let assignedTasks: [ShigodekiTask]
    let isLoadingTasks: Bool
    
    var body: some View {
        Section("アサイン済みタスク (\(assignedTasks.count))") {
            if isLoadingTasks {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("タスクを読み込み中...")
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.vertical, 8)
            } else if assignedTasks.isEmpty {
                HStack {
                    Image(systemName: "checklist")
                        .foregroundColor(.secondary)
                    Text("アサイン済みタスクはありません")
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.vertical, 8)
            } else {
                ForEach(assignedTasks) { task in
                    TaskRowCompact(task: task)
                }
            }
        }
    }
}