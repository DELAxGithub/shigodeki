import Foundation

// MARK: - Validation Types

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