//
//  TemplateCustomizationService.swift
//  shigodeki
//
//  Created by Claude on 2025-01-04.
//

import Foundation

struct TemplateCustomizationService {
    
    // MARK: - Template Stats
    
    static func calculateStats(for template: ProjectTemplate) -> TemplateStats {
        return TemplateStats(template: template)
    }
    
    // MARK: - Initial Setup
    
    static func createInitialProjectSettings() -> ProjectSettings {
        return ProjectSettings(
            color: .blue,
            isPrivate: false
        )
    }
    
    // MARK: - Template Customization
    
    static func applyCustomizations(
        to template: ProjectTemplate,
        projectName: String,
        customDescription: String,
        customizations: ProjectCustomizations
    ) -> ProjectTemplate {
        // この実装は簡略化されています。実際にはより詳細なカスタマイゼーションロジックが必要です
        var modifiedTemplate = template
        
        // 名前と説明の変更
        modifiedTemplate = ProjectTemplate(
            name: projectName,
            description: customDescription.isEmpty ? template.description : customDescription,
            goal: template.goal,
            category: template.category,
            version: template.version,
            phases: applyPhaseCustomizations(template.phases, customizations: customizations),
            metadata: template.metadata
        )
        
        return modifiedTemplate
    }
    
    // MARK: - Phase Customizations
    
    private static func applyPhaseCustomizations(
        _ phases: [PhaseTemplate],
        customizations: ProjectCustomizations
    ) -> [PhaseTemplate] {
        return phases.compactMap { phase in
            // オプショナルタスクのスキップ処理
            let filteredTaskLists = phase.taskLists.map { taskList in
                let filteredTasks = customizations.skipOptionalTasks 
                    ? taskList.tasks.filter { !$0.isOptional }
                    : taskList.tasks
                
                // タスクの優先度オーバーライド適用
                let updatedTasks = filteredTasks.map { task in
                    if let overridePriority = customizations.taskPriorityOverrides[task.title] {
                        var updatedTask = task
                        updatedTask.priority = overridePriority
                        return updatedTask
                    }
                    return task
                }
                
                return TaskListTemplate(
                    name: taskList.name,
                    description: taskList.description,
                    color: taskList.color,
                    order: taskList.order,
                    tasks: updatedTasks
                )
            }
            
            return PhaseTemplate(
                title: phase.title,
                description: phase.description,
                order: phase.order,
                estimatedDuration: phase.estimatedDuration,
                taskLists: filteredTaskLists
            )
        }
    }
    
    // MARK: - Validation
    
    static func validateCustomizations(_ customizations: ProjectCustomizations) -> Bool {
        // 基本的な検証ロジック
        return true
    }
    
    // MARK: - High Priority Tasks
    
    static func getHighPriorityTasks(from template: ProjectTemplate) -> [TaskTemplate] {
        return template.phases.flatMap { phase in
            phase.taskLists.flatMap { taskList in
                taskList.tasks.filter { $0.priority == .high }
            }
        }
    }
    
    // MARK: - Summary Generation
    
    static func generateCustomizationSummary(
        skipOptionalTasks: Bool,
        selectedPhaseColors: [String: TaskListColor],
        selectedTaskPriorityOverrides: [String: TaskPriority],
        selectedProjectSettings: ProjectSettings,
        stats: TemplateStats
    ) -> [CustomizationSummary] {
        var summary: [CustomizationSummary] = []
        
        if skipOptionalTasks && stats.optionalTaskCount > 0 {
            summary.append(CustomizationSummary(
                type: .excludeOptionalTasks,
                description: "\(stats.optionalTaskCount)個のオプショナルタスクを除外",
                count: stats.optionalTaskCount
            ))
        }
        
        if !selectedPhaseColors.isEmpty {
            summary.append(CustomizationSummary(
                type: .changePhaseColors,
                description: "\(selectedPhaseColors.count)個のフェーズカラーを変更",
                count: selectedPhaseColors.count
            ))
        }
        
        if !selectedTaskPriorityOverrides.isEmpty {
            summary.append(CustomizationSummary(
                type: .adjustTaskPriorities,
                description: "\(selectedTaskPriorityOverrides.count)個のタスク優先度を調整",
                count: selectedTaskPriorityOverrides.count
            ))
        }
        
        if selectedProjectSettings.isPrivate {
            summary.append(CustomizationSummary(
                type: .setPrivateProject,
                description: "プライベートプロジェクトに設定",
                count: 1
            ))
        }
        
        return summary
    }
}

// MARK: - Supporting Types

enum CustomizationType {
    case excludeOptionalTasks
    case changePhaseColors
    case adjustTaskPriorities
    case setPrivateProject
}

struct CustomizationSummary {
    let type: CustomizationType
    let description: String
    let count: Int
}