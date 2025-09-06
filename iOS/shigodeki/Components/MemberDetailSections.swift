//
//  MemberDetailSections.swift
//  shigodeki
//
//  Extracted from MemberDetailView.swift for CLAUDE.md compliance
//  Member detail view section components
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

// MARK: - Statistics Section

struct MemberStatisticsSection: View {
    let userProjects: [Project]
    let assignedTasks: [ShigodekiTask]
    
    private var completedTasks: Int {
        assignedTasks.filter { $0.isCompleted }.count
    }
    
    private var pendingTasks: Int {
        assignedTasks.filter { !$0.isCompleted }.count
    }
    
    private var completionRate: Double {
        guard !assignedTasks.isEmpty else { return 0.0 }
        return Double(completedTasks) / Double(assignedTasks.count)
    }
    
    var body: some View {
        Section("統計情報") {
            VStack(spacing: 16) {
                // Project and Task counts
                HStack(spacing: 20) {
                    StatisticCard(
                        title: "参加プロジェクト",
                        value: "\(userProjects.count)",
                        icon: "folder",
                        color: .blue
                    )
                    
                    StatisticCard(
                        title: "総タスク数",
                        value: "\(assignedTasks.count)",
                        icon: "checklist",
                        color: .green
                    )
                }
                
                // Completion statistics
                HStack(spacing: 20) {
                    StatisticCard(
                        title: "完了済み",
                        value: "\(completedTasks)",
                        icon: "checkmark.circle",
                        color: .green
                    )
                    
                    StatisticCard(
                        title: "進行中",
                        value: "\(pendingTasks)",
                        icon: "clock",
                        color: .orange
                    )
                }
                
                // Completion rate progress
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("完了率")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Text("\(Int(completionRate * 100))%")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    }
                    
                    ProgressView(value: completionRate)
                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                }
            }
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Supporting Components

struct ProjectRowCompact: View {
    let project: Project
    
    var body: some View {
        HStack {
            Circle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: 8, height: 8)
            
            Text(project.name)
                .font(.body)
            
            Spacer()
            
            // TODO: Project.status property doesn't exist yet
            // Text(project.status.displayName)
            //     .font(.caption)
            //     .padding(.horizontal, 8)
            //     .padding(.vertical, 2)
            //     .background(statusColor.opacity(0.2))
            //     .foregroundColor(statusColor)
            //     .cornerRadius(4)
        }
        .padding(.vertical, 4)
    }
    
    private var statusColor: Color {
        // TODO: Project.status property doesn't exist yet
        // switch project.status {
        // case .planning: return .blue
        // case .active: return .green
        // case .completed: return .gray
        // case .cancelled: return .red
        // }
        return .blue // temporary default
    }
}

struct TaskRowCompact: View {
    let task: ShigodekiTask
    
    var body: some View {
        HStack {
            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundColor(task.isCompleted ? .green : .gray)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.body)
                    .strikethrough(task.isCompleted)
                
                if let dueDate = task.dueDate {
                    Text("期限: \(DateFormatter.shortDate.string(from: dueDate))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            PriorityBadge(priority: task.priority)
        }
        .padding(.vertical, 4)
    }
}

struct StatisticCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct PriorityBadge: View {
    let priority: TaskPriority
    
    private var priorityColor: Color {
        switch priority {
        case .low: return .green
        case .medium: return .yellow
        case .high: return .orange
        // .critical case removed - doesn't exist in TaskPriority enum
        }
    }
    
    var body: some View {
        Text(priority.displayName)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(priorityColor.opacity(0.2))
            .foregroundColor(priorityColor)
            .cornerRadius(4)
    }
}