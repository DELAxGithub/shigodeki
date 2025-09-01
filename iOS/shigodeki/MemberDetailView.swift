//
//  MemberDetailView.swift
//  shigodeki
//
//  Created by Claude on 2025-09-01.
//

import SwiftUI
import FirebaseFirestore

struct MemberDetailView: View {
    let member: User
    @EnvironmentObject var sharedManagers: SharedManagerStore
    @State private var userProjects: [Project] = []
    @State private var assignedTasks: [ShigodekiTask] = []
    @State private var isLoadingProjects = false
    @State private var isLoadingTasks = false
    @State private var projectManager: ProjectManager?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                // Member Info Section
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
                                
                                if let lastActive = member.lastActiveAt {
                                    Text("最終アクティブ: \(DateFormatter.shortDate.string(from: lastActive))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("プロフィール")
                }
                
                // Contact Info Section
                Section("連絡先") {
                    if !member.email.isEmpty {
                        Button(action: {
                            if let emailURL = URL(string: "mailto:\(member.email)") {
                                UIApplication.shared.open(emailURL)
                            }
                        }) {
                            HStack {
                                Image(systemName: "envelope.fill")
                                    .foregroundColor(.blue)
                                    .frame(width: 25)
                                
                                Text(member.email)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Image(systemName: "arrow.up.right.square")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                        }
                    } else {
                        HStack {
                            Image(systemName: "envelope.fill")
                                .foregroundColor(.gray)
                                .frame(width: 25)
                            
                            Text("メールアドレス未設定")
                                .foregroundColor(.secondary)
                                .font(.subheadline)
                        }
                    }
                }
                
                // Projects Section
                Section("参加プロジェクト (\(userProjects.count))") {
                    if isLoadingProjects {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("プロジェクトを読み込み中...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                    } else if userProjects.isEmpty {
                        HStack {
                            Image(systemName: "folder.badge.questionmark")
                                .foregroundColor(.gray)
                                .frame(width: 25)
                            
                            Text("参加プロジェクトがありません")
                                .foregroundColor(.secondary)
                                .font(.subheadline)
                        }
                        .padding(.vertical, 8)
                    } else {
                        ForEach(userProjects) { project in
                            if let pm = projectManager {
                                NavigationLink(destination: ProjectDetailView(project: project, projectManager: pm)) {
                                    ProjectRowView(project: project)
                                }
                            } else {
                                ProjectRowView(project: project)
                            }
                        }
                    }
                }
                
                // Assigned Tasks Section
                Section("アサイン済みタスク (\(assignedTasks.count))") {
                    if isLoadingTasks {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("タスクを読み込み中...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                    } else if assignedTasks.isEmpty {
                        HStack {
                            Image(systemName: "checkmark.circle.badge.questionmark")
                                .foregroundColor(.gray)
                                .frame(width: 25)
                            
                            Text("アサイン済みタスクがありません")
                                .foregroundColor(.secondary)
                                .font(.subheadline)
                        }
                        .padding(.vertical, 8)
                    } else {
                        ForEach(assignedTasks.prefix(10)) { task in // 最大10件表示
                            MemberTaskRowView(task: task)
                        }
                        
                        if assignedTasks.count > 10 {
                            HStack {
                                Image(systemName: "ellipsis")
                                    .foregroundColor(.secondary)
                                    .frame(width: 25)
                                
                                Text("他 \(assignedTasks.count - 10) 件のタスク")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                // Statistics Section
                if !userProjects.isEmpty || !assignedTasks.isEmpty {
                    Section("統計情報") {
                        StatRowView(
                            icon: "folder.fill",
                            title: "参加プロジェクト",
                            value: "\(userProjects.count)"
                        )
                        
                        StatRowView(
                            icon: "checkmark.circle.fill",
                            title: "完了済みタスク",
                            value: "\(assignedTasks.filter { $0.isCompleted }.count)"
                        )
                        
                        StatRowView(
                            icon: "clock.fill",
                            title: "進行中タスク",
                            value: "\(assignedTasks.filter { !$0.isCompleted }.count)"
                        )
                        
                        if let totalEstimatedHours = assignedTasks.compactMap({ $0.estimatedHours }).reduce(0, +),
                           totalEstimatedHours > 0 {
                            StatRowView(
                                icon: "hourglass.fill",
                                title: "見積時間",
                                value: String(format: "%.1fh", totalEstimatedHours)
                            )
                        }
                    }
                }
            }
            .navigationTitle("メンバー詳細")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            if projectManager == nil {
                projectManager = await sharedManagers.getProjectManager()
            }
            await loadMemberData()
        }
    }
    
    private func loadMemberData() async {
        guard let userId = member.id else { return }
        
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await loadUserProjects(userId: userId)
            }
            
            group.addTask {
                await loadAssignedTasks(userId: userId)
            }
        }
    }
    
    @MainActor
    private func loadUserProjects(userId: String) async {
        isLoadingProjects = true
        defer { isLoadingProjects = false }
        
        do {
            let db = Firestore.firestore()
            let decoder = Firestore.Decoder()
            
            // ユーザーが参加しているプロジェクトを取得
            let projectSnapshot = try await db.collection("projects")
                .whereField("memberIds", arrayContains: userId)
                .getDocuments()
            
            let projects = try projectSnapshot.documents.compactMap { doc -> Project? in
                try doc.data(as: Project.self, decoder: decoder)
            }
            
            userProjects = projects.sorted { ($0.lastModifiedAt ?? Date.distantPast) > ($1.lastModifiedAt ?? Date.distantPast) }
            
        } catch {
            print("Error loading user projects: \(error)")
            userProjects = []
        }
    }
    
    @MainActor
    private func loadAssignedTasks(userId: String) async {
        isLoadingTasks = true
        defer { isLoadingTasks = false }
        
        do {
            let db = Firestore.firestore()
            let decoder = Firestore.Decoder()
            
            // ユーザーにアサインされているタスクを取得
            let taskSnapshot = try await db.collection("tasks")
                .whereField("assignedTo", isEqualTo: userId)
                .limit(to: 50) // 最大50件
                .getDocuments()
            
            let tasks = try taskSnapshot.documents.compactMap { doc -> ShigodekiTask? in
                try doc.data(as: ShigodekiTask.self, decoder: decoder)
            }
            
            assignedTasks = tasks.sorted { 
                // 未完了タスクを先に、その後作成日の新しい順
                if $0.isCompleted != $1.isCompleted {
                    return !$0.isCompleted && $1.isCompleted
                }
                return ($0.createdAt ?? Date.distantPast) > ($1.createdAt ?? Date.distantPast)
            }
            
        } catch {
            print("Error loading assigned tasks: \(error)")
            assignedTasks = []
        }
    }
}

struct MemberTaskRowView: View {
    let task: ShigodekiTask
    
    var body: some View {
        HStack {
            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundColor(task.isCompleted ? .green : .gray)
                .frame(width: 25)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.subheadline)
                    .strikethrough(task.isCompleted)
                    .foregroundColor(task.isCompleted ? .secondary : .primary)
                
                HStack {
                    if task.priority != .medium {
                        PriorityBadge(priority: task.priority)
                    }
                    
                    if let dueDate = task.dueDate {
                        Text("期限: \(DateFormatter.shortDate.string(from: dueDate))")
                            .font(.caption2)
                            .foregroundColor(dueDate < Date() && !task.isCompleted ? .red : .secondary)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 2)
    }
}

struct PriorityBadge: View {
    let priority: TaskPriority
    
    private var priorityColor: Color {
        switch priority {
        case .low: return .blue
        case .medium: return .orange
        case .high: return .red
        }
    }
    
    var body: some View {
        Text(priority.displayName)
            .font(.caption2)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(priorityColor.opacity(0.2))
            .foregroundColor(priorityColor)
            .cornerRadius(3)
    }
}

struct StatRowView: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 25)
            
            Text(title)
                .font(.subheadline)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
    }
}


#Preview {
    let sampleUser = User(
        name: "田中太郎",
        email: "tanaka@example.com",
        projectIds: ["project1", "project2"],
        roleAssignments: [:]
    )
    
    MemberDetailView(member: sampleUser)
}