//
//  TemplateImporter.swift
//  shigodeki
//
//  Created by Claude on 2025-08-29.
//

import Foundation

class TemplateImporter: ObservableObject {
    
    enum ImportError: LocalizedError {
        case invalidJSON
        case unsupportedFormat
        case missingRequiredFields(String)
        case validationFailed(String)
        case conversionFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .invalidJSON:
                return "JSONファイルが無効です"
            case .unsupportedFormat:
                return "サポートされていない形式です"
            case .missingRequiredFields(let field):
                return "必須フィールド '\(field)' が見つかりません"
            case .validationFailed(let message):
                return "バリデーションエラー: \(message)"
            case .conversionFailed(let message):
                return "変換エラー: \(message)"
            }
        }
    }
    
    struct ImportResult {
        let projectTemplate: ProjectTemplate
        let warnings: [String]
        let statistics: TemplateStats
    }
    
    @Published var isImporting = false
    @Published var lastImportResult: ImportResult?
    @Published var lastImportError: ImportError?
    
    // MARK: - Public Methods
    
    @MainActor
    func importTemplate(from jsonData: Data) async throws -> ImportResult {
        isImporting = true
        lastImportError = nil
        
        defer {
            isImporting = false
        }
        
        do {
            // まず標準形式を試す
            if let template = try? ModelJSONUtility.shared.importTemplate(from: jsonData) {
                let result = try validateAndCreateResult(template: template)
                lastImportResult = result
                return result
            }
            
            // レガシー形式（steps形式）を試す
            if let legacyTemplate = try? ModelJSONUtility.shared.importLegacyTemplate(from: jsonData) {
                let template = try convertFromLegacyFormat(legacyTemplate)
                let result = try validateAndCreateResult(template: template)
                lastImportResult = result
                return result
            }
            
            throw ImportError.unsupportedFormat
            
        } catch let error as ImportError {
            lastImportError = error
            throw error
        } catch {
            let importError = ImportError.invalidJSON
            lastImportError = importError
            throw importError
        }
    }
    
    @MainActor
    func importTemplateFromFile(url: URL) async throws -> ImportResult {
        guard url.startAccessingSecurityScopedResource() else {
            throw ImportError.conversionFailed("ファイルへのアクセス権限がありません")
        }
        
        defer {
            url.stopAccessingSecurityScopedResource()
        }
        
        let data = try Data(contentsOf: url)
        return try await importTemplate(from: data)
    }
    
    func createProject(from template: ProjectTemplate, ownerId: String, 
                      projectName: String? = nil, customizations: ProjectCustomizations? = nil) async throws -> Project {
        
        let finalProjectName = projectName ?? template.name
        var project = Project(name: finalProjectName, description: template.description, ownerId: ownerId)
        
        // カスタマイゼーションを適用
        if let customizations = customizations {
            if let settings = customizations.projectSettings {
                project.settings = settings
            }
        }
        
        return project
    }
    
    // MARK: - Private Methods
    
    private func validateAndCreateResult(template: ProjectTemplate) throws -> ImportResult {
        var warnings: [String] = []
        
        // 基本バリデーション
        if template.name.isEmpty {
            throw ImportError.missingRequiredFields("name")
        }
        
        if template.phases.isEmpty {
            throw ImportError.validationFailed("少なくとも1つのフェーズが必要です")
        }
        
        // フェーズの順序チェック
        let sortedPhases = template.phases.sorted { $0.order < $1.order }
        if sortedPhases != template.phases {
            warnings.append("フェーズの順序が正しくありません。自動で修正されます。")
        }
        
        // タスクの依存関係チェック
        for phase in template.phases {
            for taskList in phase.taskLists {
                for task in taskList.tasks {
                    if !task.dependsOn.isEmpty {
                        let allTaskTitles = template.phases.flatMap { phase in
                            phase.taskLists.flatMap { $0.tasks.map { $0.title } }
                        }
                        for dependency in task.dependsOn {
                            if !allTaskTitles.contains(dependency) {
                                warnings.append("タスク '\(task.title)' の依存関係 '\(dependency)' が見つかりません")
                            }
                        }
                    }
                }
            }
        }
        
        // 統計情報を計算
        let statistics = TemplateStats(template: template)
        
        // 複雑度の警告
        if statistics.totalTasks > 100 {
            warnings.append("タスク数が多いため（\(statistics.totalTasks)個）、プロジェクト管理が複雑になる可能性があります")
        }
        
        if statistics.estimatedCompletionHours > 1000 {
            warnings.append("推定作業時間が非常に長いです（\(Int(statistics.estimatedCompletionHours))時間）")
        }
        
        return ImportResult(
            projectTemplate: template,
            warnings: warnings,
            statistics: statistics
        )
    }
    
    private func convertFromLegacyFormat(_ legacy: LegacyJSONTemplate) throws -> ProjectTemplate {
        // カテゴリ変換
        let category = parseCategory(from: legacy.category)
        
        // フェーズ変換
        let phases = try legacy.steps.map { step in
            try convertLegacyPhase(step)
        }
        
        // メタデータ変換
        let metadata = TemplateMetadata(
            author: legacy.metadata?.author ?? "Unknown",
            createdAt: legacy.metadata?.createdAt ?? ISO8601DateFormatter().string(from: Date()),
            estimatedDuration: legacy.metadata?.estimatedDuration,
            difficulty: parseDifficulty(from: legacy.metadata?.difficulty),
            tags: legacy.metadata?.tags ?? [],
            language: "ja"
        )
        
        return ProjectTemplate(
            name: legacy.name,
            description: legacy.description,
            goal: legacy.goal,
            category: category,
            version: legacy.version ?? "1.0",
            phases: phases,
            metadata: metadata
        )
    }
    
    private func convertLegacyPhase(_ step: LegacyJSONTemplate.LegacyStep) throws -> PhaseTemplate {
        let tasks = step.tasks.map { convertLegacyTask($0) }
        
        let defaultTaskList = TaskListTemplate(
            name: "メインタスク",
            description: step.description,
            color: .blue,
            order: 0,
            tasks: tasks
        )
        
        return PhaseTemplate(
            title: step.title,
            description: step.description,
            order: step.order,
            prerequisites: step.prerequisites ?? [],
            templateReference: step.templateReference,
            estimatedDuration: step.estimatedDuration,
            taskLists: [defaultTaskList]
        )
    }
    
    private func convertLegacyTask(_ task: LegacyJSONTemplate.LegacyTask) -> TaskTemplate {
        let priority = parsePriority(from: task.priority)
        
        return TaskTemplate(
            title: task.title,
            description: task.description,
            priority: priority,
            estimatedDuration: task.estimatedDuration,
            deadline: task.deadline,
            tags: task.tags ?? [],
            templateLinks: task.templateLinks,
            isOptional: task.isOptional ?? false,
            estimatedHours: parseEstimatedHours(from: task.estimatedDuration),
            dependsOn: [],
            subtasks: []
        )
    }
    
    // MARK: - Parsing Utilities
    
    private func parseCategory(from categoryString: String?) -> TemplateCategory {
        guard let categoryString = categoryString else { return .other }
        
        // 日本語カテゴリマッピング
        let mapping: [String: TemplateCategory] = [
            "ソフトウェア開発": .softwareDevelopment,
            "プロジェクト管理": .projectManagement,
            "イベント企画": .eventPlanning,
            "ライフイベント": .lifeEvents,
            "ビジネス": .business,
            "教育": .education,
            "クリエイティブ": .creative,
            "個人": .personal,
            "健康": .health,
            "旅行": .travel
        ]
        
        return mapping[categoryString] ?? TemplateCategory(rawValue: categoryString.lowercased().replacingOccurrences(of: " ", with: "_")) ?? .other
    }
    
    private func parseDifficulty(from difficultyString: String?) -> TemplateDifficulty {
        guard let difficultyString = difficultyString else { return .intermediate }
        
        let mapping: [String: TemplateDifficulty] = [
            "low": .beginner,
            "medium": .intermediate,
            "high": .advanced,
            "expert": .expert,
            "初級": .beginner,
            "中級": .intermediate,
            "上級": .advanced,
            "エキスパート": .expert
        ]
        
        return mapping[difficultyString] ?? .intermediate
    }
    
    private func parsePriority(from priorityString: String?) -> TaskPriority {
        guard let priorityString = priorityString else { return .medium }
        
        switch priorityString.lowercased() {
        case "low", "低":
            return .low
        case "high", "高":
            return .high
        default:
            return .medium
        }
    }
    
    private func parseEstimatedHours(from durationString: String?) -> Double? {
        guard let durationString = durationString else { return nil }
        
        // 簡単な時間パース（例: "2時間", "1週間", "3日"）
        if durationString.contains("時間") {
            let numberString = durationString.replacingOccurrences(of: "時間", with: "").trimmingCharacters(in: .whitespaces)
            return Double(numberString)
        } else if durationString.contains("日") {
            let numberString = durationString.replacingOccurrences(of: "日", with: "").trimmingCharacters(in: .whitespaces)
            if let days = Double(numberString) {
                return days * 8 // 1日8時間想定
            }
        } else if durationString.contains("週間") {
            let numberString = durationString.replacingOccurrences(of: "週間", with: "").trimmingCharacters(in: .whitespaces)
            if let weeks = Double(numberString) {
                return weeks * 40 // 1週間40時間想定
            }
        } else if durationString.contains("ヶ月") {
            let numberString = durationString.replacingOccurrences(of: "ヶ月", with: "").trimmingCharacters(in: .whitespaces)
            if let months = Double(numberString) {
                return months * 160 // 1ヶ月160時間想定
            }
        }
        
        return nil
    }
}

// MARK: - Project Customizations

struct ProjectCustomizations {
    let projectSettings: ProjectSettings?
    let skipOptionalTasks: Bool
    let phaseStartDelays: [String: TimeInterval] // Phase title -> delay in seconds
    let taskPriorityOverrides: [String: TaskPriority] // Task title -> new priority
    let customPhaseColors: [String: TaskListColor] // Phase title -> color
    
    init(projectSettings: ProjectSettings? = nil,
         skipOptionalTasks: Bool = false,
         phaseStartDelays: [String: TimeInterval] = [:],
         taskPriorityOverrides: [String: TaskPriority] = [:],
         customPhaseColors: [String: TaskListColor] = [:]) {
        self.projectSettings = projectSettings
        self.skipOptionalTasks = skipOptionalTasks
        self.phaseStartDelays = phaseStartDelays
        self.taskPriorityOverrides = taskPriorityOverrides
        self.customPhaseColors = customPhaseColors
    }
}

// MARK: - Preview Support

extension TemplateImporter {
    static func previewImporter() -> TemplateImporter {
        let importer = TemplateImporter()
        
        let sampleTemplate = ProjectTemplate(
            name: "サンプルプロジェクト",
            description: "テンプレートのサンプル",
            goal: "基本的なワークフローの理解",
            category: .softwareDevelopment,
            version: "1.0",
            phases: [
                PhaseTemplate(
                    title: "準備フェーズ",
                    description: "プロジェクト開始前の準備",
                    order: 0,
                    taskLists: [
                        TaskListTemplate(
                            name: "初期設定",
                            tasks: [
                                TaskTemplate(
                                    title: "環境構築",
                                    description: "開発環境のセットアップ",
                                    priority: .high
                                )
                            ]
                        )
                    ]
                )
            ],
            metadata: TemplateMetadata(
                author: "System",
                difficulty: .beginner,
                tags: ["sample", "demo"]
            )
        )
        
        let stats = TemplateStats(template: sampleTemplate)
        importer.lastImportResult = ImportResult(
            projectTemplate: sampleTemplate,
            warnings: ["これはサンプルデータです"],
            statistics: stats
        )
        
        return importer
    }
}