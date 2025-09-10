//
//  OptimizedProjectRow.swift
//  shigodeki
//
//  Created by Claude on 2025-08-29.
//

import SwiftUI

/// パフォーマンス最適化されたプロジェクト行コンポーネント
/// PerformanceOptimization.swiftの機能を活用
struct OptimizedProjectRow: View {
    let project: Project
    @State private var fallbackPhases: Int? = nil
    @State private var fallbackTasks: Int? = nil
    
    // パフォーマンス最適化のための状態
    @State private var isPressed = false
    @State private var lastAccessTime = Date()
    
    var body: some View {
        HStack(spacing: 16) {
            
            // プロジェクトアイコン（キャッシュ付き）
            ProjectIconView(project: project)
            
            // プロジェクト情報
            VStack(alignment: .leading, spacing: 4) {
                // プロジェクト名
                HStack(spacing: 6) {
                    Text(project.name)
                    .font(.headline)
                    .lineLimit(1)
                    .foregroundColor(.primary)
                    OwnerBadge(ownerType: project.ownerType)
                }
                
                // 説明文（遅延表示）
                if let description = project.description {
                    Text(description)
                        .font(.subheadline)
                        .lineLimit(2)
                        .foregroundColor(.secondary)
                        .lazyLoading() // 🆕 遅延読み込み適用
                }
                
                // プロジェクト統計
                ProjectStatsView(project: project)
                    .onAppear { Task { await loadFallbackStatsIfNeeded() } }
            }
            
            Spacer()
            
            // 最終更新時間
            VStack(alignment: .trailing, spacing: 4) {
                if let lastModified = project.lastModifiedAt {
                    Text(RelativeDateTimeFormatter().localizedString(for: lastModified, relativeTo: Date()))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(Color(.tertiaryLabel))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
                .opacity(isPressed ? 0.8 : 1.0)
        )
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .contentShape(Rectangle())
        // 内部タップは持たない（NavigationLinkのタップを優先）
        .onAppear {
            // パフォーマンス監視
            InstrumentsSetup.shared.logMemoryUsage(context: "ProjectRow Appeared")
        }
    }
}

// MARK: - Sub Components

/// プロジェクトアイコンビュー（キャッシュ機能付き）
struct ProjectIconView: View {
    let project: Project
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.blue.opacity(0.1))
                .frame(width: 50, height: 50)
            
            // プロジェクトタイプに応じたアイコン
            Image(systemName: projectIconName)
                .font(.title2)
                .foregroundColor(.blue)
        }
    }
    
    private var projectIconName: String {
        // プロジェクト名や説明からアイコンを推定
        if project.name.lowercased().contains("web") {
            return "globe"
        } else if project.name.lowercased().contains("mobile") || project.name.lowercased().contains("app") {
            return "iphone"
        } else if project.name.lowercased().contains("design") {
            return "paintbrush"
        } else {
            return "folder"
        }
    }
}

/// プロジェクト統計ビュー（遅延読み込み）
struct ProjectStatsView: View {
    let project: Project
    
    var body: some View {
        LazyLoadingView(threshold: 30) {
            HStack(spacing: 12) {
                
                // フェーズ数
                ProjectStatItem(
                    icon: "list.number",
                    value: "\(project.statistics?.totalPhases ?? 0)",
                    label: "フェーズ"
                )
                
                // タスク数
                ProjectStatItem(
                    icon: "checkmark.circle",
                    value: "\(project.statistics?.totalTasks ?? 0)",
                    label: "タスク"
                )
                
                // 完了率（フォールバックは非表示）
                if let stats = project.statistics {
                    let completionRate = stats.totalTasks > 0 ? Int((Double(stats.completedTasks) / Double(stats.totalTasks)) * 100) : 0
                    ProjectStatItem(icon: "percent", value: "\(completionRate)%", label: "完了")
                }
            }
        }
    }
}

/// 統計アイテム (OptimizedProjectRow専用)
struct ProjectStatItem: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.caption)
                    .fontWeight(.semibold)
                
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct OwnerBadge: View {
    let ownerType: ProjectOwnerType
    var body: some View {
        Text(ownerType == .family ? "チーム" : "個人")
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(ownerType == .family ? Color.blue.opacity(0.15) : Color.gray.opacity(0.15))
            .foregroundColor(ownerType == .family ? .blue : .secondary)
            .cornerRadius(4)
    }
}

// MARK: - Performance Extensions

extension OptimizedProjectRow {
    
    /// パフォーマンス監視付きのViewリターン
    func withPerformanceMonitoring() -> some View {
        self.background(
            PerformanceMonitorView(elementName: "ProjectRow")
        )
    }
    
    private func loadFallbackStatsIfNeeded() async {
        if project.statistics != nil { return }
        guard let pid = project.id else { return }
        let phaseManager = PhaseManager()
        do {
            let phases = try await phaseManager.getPhases(projectId: pid)
            await MainActor.run { fallbackPhases = phases.count }
            let taskManager = EnhancedTaskManager()
            var total = 0
            for ph in phases {
                if let phid = ph.id {
                    let tasks = try await taskManager.getPhaseTasks(phaseId: phid, projectId: pid)
                    total += tasks.count
                }
            }
            await MainActor.run { fallbackTasks = total }
        } catch {
            // ignore
        }
    }
}

/// パフォーマンス監視用の透明なビュー
struct PerformanceMonitorView: View {
    let elementName: String
    @StateObject private var performanceMonitor = PerformanceMonitor.shared
    
    var body: some View {
        Color.clear
            .onAppear {
                InstrumentsSetup.shared.startUIResponseMeasurement(action: "\(elementName) Render")
            }
            .onDisappear {
                InstrumentsSetup.shared.endUIResponseMeasurement(action: "\(elementName) Render")
            }
    }
}

// MARK: - Preview

#if DEBUG
struct OptimizedProjectRow_Previews: PreviewProvider {
    static var previews: some View {
        let sampleProject = Project(
            name: "Sample Mobile App Project",
            description: "A sample project with detailed description for testing the optimized row component",
            ownerId: "user1"
        )
        
        VStack(spacing: 8) {
            OptimizedProjectRow(project: sampleProject)
            OptimizedProjectRow(project: sampleProject)
            OptimizedProjectRow(project: sampleProject)
        }
        .padding()
        .background(Color(.systemBackground))
        .previewLayout(.sizeThatFits)
    }
}
#endif
