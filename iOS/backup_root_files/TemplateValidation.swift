//
//  TemplateValidation.swift
//  shigodeki
//
//  Created by Claude on 2025-08-29.
//

import Foundation

class TemplateValidator: ObservableObject {
    
    enum ValidationError: LocalizedError, Equatable {
        case emptyName
        case emptyPhases
        case duplicatePhaseOrders([Int])
        case duplicatePhaseTitles([String])
        case emptyTasksInPhase(String)
        case invalidDependency(task: String, dependency: String)
        case circularDependency([String])
        case invalidEstimatedHours(task: String, hours: Double)
        case missingRequiredField(field: String, location: String)
        case invalidDateFormat(field: String, value: String)
        case unsupportedVersion(String)
        case invalidCategory(String)
        case exceedsMaxComplexity(current: Int, max: Int)
        case invalidPriority(task: String, priority: String)
        case emptyTaskTitle(phaseTitle: String, taskIndex: Int)
        
        var errorDescription: String? {
            switch self {
            case .emptyName:
                return "テンプレート名が空です"
            case .emptyPhases:
                return "少なくとも1つのフェーズが必要です"
            case .duplicatePhaseOrders(let orders):
                return "重複するフェーズ順序があります: \(orders.map(String.init).joined(separator: ", "))"
            case .duplicatePhaseTitles(let titles):
                return "重複するフェーズ名があります: \(titles.joined(separator: ", "))"
            case .emptyTasksInPhase(let phase):
                return "フェーズ '\(phase)' にタスクがありません"
            case .invalidDependency(let task, let dependency):
                return "タスク '\(task)' の依存関係 '\(dependency)' が見つかりません"
            case .circularDependency(let tasks):
                return "循環依存が検出されました: \(tasks.joined(separator: " → "))"
            case .invalidEstimatedHours(let task, let hours):
                return "タスク '\(task)' の推定時間が無効です: \(hours)"
            case .missingRequiredField(let field, let location):
                return "必須フィールド '\(field)' が '\(location)' にありません"
            case .invalidDateFormat(let field, let value):
                return "日付フィールド '\(field)' の形式が無効です: \(value)"
            case .unsupportedVersion(let version):
                return "サポートされていないバージョンです: \(version)"
            case .invalidCategory(let category):
                return "無効なカテゴリです: \(category)"
            case .exceedsMaxComplexity(let current, let max):
                return "テンプレートの複雑度が上限を超えています: \(current)/\(max)"
            case .invalidPriority(let task, let priority):
                return "タスク '\(task)' の優先度が無効です: \(priority)"
            case .emptyTaskTitle(let phaseTitle, let taskIndex):
                return "フェーズ '\(phaseTitle)' のタスク #\(taskIndex + 1) のタイトルが空です"
            }
        }
        
        var severity: ValidationSeverity {
            switch self {
            case .emptyName, .emptyPhases, .circularDependency, .unsupportedVersion:
                return .error
            case .duplicatePhaseOrders, .duplicatePhaseTitles, .invalidDependency, .missingRequiredField, .emptyTaskTitle:
                return .error
            case .emptyTasksInPhase, .exceedsMaxComplexity:
                return .warning
            case .invalidEstimatedHours, .invalidDateFormat, .invalidCategory, .invalidPriority:
                return .warning
            }
        }
    }
    
    enum ValidationSeverity {
        case error
        case warning
        case info
        
        var displayName: String {
            switch self {
            case .error: return "エラー"
            case .warning: return "警告"
            case .info: return "情報"
            }
        }
    }
    
    struct ValidationResult {
        let isValid: Bool
        let errors: [ValidationError]
        let warnings: [ValidationError]
        let suggestions: [ValidationSuggestion]
        let complexity: ComplexityMetrics
        
        var hasErrors: Bool { !errors.isEmpty }
        var hasWarnings: Bool { !warnings.isEmpty }
        var totalIssues: Int { errors.count + warnings.count }
    }
    
    struct ValidationSuggestion {
        let type: SuggestionType
        let message: String
        let location: String?
        
        enum SuggestionType {
            case optimization
            case bestPractice
            case accessibility
            case performance
        }
    }
    
    struct ComplexityMetrics {
        let totalTasks: Int
        let totalSubtasks: Int
        let averageTasksPerPhase: Double
        let dependencyCount: Int
        let estimatedTotalHours: Double
        let complexityScore: Double
        let maxRecommendedTasks: Int
        
        var isHighComplexity: Bool {
            complexityScore > 0.8 || totalTasks > maxRecommendedTasks
        }
        
        var complexityLevel: String {
            switch complexityScore {
            case 0..<0.3: return "簡単"
            case 0.3..<0.6: return "普通"
            case 0.6..<0.8: return "複雑"
            default: return "非常に複雑"
            }
        }
    }
    
    // MARK: - Configuration
    
    struct ValidationConfig {
        let maxTasksPerTemplate: Int
        let maxPhasesPerTemplate: Int
        let maxTasksPerPhase: Int
        let maxDependencyDepth: Int
        let maxEstimatedHours: Double
        let allowEmptyPhases: Bool
        let strictMode: Bool
        
        static let `default` = ValidationConfig(
            maxTasksPerTemplate: 500,
            maxPhasesPerTemplate: 50,
            maxTasksPerPhase: 100,
            maxDependencyDepth: 10,
            maxEstimatedHours: 10000,
            allowEmptyPhases: false,
            strictMode: false
        )
        
        static let strict = ValidationConfig(
            maxTasksPerTemplate: 200,
            maxPhasesPerTemplate: 20,
            maxTasksPerPhase: 50,
            maxDependencyDepth: 5,
            maxEstimatedHours: 5000,
            allowEmptyPhases: false,
            strictMode: true
        )
    }
    
    private let config: ValidationConfig
    @Published var lastValidationResult: ValidationResult?
    @Published var isValidating = false
    
    init(config: ValidationConfig = .default) {
        self.config = config
    }
    
    // MARK: - Public Methods
    
    func validate(_ template: ProjectTemplate) async -> ValidationResult {
        await MainActor.run {
            isValidating = true
        }
        
        defer {
            Task { @MainActor in
                isValidating = false
            }
        }
        
        var errors: [ValidationError] = []
        var warnings: [ValidationError] = []
        var suggestions: [ValidationSuggestion] = []
        
        // 基本バリデーション
        validateBasicStructure(template, errors: &errors, warnings: &warnings)
        
        // フェーズバリデーション
        validatePhases(template.phases, errors: &errors, warnings: &warnings, suggestions: &suggestions)
        
        // タスクバリデーション
        validateTasks(template.phases, errors: &errors, warnings: &warnings, suggestions: &suggestions)
        
        // 依存関係バリデーション
        validateDependencies(template.phases, errors: &errors, warnings: &warnings)
        
        // 複雑度計算
        let complexity = calculateComplexity(template)
        
        // 複雑度チェック
        if complexity.isHighComplexity {
            warnings.append(.exceedsMaxComplexity(current: complexity.totalTasks, max: complexity.maxRecommendedTasks))
        }
        
        // 最適化提案
        generateOptimizationSuggestions(template, complexity: complexity, suggestions: &suggestions)
        
        let result = ValidationResult(
            isValid: errors.isEmpty,
            errors: errors,
            warnings: warnings,
            suggestions: suggestions,
            complexity: complexity
        )
        
        await MainActor.run {
            lastValidationResult = result
        }
        
        return result
    }
    
    func validateJSON(_ jsonData: Data) async -> ValidationResult {
        do {
            // 標準形式を試す
            if let template = try? ModelJSONUtility.shared.importTemplate(from: jsonData) {
                return await validate(template)
            }
            
            // レガシー形式を試す
            if let legacyTemplate = try? ModelJSONUtility.shared.importLegacyTemplate(from: jsonData) {
                let template = try convertLegacyForValidation(legacyTemplate)
                return await validate(template)
            }
            
            // JSONが無効
            let result = ValidationResult(
                isValid: false,
                errors: [.unsupportedVersion("unknown")],
                warnings: [],
                suggestions: [],
                complexity: ComplexityMetrics(
                    totalTasks: 0, totalSubtasks: 0, averageTasksPerPhase: 0,
                    dependencyCount: 0, estimatedTotalHours: 0, complexityScore: 0,
                    maxRecommendedTasks: config.maxTasksPerTemplate
                )
            )
            
            await MainActor.run {
                lastValidationResult = result
            }
            
            return result
            
        } catch {
            let result = ValidationResult(
                isValid: false,
                errors: [.invalidDateFormat(field: "JSON", value: "parsing_failed")],
                warnings: [],
                suggestions: [],
                complexity: ComplexityMetrics(
                    totalTasks: 0, totalSubtasks: 0, averageTasksPerPhase: 0,
                    dependencyCount: 0, estimatedTotalHours: 0, complexityScore: 0,
                    maxRecommendedTasks: config.maxTasksPerTemplate
                )
            )
            
            await MainActor.run {
                lastValidationResult = result
            }
            
            return result
        }
    }
    
    // MARK: - Private Validation Methods
    
    private func validateBasicStructure(_ template: ProjectTemplate, 
                                       errors: inout [ValidationError], 
                                       warnings: inout [ValidationError]) {
        // 名前チェック
        if template.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(.emptyName)
        }
        
        // フェーズチェック
        if template.phases.isEmpty {
            errors.append(.emptyPhases)
        }
        
        // バージョンチェック
        let supportedVersions = ["1.0", "1.1", "1.2"]
        if !supportedVersions.contains(template.version) {
            warnings.append(.unsupportedVersion(template.version))
        }
        
        // カテゴリチェック
        if !TemplateCategory.allCases.contains(template.category) {
            warnings.append(.invalidCategory(template.category.rawValue))
        }
    }
    
    private func validatePhases(_ phases: [PhaseTemplate], 
                               errors: inout [ValidationError], 
                               warnings: inout [ValidationError],
                               suggestions: inout [ValidationSuggestion]) {
        // フェーズ数チェック
        if phases.count > config.maxPhasesPerTemplate {
            warnings.append(.exceedsMaxComplexity(current: phases.count, max: config.maxPhasesPerTemplate))
        }
        
        // 重複する順序チェック
        let orders = phases.map { $0.order }
        let duplicateOrders = orders.duplicates()
        if !duplicateOrders.isEmpty {
            errors.append(.duplicatePhaseOrders(duplicateOrders))
        }
        
        // 重複するタイトルチェック
        let titles = phases.map { $0.title }
        let duplicateTitles = titles.duplicates()
        if !duplicateTitles.isEmpty {
            errors.append(.duplicatePhaseTitles(duplicateTitles))
        }
        
        // 空のフェーズチェック
        for phase in phases {
            let totalTasks = phase.taskLists.reduce(0) { $0 + $1.tasks.count }
            if totalTasks == 0 && !config.allowEmptyPhases {
                warnings.append(.emptyTasksInPhase(phase.title))
            }
        }
        
        // ベストプラクティス提案
        if phases.count > 10 {
            suggestions.append(ValidationSuggestion(
                type: .bestPractice,
                message: "フェーズ数が多いです（\(phases.count)個）。関連するフェーズを統合することを検討してください",
                location: "phases"
            ))
        }
    }
    
    private func validateTasks(_ phases: [PhaseTemplate], 
                              errors: inout [ValidationError], 
                              warnings: inout [ValidationError],
                              suggestions: inout [ValidationSuggestion]) {
        
        for phase in phases {
            for (taskListIndex, taskList) in phase.taskLists.enumerated() {
                // タスク数チェック
                if taskList.tasks.count > config.maxTasksPerPhase {
                    warnings.append(.exceedsMaxComplexity(current: taskList.tasks.count, max: config.maxTasksPerPhase))
                }
                
                for (taskIndex, task) in taskList.tasks.enumerated() {
                    // タスクタイトルチェック
                    if task.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        errors.append(.emptyTaskTitle(phaseTitle: phase.title, taskIndex: taskIndex))
                    }
                    
                    // 推定時間チェック
                    if let hours = task.estimatedHours {
                        if hours < 0 || hours > config.maxEstimatedHours {
                            warnings.append(.invalidEstimatedHours(task: task.title, hours: hours))
                        }
                    }
                    
                    // 優先度チェック
                    if !TaskPriority.allCases.contains(task.priority) {
                        warnings.append(.invalidPriority(task: task.title, priority: task.priority.rawValue))
                    }
                }
            }
        }
        
        // アクセシビリティ提案
        let totalTasks = phases.reduce(0) { phaseSum, phase in
            phaseSum + phase.taskLists.reduce(0) { $0 + $1.tasks.count }
        }
        
        if totalTasks > 50 {
            suggestions.append(ValidationSuggestion(
                type: .accessibility,
                message: "多数のタスクがあります。進捗追跡を容易にするため、マイルストーンの設定を検討してください",
                location: "tasks"
            ))
        }
    }
    
    private func validateDependencies(_ phases: [PhaseTemplate], 
                                     errors: inout [ValidationError], 
                                     warnings: inout [ValidationError]) {
        
        let allTaskTitles = Set(phases.flatMap { phase in
            phase.taskLists.flatMap { $0.tasks.map { $0.title } }
        })
        
        var dependencyGraph: [String: [String]] = [:]
        
        for phase in phases {
            for taskList in phase.taskLists {
                for task in taskList.tasks {
                    // 依存関係の存在チェック
                    for dependency in task.dependsOn {
                        if !allTaskTitles.contains(dependency) {
                            errors.append(.invalidDependency(task: task.title, dependency: dependency))
                        }
                    }
                    
                    // 依存関係グラフ構築
                    dependencyGraph[task.title] = task.dependsOn
                }
            }
        }
        
        // 循環依存チェック
        if let cycle = findCircularDependency(in: dependencyGraph) {
            errors.append(.circularDependency(cycle))
        }
    }
    
    private func calculateComplexity(_ template: ProjectTemplate) -> ComplexityMetrics {
        let totalTasks = template.phases.reduce(0) { phaseSum, phase in
            phaseSum + phase.taskLists.reduce(0) { $0 + $1.tasks.count }
        }
        
        let totalSubtasks = template.phases.reduce(0) { phaseSum, phase in
            phaseSum + phase.taskLists.reduce(0) { taskListSum, taskList in
                taskListSum + taskList.tasks.reduce(0) { $0 + $1.subtasks.count }
            }
        }
        
        let averageTasksPerPhase = template.phases.isEmpty ? 0 : Double(totalTasks) / Double(template.phases.count)
        
        let dependencyCount = template.phases.reduce(0) { phaseSum, phase in
            phaseSum + phase.taskLists.reduce(0) { taskListSum, taskList in
                taskListSum + taskList.tasks.reduce(0) { $0 + $1.dependsOn.count }
            }
        }
        
        let estimatedTotalHours = template.phases.reduce(0.0) { phaseSum, phase in
            phaseSum + phase.taskLists.reduce(0.0) { taskListSum, taskList in
                taskListSum + taskList.tasks.reduce(0.0) { $0 + ($1.estimatedHours ?? 1.0) }
            }
        }
        
        // 複雑度スコア計算（0-1）
        let taskComplexity = min(Double(totalTasks) / Double(config.maxTasksPerTemplate), 1.0)
        let dependencyComplexity = min(Double(dependencyCount) / Double(totalTasks * 2), 1.0)
        let phaseComplexity = min(Double(template.phases.count) / Double(config.maxPhasesPerTemplate), 1.0)
        
        let complexityScore = (taskComplexity * 0.5) + (dependencyComplexity * 0.3) + (phaseComplexity * 0.2)
        
        return ComplexityMetrics(
            totalTasks: totalTasks,
            totalSubtasks: totalSubtasks,
            averageTasksPerPhase: averageTasksPerPhase,
            dependencyCount: dependencyCount,
            estimatedTotalHours: estimatedTotalHours,
            complexityScore: complexityScore,
            maxRecommendedTasks: config.maxTasksPerTemplate
        )
    }
    
    private func generateOptimizationSuggestions(_ template: ProjectTemplate, 
                                               complexity: ComplexityMetrics, 
                                               suggestions: inout [ValidationSuggestion]) {
        
        // パフォーマンス提案
        if complexity.totalTasks > 200 {
            suggestions.append(ValidationSuggestion(
                type: .performance,
                message: "大量のタスクがパフォーマンスに影響する可能性があります。テンプレートを分割することを検討してください",
                location: "performance"
            ))
        }
        
        // 最適化提案
        if complexity.averageTasksPerPhase > 20 {
            suggestions.append(ValidationSuggestion(
                type: .optimization,
                message: "フェーズあたりのタスク数が多いです。フェーズを細分化することで管理しやすくなります",
                location: "optimization"
            ))
        }
        
        // 依存関係提案
        if complexity.dependencyCount > complexity.totalTasks / 2 {
            suggestions.append(ValidationSuggestion(
                type: .optimization,
                message: "依存関係が多すぎます。タスクの順序を見直して依存関係を簡素化してください",
                location: "dependencies"
            ))
        }
    }
    
    // MARK: - Helper Methods
    
    private func convertLegacyForValidation(_ legacy: LegacyJSONTemplate) throws -> ProjectTemplate {
        // 簡略化された変換（バリデーション用）
        let phases = legacy.steps.map { step in
            let tasks = step.tasks.map { task in
                TaskTemplate(
                    title: task.title,
                    description: task.description,
                    priority: TaskPriority(rawValue: task.priority ?? "medium") ?? .medium
                )
            }
            
            return PhaseTemplate(
                title: step.title,
                description: step.description,
                order: step.order,
                taskLists: [TaskListTemplate(name: "Tasks", tasks: tasks)]
            )
        }
        
        let metadata = TemplateMetadata(
            author: legacy.metadata?.author ?? "Unknown",
            createdAt: legacy.metadata?.createdAt ?? ISO8601DateFormatter().string(from: Date())
        )
        
        return ProjectTemplate(
            name: legacy.name,
            category: .other,
            version: legacy.version ?? "1.0",
            phases: phases,
            metadata: metadata
        )
    }
    
    private func findCircularDependency(in graph: [String: [String]]) -> [String]? {
        var visited: Set<String> = []
        var recursionStack: Set<String> = []
        var path: [String] = []
        
        for node in graph.keys {
            if !visited.contains(node) {
                if let cycle = dfsForCycle(node: node, graph: graph, visited: &visited, 
                                         recursionStack: &recursionStack, path: &path) {
                    return cycle
                }
            }
        }
        
        return nil
    }
    
    private func dfsForCycle(node: String, graph: [String: [String]], 
                           visited: inout Set<String>, recursionStack: inout Set<String>, 
                           path: inout [String]) -> [String]? {
        
        visited.insert(node)
        recursionStack.insert(node)
        path.append(node)
        
        for neighbor in graph[node] ?? [] {
            if !visited.contains(neighbor) {
                if let cycle = dfsForCycle(node: neighbor, graph: graph, visited: &visited, 
                                         recursionStack: &recursionStack, path: &path) {
                    return cycle
                }
            } else if recursionStack.contains(neighbor) {
                // 循環発見
                if let startIndex = path.firstIndex(of: neighbor) {
                    return Array(path[startIndex...]) + [neighbor]
                }
            }
        }
        
        recursionStack.remove(node)
        path.removeLast()
        return nil
    }
}

// MARK: - Extensions

extension Array where Element: Hashable {
    func duplicates() -> [Element] {
        var seen: Set<Element> = []
        var duplicates: Set<Element> = []
        
        for element in self {
            if seen.contains(element) {
                duplicates.insert(element)
            } else {
                seen.insert(element)
            }
        }
        
        return Array(duplicates)
    }
}

// MARK: - Preview Support

extension TemplateValidator {
    static func previewValidator() -> TemplateValidator {
        return TemplateValidator(config: .default)
    }
}