//
//  TemplateExporter.swift
//  shigodeki
//
//  Created by Claude on 2025-08-29.
//

import Foundation

class TemplateExporter: ObservableObject {
    
    enum ExportError: LocalizedError {
        case noPhases
        case noTasks
        case encodingFailed
        case fileWriteFailed(String)
        case permissionDenied
        
        var errorDescription: String? {
            switch self {
            case .noPhases:
                return "プロジェクトにフェーズがありません"
            case .noTasks:
                return "エクスポートするタスクがありません"
            case .encodingFailed:
                return "JSONエンコードに失敗しました"
            case .fileWriteFailed(let path):
                return "ファイルの書き込みに失敗しました: \(path)"
            case .permissionDenied:
                return "ファイルへの書き込み権限がありません"
            }
        }
    }
    
    struct ExportOptions {
        let includeCompletedTasks: Bool
        let includeOptionalTasks: Bool
        let includeSubtasks: Bool
        let includeEstimates: Bool
        let includeStatistics: Bool
        let anonymizeData: Bool
        let exportFormat: ExportFormat
        
        init(includeCompletedTasks: Bool = true,
             includeOptionalTasks: Bool = true,
             includeSubtasks: Bool = true,
             includeEstimates: Bool = true,
             includeStatistics: Bool = false,
             anonymizeData: Bool = false,
             exportFormat: ExportFormat = .projectTemplate) {
            self.includeCompletedTasks = includeCompletedTasks
            self.includeOptionalTasks = includeOptionalTasks
            self.includeSubtasks = includeSubtasks
            self.includeEstimates = includeEstimates
            self.includeStatistics = includeStatistics
            self.anonymizeData = anonymizeData
            self.exportFormat = exportFormat
        }
        
        static let `default` = ExportOptions()
        static let minimal = ExportOptions(
            includeCompletedTasks: false,
            includeSubtasks: false,
            includeEstimates: false
        )
        static let anonymous = ExportOptions(
            includeStatistics: false,
            anonymizeData: true
        )
    }
    
    enum ExportFormat {
        case projectTemplate    // 標準のProjectTemplate形式
        case legacySteps       // 旧形式のsteps形式（ツルツルテンプレート互換）
        case minimal           // 最小限のデータのみ
    }
    
    @Published var isExporting = false
    @Published var lastExportResult: URL?
    @Published var lastExportError: ExportError?
    
    // MARK: - Public Methods
    
    func exportProject(_ project: Project, 
                      phases: [Phase] = [],
                      taskLists: [String: [TaskList]] = [:],
                      tasks: [String: [ShigodekiTask]] = [:],
                      subtasks: [String: [Subtask]] = [:],
                      options: ExportOptions = .default) async throws -> ProjectTemplate {
        
        await MainActor.run {
            isExporting = true
            lastExportError = nil
        }
        
        defer {
            Task { @MainActor in
                isExporting = false
            }
        }
        
        // フェーズの検証
        guard !phases.isEmpty else {
            let error = ExportError.noPhases
            await MainActor.run {
                lastExportError = error
            }
            throw error
        }
        
        // テンプレート変換
        let template = try await convertToTemplate(
            project: project,
            phases: phases,
            taskLists: taskLists,
            tasks: tasks,
            subtasks: subtasks,
            options: options
        )
        
        return template
    }
    
    func exportToJSON(_ project: Project,
                     phases: [Phase] = [],
                     taskLists: [String: [TaskList]] = [:],
                     tasks: [String: [ShigodekiTask]] = [:],
                     subtasks: [String: [Subtask]] = [:],
                     options: ExportOptions = .default) async throws -> Data {
        
        let template = try await exportProject(
            project,
            phases: phases,
            taskLists: taskLists,
            tasks: tasks,
            subtasks: subtasks,
            options: options
        )
        
        return try encodeTemplate(template, format: options.exportFormat)
    }
    
    func exportToFile(_ project: Project,
                     phases: [Phase] = [],
                     taskLists: [String: [TaskList]] = [:],
                     tasks: [String: [ShigodekiTask]] = [:],
                     subtasks: [String: [Subtask]] = [:],
                     options: ExportOptions = .default,
                     to url: URL) async throws {
        
        let jsonData = try await exportToJSON(
            project,
            phases: phases,
            taskLists: taskLists,
            tasks: tasks,
            subtasks: subtasks,
            options: options
        )
        
        do {
            try jsonData.write(to: url)
            await MainActor.run {
                lastExportResult = url
            }
        } catch {
            let exportError = ExportError.fileWriteFailed(url.path)
            await MainActor.run {
                lastExportError = exportError
            }
            throw exportError
        }
    }
    
    // MARK: - Private Methods
    
    private func convertToTemplate(project: Project,
                                  phases: [Phase],
                                  taskLists: [String: [TaskList]],
                                  tasks: [String: [ShigodekiTask]],
                                  subtasks: [String: [Subtask]],
                                  options: ExportOptions) async throws -> ProjectTemplate {
        
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
    
    private func convertPhaseToTemplate(phase: Phase,
                                       taskLists: [TaskList],
                                       tasks: [String: [ShigodekiTask]],
                                       subtasks: [String: [Subtask]],
                                       options: ExportOptions) throws -> PhaseTemplate {
        
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
    
    private func convertTasksToTemplates(tasks: [ShigodekiTask],
                                        subtasks: [String: [Subtask]],
                                        options: ExportOptions) -> [TaskTemplate] {
        
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
    
    private func createMetadata(from project: Project, options: ExportOptions) -> TemplateMetadata {
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
    
    private func estimateCategory(from project: Project, 
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
    
    private func encodeTemplate(_ template: ProjectTemplate, format: ExportFormat) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        do {
            switch format {
            case .projectTemplate:
                return try encoder.encode(template)
                
            case .legacySteps:
                let legacyTemplate = convertToLegacyFormat(template)
                return try encoder.encode(legacyTemplate)
                
            case .minimal:
                let minimalTemplate = createMinimalTemplate(template)
                return try JSONSerialization.data(withJSONObject: minimalTemplate, options: [.prettyPrinted, .sortedKeys])
            }
        } catch {
            throw ExportError.encodingFailed
        }
    }
    
    private func convertToLegacyFormat(_ template: ProjectTemplate) -> LegacyJSONTemplate {
        let steps = template.phases.map { phase in
            let tasks = phase.taskLists.flatMap { $0.tasks }.map { task in
                LegacyJSONTemplate.LegacyTask(
                    title: task.title,
                    description: task.description,
                    priority: task.priority.rawValue,
                    estimatedDuration: task.estimatedDuration,
                    deadline: task.deadline,
                    tags: task.tags.isEmpty ? nil : task.tags,
                    templateLinks: task.templateLinks,
                    isOptional: task.isOptional ? true : nil
                )
            }
            
            return LegacyJSONTemplate.LegacyStep(
                title: phase.title,
                description: phase.description,
                order: phase.order,
                prerequisites: phase.prerequisites.isEmpty ? nil : phase.prerequisites,
                templateReference: phase.templateReference,
                estimatedDuration: phase.estimatedDuration,
                tasks: tasks
            )
        }
        
        let metadata = LegacyJSONTemplate.LegacyMetadata(
            author: template.metadata.author,
            createdAt: template.metadata.createdAt,
            estimatedDuration: template.metadata.estimatedDuration,
            difficulty: template.metadata.difficulty.rawValue,
            tags: template.metadata.tags.isEmpty ? nil : template.metadata.tags
        )
        
        return LegacyJSONTemplate(
            name: template.name,
            description: template.description,
            goal: template.goal,
            category: template.category.displayName,
            version: template.version,
            steps: steps,
            metadata: metadata
        )
    }
    
    private func createMinimalTemplate(_ template: ProjectTemplate) -> [String: Any] {
        return [
            "name": template.name,
            "description": template.description ?? "",
            "category": template.category.rawValue,
            "phases": template.phases.map { phase in
                [
                    "title": phase.title,
                    "order": phase.order,
                    "tasks": phase.taskLists.flatMap { $0.tasks }.map { task in
                        [
                            "title": task.title,
                            "priority": task.priority.rawValue
                        ]
                    }
                ]
            }
        ]
    }
}

// MARK: - Preview Support

extension TemplateExporter {
    static func previewExporter() -> TemplateExporter {
        let exporter = TemplateExporter()
        return exporter
    }
}