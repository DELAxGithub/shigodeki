//
//  TemplateCustomizationComponents.swift
//  shigodeki
//
//  Created by Claude on 2025-01-04.
//

import SwiftUI

// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.primaryBlue)
                .font(.title3)
            
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
            
            Spacer()
        }
    }
}

// MARK: - Stat Chip

struct StatChip: View {
    let icon: String
    let value: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color(.systemGray6))
        .cornerRadius(6)
    }
}

// MARK: - Color Selector Button

struct ColorSelectorButton: View {
    let color: TaskListColor
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Circle()
                    .fill(color.swiftUIColor)
                    .frame(width: 30, height: 30)
                    .overlay(
                        Circle()
                            .stroke(isSelected ? Color.primary : Color.clear, lineWidth: 2)
                    )
                
                Text(color.displayName)
                    .font(.caption2)
                    .foregroundColor(.primary)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Customization Summary Item

struct CustomizationSummaryItem: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(color)
            
            Text(text)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
}

// MARK: - Template Overview Section

struct TemplateOverviewSection: View {
    let template: ProjectTemplate
    let stats: TemplateStats
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(template.category.color.opacity(0.2))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: template.category.icon)
                        .font(.title2)
                        .foregroundColor(template.category.color)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(template.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if let description = template.description {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 12) {
                        StatChip(
                            icon: "list.bullet",
                            value: "\(stats.totalPhases)フェーズ"
                        )
                        StatChip(
                            icon: "square.grid.2x2",
                            value: "\(stats.totalTaskLists)リスト"
                        )
                        
                        StatChip(
                            icon: "checkmark.square",
                            value: "\(stats.totalTasks)タスク"
                        )
                        
                        StatChip(
                            icon: "clock",
                            value: stats.completionTimeRange
                        )
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
}

// MARK: - Project Settings Section

struct ProjectSettingsSection: View {
    @Binding var projectName: String
    @Binding var customDescription: String
    @Binding var selectedProjectSettings: ProjectSettings
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "プロジェクト設定", icon: "gear")
            
            VStack(spacing: 16) {
                // プロジェクト名
                VStack(alignment: .leading, spacing: 8) {
                    Text("プロジェクト名")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    TextField("プロジェクト名を入力", text: $projectName)
                        .textFieldStyle(.roundedBorder)
                }
                
                // カスタム説明
                VStack(alignment: .leading, spacing: 8) {
                    Text("説明（オプション）")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    TextEditor(text: $customDescription)
                        .frame(height: 80)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(.systemGray4), lineWidth: 1)
                        )
                }
                
                // プロジェクトカラー
                VStack(alignment: .leading, spacing: 8) {
                    Text("プロジェクトカラー")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(TaskListColor.allCases, id: \.rawValue) { color in
                                ColorSelectorButton(
                                    color: color,
                                    isSelected: selectedProjectSettings.color == color
                                ) {
                                    selectedProjectSettings = ProjectSettings(
                                        color: color,
                                        isPrivate: selectedProjectSettings.isPrivate
                                    )
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                // プライベート設定
                Toggle("プライベートプロジェクト", isOn: Binding(
                    get: { selectedProjectSettings.isPrivate },
                    set: { newValue in
                        selectedProjectSettings = ProjectSettings(
                            color: selectedProjectSettings.color,
                            isPrivate: newValue
                        )
                    }
                ))
            }
        }
    }
}

// MARK: - Task Options Section

struct TaskOptionsSection: View {
    @Binding var skipOptionalTasks: Bool
    @Binding var showAdvancedOptions: Bool
    let stats: TemplateStats
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "タスクオプション", icon: "checkmark.square")
            
            VStack(spacing: 16) {
                // オプショナルタスクをスキップ
                if stats.optionalTaskCount > 0 {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("オプショナルタスクをスキップ", isOn: $skipOptionalTasks)
                        
                        if skipOptionalTasks {
                            Text("\(stats.optionalTaskCount)個のオプショナルタスクが除外されます")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // 高度なオプションの表示切り替え
                Button {
                    withAnimation {
                        showAdvancedOptions.toggle()
                    }
                } label: {
                    HStack {
                        Image(systemName: showAdvancedOptions ? "chevron.up" : "chevron.down")
                            .foregroundColor(.primaryBlue)
                        
                        Text("高度なオプション")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primaryBlue)
                        
                        Spacer()
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

// MARK: - Phase Color Customization Section

struct PhaseColorCustomizationSection: View {
    let template: ProjectTemplate
    @Binding var selectedPhaseColors: [String: TaskListColor]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("フェーズカラー")
                .font(.subheadline)
                .fontWeight(.medium)
            
            VStack(spacing: 12) {
                ForEach(template.phases, id: \.id) { phase in
                    HStack {
                        Text(phase.title)
                            .font(.caption)
                        
                        Spacer()
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(TaskListColor.allCases, id: \.rawValue) { color in
                                    Button {
                                        selectedPhaseColors[phase.title] = color
                                    } label: {
                                        Circle()
                                            .fill(color.swiftUIColor)
                                            .frame(width: 24, height: 24)
                                            .overlay(
                                                Circle()
                                                    .stroke(
                                                        selectedPhaseColors[phase.title] == color ? Color.primary : Color.clear,
                                                        lineWidth: 2
                                                    )
                                            )
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Task Priority Customization Section

struct TaskPriorityCustomizationSection: View {
    let template: ProjectTemplate
    @Binding var selectedTaskPriorityOverrides: [String: TaskPriority]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("タスク優先度の調整")
                .font(.subheadline)
                .fontWeight(.medium)
            
            Text("高優先度のタスクをさらに調整できます")
                .font(.caption)
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                let highPriorityTasks = template.phases.flatMap { phase in
                    phase.taskLists.flatMap { taskList in
                        taskList.tasks.filter { $0.priority == .high }
                    }
                }
                
                if !highPriorityTasks.isEmpty {
                    ForEach(highPriorityTasks.prefix(5), id: \.id) { task in
                        HStack {
                            Text(task.title)
                                .font(.caption)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Menu {
                                ForEach(TaskPriority.allCases, id: \.rawValue) { priority in
                                    Button {
                                        selectedTaskPriorityOverrides[task.title] = priority
                                    } label: {
                                        HStack {
                                            Text(priority.displayName)
                                            if selectedTaskPriorityOverrides[task.title] == priority ||
                                                (selectedTaskPriorityOverrides[task.title] == nil && task.priority == priority) {
                                                Spacer()
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack {
                                    let currentPriority = selectedTaskPriorityOverrides[task.title] ?? task.priority
                                    Text(currentPriority.displayName)
                                        .font(.caption)
                                        .foregroundColor(currentPriority.swiftUIColor)
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(.systemGray6))
                                .cornerRadius(6)
                            }
                        }
                    }
                    
                    if highPriorityTasks.count > 5 {
                        Text("他 \(highPriorityTasks.count - 5) 件の高優先度タスク...")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("高優先度のタスクはありません")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
        }
    }
}

// MARK: - Preview Section

struct TemplatePreviewSection: View {
    let projectName: String
    let customDescription: String
    let selectedProjectSettings: ProjectSettings
    let skipOptionalTasks: Bool
    let selectedPhaseColors: [String: TaskListColor]
    let selectedTaskPriorityOverrides: [String: TaskPriority]
    let stats: TemplateStats
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "プレビュー", icon: "eye")
            
            VStack(alignment: .leading, spacing: 12) {
                // 最終的なプロジェクト設定表示
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Circle()
                            .fill(selectedProjectSettings.color.swiftUIColor)
                            .frame(width: 12, height: 12)
                        
                        Text(projectName)
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        if selectedProjectSettings.isPrivate {
                            Image(systemName: "lock.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    
                    if !customDescription.isEmpty {
                        Text(customDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // 変更点サマリー
                VStack(alignment: .leading, spacing: 8) {
                    Text("カスタマイズ内容:")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    if skipOptionalTasks && stats.optionalTaskCount > 0 {
                        CustomizationSummaryItem(
                            icon: "minus.circle",
                            text: "\(stats.optionalTaskCount)個のオプショナルタスクを除外",
                            color: .orange
                        )
                    }
                    
                    if !selectedPhaseColors.isEmpty {
                        CustomizationSummaryItem(
                            icon: "paintbrush",
                            text: "\(selectedPhaseColors.count)個のフェーズカラーを変更",
                            color: .blue
                        )
                    }
                    
                    if !selectedTaskPriorityOverrides.isEmpty {
                        CustomizationSummaryItem(
                            icon: "arrow.up.arrow.down",
                            text: "\(selectedTaskPriorityOverrides.count)個のタスク優先度を調整",
                            color: .green
                        )
                    }
                    
                    if selectedProjectSettings.isPrivate {
                        CustomizationSummaryItem(
                            icon: "lock",
                            text: "プライベートプロジェクトに設定",
                            color: .purple
                        )
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGroupedBackground))
            )
        }
    }
}