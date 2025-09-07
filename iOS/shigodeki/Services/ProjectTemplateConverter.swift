//
//  ProjectTemplateConverter.swift
//  shigodeki
//
//  Created by Claude on 2025-08-29.
//

import Foundation

struct ProjectTemplateConverter {
    
    static func convertToTemplate(project: Project,
                                  phases: [Phase],
                                  taskLists: [String: [TaskList]],
                                  tasks: [String: [ShigodekiTask]],
                                  subtasks: [String: [Subtask]],
                                  options: TemplateExportOptions) throws -> ProjectTemplate {
        
        // フェーズテンプレート変換
        let phaseTemplates = try phases.sorted { $0.order < $1.order }.map { phase in
            try convertPhaseToTemplate(
                phase: phase,
                taskLists: taskLists[phase.id ?? ""] ?? [],
                tasks: tasks,
                subtasks: subtasks,
                options: options
            )
        }
        
        // メタデータ作成
        let metadata = createMetadata(from: project, options: options)
        
        // カテゴリ推定
        let category = estimateCategory(from: project, phases: phases, tasks: tasks)
        
        let template = ProjectTemplate(
            name: options.anonymizeData ? "プロジェクトテンプレート" : project.name,
            description: options.anonymizeData ? "エクスポートされたテンプレート" : project.description,
            goal: nil,
            category: category,
            version: "1.0",
            phases: phaseTemplates,
            metadata: metadata
        )
        
        return template
    }
    
    static func convertPhaseToTemplate(phase: Phase,
                                       taskLists: [TaskList],
                                       tasks: [String: [ShigodekiTask]],
                                       subtasks: [String: [Subtask]],
                                       options: TemplateExportOptions) throws -> PhaseTemplate {
        
        let sortedTaskLists = taskLists.sorted { $0.order < $1.order }
        let taskListTemplates = sortedTaskLists.compactMap { taskList -> TaskListTemplate? in
            let taskTemplates = convertTasksToTemplates(
                tasks: tasks[taskList.id ?? ""] ?? [],
                subtasks: subtasks,
                options: options
            )
            
            // 空のタスクリストをスキップするかどうか
            if taskTemplates.isEmpty && !options.includeOptionalTasks {
                return nil
            }
            
            return TaskListTemplate(
                name: taskList.name,
                description: nil,
                color: taskList.color,
                order: taskList.order,
                tasks: taskTemplates
            )
        }
        
        return PhaseTemplate(
            title: phase.name,
            description: phase.description,
            order: phase.order,
            prerequisites: [],
            templateReference: nil,
            estimatedDuration: nil,
            taskLists: taskListTemplates.isEmpty ? [TaskListTemplate.defaultTaskList] : taskListTemplates
        )
    }
    
    static func convertTasksToTemplates(tasks: [ShigodekiTask],
                                        subtasks: [String: [Subtask]],
                                        options: TemplateExportOptions) -> [TaskTemplate] {
        
        return tasks.compactMap { task -> TaskTemplate? in
            // 完了済みタスクを含めるかチェック
            if task.isCompleted && !options.includeCompletedTasks {
                return nil
            }
            
            // サブタスク変換
            let subtaskTemplates: [SubtaskTemplate]
            if options.includeSubtasks {
                subtaskTemplates = (subtasks[task.id ?? ""] ?? []).map { subtask in
                    SubtaskTemplate(
                        title: subtask.title,
                        description: subtask.description,
                        estimatedDuration: nil,
                        isOptional: false
                    )
                }
            } else {
                subtaskTemplates = []
            }
            
            // 推定時間
            let estimatedHours = options.includeEstimates ? task.estimatedHours : nil
            
            return TaskTemplate(
                title: task.title,
                description: task.description,
                priority: task.priority,
                estimatedDuration: nil,
                deadline: nil,
                tags: task.tags,
                templateLinks: nil,
                isOptional: false,
                estimatedHours: estimatedHours,
                dependsOn: task.dependsOn,
                subtasks: subtaskTemplates
            )
        }
    }
    
    static func createMetadata(from project: Project, options: TemplateExportOptions) -> TemplateMetadata {
        let author = options.anonymizeData ? "Anonymous" : "Exported from Shigodeki"
        
        return TemplateMetadata(
            author: author,
            createdAt: ISO8601DateFormatter().string(from: Date()),
            estimatedDuration: nil,
            difficulty: .intermediate,
            tags: ["exported"],
            language: "ja",
            requiredSkills: nil,
            targetAudience: nil
        )
    }
    
    static func estimateCategory(from project: Project, 
                                 phases: [Phase], 
                                 tasks: [String: [ShigodekiTask]]) -> TemplateCategory {
        
        let allTasks = tasks.values.flatMap { $0 }
        let allTaskTitles = allTasks.map { $0.title.lowercased() }
        let allTaskTags = allTasks.flatMap { $0.tags.map { $0.lowercased() } }
        let allText = (allTaskTitles + allTaskTags + [project.name.lowercased()]).joined(separator: " ")
        
        // キーワードベースでカテゴリを推定
        if allText.contains("開発") || allText.contains("プログラム") || allText.contains("アプリ") || allText.contains("web") {
            return .softwareDevelopment
        } else if allText.contains("イベント") || allText.contains("企画") || allText.contains("パーティ") {
            return .eventPlanning
        } else if allText.contains("結婚") || allText.contains("引越") || allText.contains("終活") {
            return .lifeEvents
        } else if allText.contains("ビジネス") || allText.contains("営業") || allText.contains("売上") {
            return .business
        } else if allText.contains("学習") || allText.contains("教育") || allText.contains("勉強") {
            return .education
        } else if allText.contains("デザイン") || allText.contains("創作") || allText.contains("アート") {
            return .creative
        } else if allText.contains("健康") || allText.contains("フィットネス") || allText.contains("運動") {
            return .health
        } else if allText.contains("旅行") || allText.contains("旅") || allText.contains("観光") {
            return .travel
        }
        
        return .projectManagement
    }
}