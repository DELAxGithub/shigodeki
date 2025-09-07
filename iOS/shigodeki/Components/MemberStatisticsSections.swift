//
//  MemberStatisticsSections.swift
//  shigodeki
//
//  Created from MemberDetailSections split for CLAUDE.md compliance
//  Member statistics and completion tracking sections
//

import SwiftUI

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