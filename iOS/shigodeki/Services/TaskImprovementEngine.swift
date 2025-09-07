import Foundation
import SwiftUI

@MainActor
final class TaskImprovementEngine: ObservableObject {
    // MARK: - Published Properties
    @Published var analysisState: AnalysisState = .idle
    @Published var improvements: [ImprovementSuggestion] = []
    @Published var analysisProgress: Double = 0.0
    @Published var analysisMessage: String = ""
    @Published var error: TaskImprovementError?
    
    // MARK: - Dependencies
    private let aiGenerator: AITaskGenerator
    private let taskManager: TaskManager
    private let familyManager: FamilyManager
    
    // MARK: - Internal State
    private var tasksBeingAnalyzed: [ShigodekiTask] = []
    private var currentUserId: String = ""
    
    // MARK: - Initialization
    init(aiGenerator: AITaskGenerator, taskManager: TaskManager, familyManager: FamilyManager) {
        self.aiGenerator = aiGenerator
        self.taskManager = taskManager
        self.familyManager = familyManager
    }
    
    // MARK: - Public Methods
    func analyzeUserTasks(userId: String) async {
        guard analysisState == .idle else { return }
        
        currentUserId = userId
        analysisState = .analyzing
        analysisProgress = 0.0
        error = nil
        improvements = []
        
        do {
            // Phase 1: Load user's tasks across all families (0-40%)
            analysisMessage = "ユーザーのタスクを読み込み中..."
            let userTasks = try await TaskAnalysisService.loadUserTasks(userId: userId, familyManager: familyManager)
            analysisProgress = 0.4
            
            guard !userTasks.isEmpty else {
                analysisState = .completed
                analysisMessage = "分析できるタスクが見つかりませんでした"
                return
            }
            
            tasksBeingAnalyzed = userTasks
            
            // Phase 2: Analyze task patterns and issues (40-60%)
            analysisMessage = "タスクパターンを分析中..."
            let taskAnalysis = await TaskAnalysisService.analyzeTaskPatterns(userTasks)
            analysisProgress = 0.6
            
            // Phase 3: Generate AI-powered suggestions (60-90%)
            analysisMessage = "AI による改善提案を生成中..."
            let suggestions = try await TaskRefinementService.generateImprovements(from: taskAnalysis, tasks: userTasks)
            analysisProgress = 0.9
            
            // Phase 4: Finalize and update UI (90-100%)
            analysisMessage = "結果を処理中..."
            improvements = suggestions.sorted { (lhs: ImprovementSuggestion, rhs: ImprovementSuggestion) in 
                lhs.impact.type.priority > rhs.impact.type.priority 
            }
            analysisProgress = 1.0
            
            analysisState = .completed
            analysisMessage = "\\(improvements.count)個の改善提案が生成されました"
            
        } catch {
            analysisState = .failed
            self.error = TaskImprovementError.from(error)
            analysisMessage = "分析中にエラーが発生しました"
        }
    }
    
    func applyImprovements(_ selectedSuggestions: Set<UUID>) async throws {
        guard !selectedSuggestions.isEmpty else { return }
        
        analysisState = .applying
        let applicableImprovements = improvements.filter { selectedSuggestions.contains($0.id) }
        
        for (index, improvement) in applicableImprovements.enumerated() {
            analysisProgress = Double(index) / Double(applicableImprovements.count)
            analysisMessage = "\\(improvement.title)を適用中..."
            
            try await applyImprovement(improvement)
        }
        
        analysisState = .applied
        analysisProgress = 1.0
        analysisMessage = "\\(applicableImprovements.count)個の改善が適用されました"
    }
    
    func reset() {
        analysisState = .idle
        improvements = []
        analysisProgress = 0.0
        analysisMessage = ""
        error = nil
        tasksBeingAnalyzed = []
    }
    
    // MARK: - Private Methods
    
    private func applyImprovement(_ improvement: ImprovementSuggestion) async throws {
        switch improvement.actionRequired.actionType {
        case .createSubtasks:
            try await applySubtaskCreation(improvement)
        case .adjustPriorities:
            try await applyPriorityAdjustment(improvement)
        case .adjustDeadlines:
            try await applyDeadlineAdjustment(improvement)
        case .reorganizeCategories:
            try await applyCategoryReorganization(improvement)
        case .addDependencies:
            try await applyDependencyMapping(improvement)
        }
    }
    
    private func applySubtaskCreation(_ improvement: ImprovementSuggestion) async throws {
        // Implementation would create subtasks for the target tasks
        // This is a placeholder for the actual implementation
        print("Creating subtasks for improvement: \\(improvement.title)")
    }
    
    private func applyPriorityAdjustment(_ improvement: ImprovementSuggestion) async throws {
        // Implementation would adjust priorities for target tasks
        print("Adjusting priorities for improvement: \\(improvement.title)")
    }
    
    private func applyDeadlineAdjustment(_ improvement: ImprovementSuggestion) async throws {
        // Implementation would adjust deadlines for target tasks
        print("Adjusting deadlines for improvement: \\(improvement.title)")
    }
    
    private func applyCategoryReorganization(_ improvement: ImprovementSuggestion) async throws {
        // Implementation would reorganize task categories
        print("Reorganizing categories for improvement: \\(improvement.title)")
    }
    
    private func applyDependencyMapping(_ improvement: ImprovementSuggestion) async throws {
        // Implementation would add task dependencies
        print("Adding dependencies for improvement: \\(improvement.title)")
    }
}

// MARK: - Supporting Data Structures

enum AnalysisState {
    case idle
    case analyzing
    case completed
    case applying
    case applied
    case failed
}


struct ImprovementSuggestion: Identifiable, Hashable {
    let id = UUID()
    let type: ImprovementType
    let title: String
    let description: String
    let targetTasks: [String] // Task IDs
    let impact: ImprovementImpact
    let actionRequired: ImprovementAction
    let confidence: Double // 0.0 - 1.0
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: ImprovementSuggestion, rhs: ImprovementSuggestion) -> Bool {
        lhs.id == rhs.id
    }
}

enum ImprovementType {
    case taskBreakdown
    case priorityAdjustment
    case deadlineOptimization
    case dependencyMapping
    case categoryReorganization
    
    var iconName: String {
        switch self {
        case .taskBreakdown: return "square.stack.3d.down.right"
        case .priorityAdjustment: return "arrow.up.arrow.down"
        case .deadlineOptimization: return "calendar.badge.clock"
        case .dependencyMapping: return "arrow.triangle.branch"
        case .categoryReorganization: return "folder.badge.gearshape"
        }
    }
}

struct ImprovementImpact {
    let type: ImpactType
    let description: String
    let estimatedTimeReduction: Double // hours per week
    
    enum ImpactType {
        case low, medium, high, critical
        
        var priority: Int {
            switch self {
            case .low: return 1
            case .medium: return 2
            case .high: return 3
            case .critical: return 4
            }
        }
        
        var color: Color {
            switch self {
            case .low: return .gray
            case .medium: return .blue
            case .high: return .orange
            case .critical: return .red
            }
        }
        
        var displayName: String {
            switch self {
            case .low: return "低"
            case .medium: return "中"
            case .high: return "高"
            case .critical: return "重要"
            }
        }
    }
}

struct ImprovementAction {
    let actionType: ActionType
    let parameters: [String: Any]
    
    enum ActionType {
        case createSubtasks
        case adjustPriorities
        case adjustDeadlines
        case reorganizeCategories
        case addDependencies
    }
}

enum TaskImprovementError: LocalizedError {
    case noTasksFound
    case aiServiceUnavailable
    case analysisTimeout
    case applicationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .noTasksFound:
            return "分析できるタスクが見つかりません"
        case .aiServiceUnavailable:
            return "AI サービスが利用できません"
        case .analysisTimeout:
            return "分析がタイムアウトしました"
        case .applicationFailed(let details):
            return "改善の適用に失敗しました: \\(details)"
        }
    }
    
    static func from(_ error: Error) -> TaskImprovementError {
        if let improvementError = error as? TaskImprovementError {
            return improvementError
        }
        return .applicationFailed(error.localizedDescription)
    }
}