//
//  TemplatePreviewView.swift
//  shigodeki
//
//  Created by Claude on 2025-08-29.
//

import SwiftUI

struct TemplatePreviewView: View {
    let template: ProjectTemplate
    @Binding var isPresented: Bool
    let onSelect: (ProjectTemplate) -> Void
    
    @State private var selectedPhaseIndex = 0
    @State private var showCustomizationSheet = false
    @State private var customizations = ProjectCustomizations()
    @State private var projectName = ""
    
    private var stats: TemplateStats {
        TemplateStats(template: template)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // ヘッダー
                    templateHeaderSection
                    
                    // 統計情報
                    statisticsSection
                    
                    // フェーズプレビュー
                    phasesPreviewSection
                    
                    // 詳細情報
                    detailsSection
                    
                    // メタデータ
                    metadataSection
                }
                .padding()
            }
            .navigationTitle("テンプレートプレビュー")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("キャンセル") {
                    isPresented = false
                },
                trailing: Menu {
                    menuContent
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            )
        }
        .onAppear {
            projectName = template.name
        }
        .sheet(isPresented: $showCustomizationSheet) {
            TemplateCustomizationView(
                template: template,
                projectName: $projectName,
                customizations: $customizations,
                isPresented: $showCustomizationSheet,
                onConfirm: { customizedTemplate in
                    onSelect(customizedTemplate)
                    isPresented = false
                }
            )
        }
    }
    
    // MARK: - View Sections
    
    private var templateHeaderSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                // カテゴリアイコン
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(template.category.color.opacity(0.2))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: template.category.icon)
                        .font(.title)
                        .foregroundColor(template.category.color)
                }
                
                // 基本情報
                VStack(alignment: .leading, spacing: 8) {
                    Text(template.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if let description = template.description {
                        Text(description)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    
                    if let goal = template.goal {
                        Label(goal, systemImage: "target")
                            .font(.caption)
                            .foregroundColor(.primaryBlue)
                    }
                    
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Image(systemName: "folder")
                                .font(.caption)
                                .foregroundColor(template.category.color)
                            Text(template.category.displayName)
                                .font(.caption)
                                .foregroundColor(template.category.color)
                        }
                        
                        DifficultyBadge(difficulty: template.metadata.difficulty)
                    }
                }
                
                Spacer()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGroupedBackground))
        )
    }
    
    private var statisticsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("プロジェクト概要")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                StatCard(
                    icon: "list.bullet",
                    title: "フェーズ数",
                    value: "\(stats.totalPhases)",
                    color: .primaryBlue
                )
                
                StatCard(
                    icon: "checkmark.square",
                    title: "総タスク数",
                    value: "\(stats.totalTasks)",
                    color: .success
                )
                
                StatCard(
                    icon: "clock",
                    title: "推定期間",
                    value: stats.completionTimeRange,
                    color: .warning
                )
                
                StatCard(
                    icon: "list.dash",
                    title: "サブタスク",
                    value: "\(stats.totalSubtasks)",
                    color: .secondary
                )
                
                StatCard(
                    icon: "percent",
                    title: "複雑度",
                    value: stats.complexityLevel.displayName,
                    color: stats.averagePhaseComplexity > 15.0 ? .error : .success
                )
                
                if stats.optionalTaskCount > 0 {
                    StatCard(
                        icon: "questionmark.square.dashed",
                        title: "オプション",
                        value: "\(stats.optionalTaskCount)",
                        color: .purple
                    )
                }
            }
        }
    }
    
    private var phasesPreviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("フェーズプレビュー")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(selectedPhaseIndex + 1) / \(template.phases.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // フェーズナビゲーション
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(template.phases.indices, id: \.self) { index in
                        let phase = template.phases[index]
                        PhaseNavigationButton(
                            phase: phase,
                            isSelected: index == selectedPhaseIndex
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedPhaseIndex = index
                            }
                        }
                    }
                }
                .padding(.horizontal, 1)
            }
            
            // 選択されたフェーズの詳細
            if template.phases.indices.contains(selectedPhaseIndex) {
                PhaseDetailView(phase: template.phases[selectedPhaseIndex])
            }
        }
    }
    
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("詳細情報")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                if !template.metadata.tags.isEmpty {
                    DetailRow(
                        title: "タグ",
                        icon: "tag",
                        content: AnyView(
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(template.metadata.tags, id: \.self) { tag in
                                        Text(tag)
                                            .font(.caption)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color(.systemGray5))
                                            .foregroundColor(.secondary)
                                            .cornerRadius(8)
                                    }
                                }
                            }
                        )
                    )
                }
                
                if let estimatedDuration = template.metadata.estimatedDuration {
                    DetailRow(
                        title: "推定期間",
                        icon: "calendar",
                        content: AnyView(
                            Text(estimatedDuration)
                                .font(.body)
                        )
                    )
                }
                
                if let targetAudience = template.metadata.targetAudience {
                    DetailRow(
                        title: "対象者",
                        icon: "person.3",
                        content: AnyView(
                            Text(targetAudience)
                                .font(.body)
                        )
                    )
                }
                
                if let requiredSkills = template.metadata.requiredSkills, !requiredSkills.isEmpty {
                    DetailRow(
                        title: "必要スキル",
                        icon: "brain.head.profile",
                        content: AnyView(
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(requiredSkills, id: \.self) { skill in
                                    HStack {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.success)
                                            .font(.caption)
                                        Text(skill)
                                            .font(.caption)
                                    }
                                }
                            }
                        )
                    )
                }
            }
        }
    }
    
    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("テンプレート情報")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                MetadataRow(title: "作成者", value: template.metadata.author)
                MetadataRow(title: "バージョン", value: template.version)
                MetadataRow(title: "言語", value: template.metadata.language.uppercased())
                
                if let date = ISO8601DateFormatter().date(from: template.metadata.createdAt) {
                    MetadataRow(
                        title: "作成日",
                        value: DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .none)
                    )
                }
            }
        }
    }
    
    private var menuContent: some View {
        Group {
            Button {
                showCustomizationSheet = true
            } label: {
                Label("カスタマイズして使用", systemImage: "slider.horizontal.3")
            }
            
            Button {
                onSelect(template)
                isPresented = false
            } label: {
                Label("そのまま使用", systemImage: "plus.circle")
            }
            
            Divider()
            
            Button {
                shareTemplate()
            } label: {
                Label("共有", systemImage: "square.and.arrow.up")
            }
            
            Button {
                exportTemplate()
            } label: {
                Label("エクスポート", systemImage: "square.and.arrow.down")
            }
        }
    }
    
    // MARK: - Actions
    
    private func shareTemplate() {
        // テンプレート共有機能（将来実装）
    }
    
    private func exportTemplate() {
        // テンプレートエクスポート機能（将来実装）
    }
}

// MARK: - Supporting Views

struct PhaseNavigationButton: View {
    let phase: PhaseTemplate
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text("\(phase.order + 1)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(isSelected ? .white : .primaryBlue)
                    .frame(width: 24, height: 24)
                    .background(
                        Circle()
                            .fill(isSelected ? Color.primaryBlue : Color.primaryBlue.opacity(0.2))
                    )
                
                Text(phase.title)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .primaryBlue : .secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: 80)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct PhaseDetailView: View {
    let phase: PhaseTemplate
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // フェーズヘッダー
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(phase.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Text("フェーズ \(phase.order + 1)")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.primaryBlue.opacity(0.2))
                        .foregroundColor(.primaryBlue)
                        .cornerRadius(8)
                }
                
                if let description = phase.description {
                    Text(description)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                
                if let duration = phase.estimatedDuration {
                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(.warning)
                        Text("推定期間: \(duration)")
                            .font(.caption)
                            .foregroundColor(.warning)
                    }
                }
                
                if !phase.prerequisites.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("前提条件:")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        ForEach(phase.prerequisites, id: \.self) { prerequisite in
                            HStack {
                                Image(systemName: "arrow.right.circle")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                                Text(prerequisite)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            
            // タスクリスト
            ForEach(phase.taskLists, id: \.id) { taskList in
                TaskListPreview(taskList: taskList)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGroupedBackground))
        )
    }
}

struct TaskListPreview: View {
    let taskList: TaskListTemplate
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // タスクリストヘッダー
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Circle()
                        .fill(taskList.color.swiftUIColor.opacity(0.2))
                        .frame(width: 8, height: 8)
                    
                    Text(taskList.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("(\(taskList.tasks.count))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            // タスクリスト（展開時）
            if isExpanded {
                VStack(spacing: 6) {
                    ForEach(taskList.tasks.prefix(5), id: \.id) { task in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "circle")
                                .foregroundColor(.secondary)
                                .font(.caption)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(task.title)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                    
                                    Spacer()
                                    
                                    PriorityIndicator(priority: task.priority)
                                }
                                
                                if let description = task.description {
                                    Text(description)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                }
                                
                                if !task.tags.isEmpty {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 4) {
                                            ForEach(task.tags.prefix(3), id: \.self) { tag in
                                                Text(tag)
                                                    .font(.caption2)
                                                    .padding(.horizontal, 4)
                                                    .padding(.vertical, 1)
                                                    .background(Color(.systemGray6))
                                                    .cornerRadius(4)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.leading)
                    }
                    
                    if taskList.tasks.count > 5 {
                        Text("他 \(taskList.tasks.count - 5) 件のタスク...")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.leading)
                    }
                }
            }
        }
    }
}

struct StatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            VStack(spacing: 2) {
                Text(value)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGroupedBackground))
        )
    }
}

struct DetailRow: View {
    let title: String
    let icon: String
    let content: AnyView
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.primaryBlue)
                    .font(.subheadline)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
            }
            
            content
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGroupedBackground))
        )
    }
}

struct MetadataRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

struct PriorityIndicator: View {
    let priority: TaskPriority
    
    var body: some View {
        Text(priority.displayName)
            .font(.caption2)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(priority.swiftUIColor.opacity(0.2))
            .foregroundColor(priority.swiftUIColor)
            .cornerRadius(4)
    }
}

// MARK: - Preview

struct TemplatePreviewView_Previews: PreviewProvider {
    static var previews: some View {
        TemplatePreviewView(
            template: BuiltInTemplates.sampleWebsiteTemplate,
            isPresented: .constant(true),
            onSelect: { _ in }
        )
    }
}