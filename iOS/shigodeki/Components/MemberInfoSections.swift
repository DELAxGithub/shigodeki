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
                        
                        if let displayEmail = EmailDisplayUtility.displayableEmail(member.email) {
                            Text(displayEmail)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
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
        if let displayEmail = EmailDisplayUtility.displayableEmail(member.email) {
            Section("連絡先") {
                HStack {
                    Image(systemName: "envelope")
                        .foregroundColor(.blue)
                        .frame(width: 20)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("メールアドレス")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(displayEmail)
                            .font(.body)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        if let emailURL = URL(string: "mailto:\(displayEmail)") {
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
}

// MARK: - Projects Section

struct MemberProjectsSection: View {
    let userProjects: [Project]
    let isLoadingProjects: Bool
    let onTapProject: (Project) -> Void
    
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
                    Button {
                        onTapProject(project)
                    } label: {
                        ProjectRowCompact(project: project)
                    }
                    .buttonStyle(.plain)
                    .interactiveEffect()
                }
            }
        }
    }
}

// MARK: - Assigned Tasks Section

struct MemberAssignedTasksSection: View {
    let assignedTasks: [ShigodekiTask]
    let isLoadingTasks: Bool
    // Optional: project/phase name lookups
    let projectNamesById: [String: String]
    let phasesByProject: [String: [Phase]]
    let onTapTask: (ShigodekiTask) -> Void
    
    init(
        assignedTasks: [ShigodekiTask],
        isLoadingTasks: Bool,
        projectNamesById: [String: String] = [:],
        phasesByProject: [String: [Phase]] = [:],
        onTapTask: @escaping (ShigodekiTask) -> Void
    ) {
        self.assignedTasks = assignedTasks
        self.isLoadingTasks = isLoadingTasks
        self.projectNamesById = projectNamesById
        self.phasesByProject = phasesByProject
        self.onTapTask = onTapTask
    }
    
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
                // Group by Project > Phase
                let byProject = Dictionary(grouping: assignedTasks, by: { $0.projectId })
                let sortedProjectIds = byProject.keys.sorted { (a, b) in
                    let na = projectNamesById[a] ?? a
                    let nb = projectNamesById[b] ?? b
                    return na.localizedCaseInsensitiveCompare(nb) == .orderedAscending
                }
                ForEach(sortedProjectIds, id: \.self) { pid in
                    let projectName = projectNamesById[pid] ?? (pid.isEmpty ? "(不明なプロジェクト)" : pid)
                    // Project header
                    HStack {
                        Text(projectName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.top, 6)
                    
                    let tasksInProject = byProject[pid] ?? []
                    let byPhase = Dictionary(grouping: tasksInProject, by: { $0.phaseId })
                    let phaseNameMap: [String: String] = Dictionary(uniqueKeysWithValues: (phasesByProject[pid] ?? []).compactMap { ph in (ph.id ?? "", ph.name) })
                    let sortedPhaseIds = byPhase.keys.sorted { (a, b) in
                        let na = phaseNameMap[a] ?? a
                        let nb = phaseNameMap[b] ?? b
                        return na.localizedCaseInsensitiveCompare(nb) == .orderedAscending
                    }
                    ForEach(sortedPhaseIds, id: \.self) { phid in
                        // Phase header
                        HStack {
                            Text(phaseNameMap[phid] ?? "(フェーズ)")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                                .padding(.leading, 8)
                            Spacer()
                        }
                        
                        ForEach(byPhase[phid] ?? []) { task in
                            Button { onTapTask(task) } label: {
                                TaskRowCompact(task: task)
                            }
                            .buttonStyle(.plain)
                            .interactiveEffect()
                        }
                    }
                }
            }
        }
    }
}
