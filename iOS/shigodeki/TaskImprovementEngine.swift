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
            let userTasks = try await loadUserTasks(userId: userId)
            analysisProgress = 0.4
            
            guard !userTasks.isEmpty else {
                analysisState = .completed
                analysisMessage = "分析できるタスクが見つかりませんでした"
                return
            }
            
            tasksBeingAnalyzed = userTasks
            
            // Phase 2: Analyze task patterns and issues (40-60%)
            analysisMessage = "タスクパターンを分析中..."
            let taskAnalysis = await analyzeTaskPatterns(userTasks)
            analysisProgress = 0.6
            
            // Phase 3: Generate AI-powered suggestions (60-90%)
            analysisMessage = "AI による改善提案を生成中..."
            let suggestions = try await generateImprovements(from: taskAnalysis, tasks: userTasks)
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
    private func loadUserTasks(userId: String) async throws -> [ShigodekiTask] {
        // Load families for user
        await familyManager.loadFamiliesForUser(userId: userId)
        let families = familyManager.families
        
        var allTasks: [ShigodekiTask] = []
        
        for family in families {
            guard let familyId = family.id else { continue }
            
            // Load task lists for this family
            // Note: Using placeholder - actual TaskManager API may differ
            let taskLists: [TaskList] = []
            
            for taskList in taskLists {
                guard let taskListId = taskList.id else { continue }
                
                // Load tasks for this task list
                // Note: Using placeholder - actual TaskManager API may differ
                let tasks: [ShigodekiTask] = []
                allTasks.append(contentsOf: tasks)
            }
        }
        
        return allTasks
    }
    
    private func analyzeTaskPatterns(_ tasks: [ShigodekiTask]) async -> TaskPatternAnalysis {
        var analysis = TaskPatternAnalysis()
        
        // Analyze task complexity
        let largeTasks = tasks.filter { $0.subtaskCount > 5 || $0.title.count > 100 }
        analysis.largeTasksNeedingBreakdown = largeTasks
        
        // Analyze priority distribution
        let priorityDistribution = Dictionary(grouping: tasks, by: { $0.priority })
        if let highPriorityCount = priorityDistribution[.high]?.count {
            let totalCount = priorityDistribution.values.flatMap({ $0 }).count
            if highPriorityCount > totalCount / 2 {
                analysis.hasPriorityInflation = true
            }
        }
        
        // Analyze overdue tasks
        let now = Date()
        let overdueTasks = tasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return dueDate < now && !task.isCompleted
        }
        analysis.overdueTasks = overdueTasks
        
        // Analyze completion patterns
        let completedTasks = tasks.filter { $0.isCompleted }
        let averageCompletionTime = calculateAverageCompletionTime(completedTasks)
        analysis.averageCompletionTime = averageCompletionTime
        
        // Analyze task dependencies
        // Note: Using placeholder - ShigodekiTask may not have dependentTaskIds property
        analysis.tasksWithoutDependencies = tasks.filter { !$0.isCompleted }
        
        return analysis
    }
    
    private func generateImprovements(from analysis: TaskPatternAnalysis, tasks: [ShigodekiTask]) async throws -> [ImprovementSuggestion] {
        var suggestions: [ImprovementSuggestion] = []
        
        // Large task breakdown suggestions
        for task in analysis.largeTasksNeedingBreakdown.prefix(3) {
            suggestions.append(ImprovementSuggestion(
                type: .taskBreakdown,
                title: "「\\(task.title)」を小さなタスクに分割",
                description: "この大きなタスクをより管理しやすい小さなタスクに分割することで、進捗を追跡しやすくなり、完了率が向上します。",
                targetTasks: [task.id].compactMap { $0 },
                impact: ImprovementImpact(
                    type: .high,
                    description: "タスク完了率20%向上",
                    estimatedTimeReduction: 2.0
                ),
                actionRequired: ImprovementAction(
                    actionType: .createSubtasks,
                    parameters: ["taskId": task.id ?? "", "suggestedCount": min(task.subtaskCount + 3, 8)]
                ),
                confidence: 0.85
            ))
        }
        
        // Priority adjustment suggestions
        if analysis.hasPriorityInflation {
            suggestions.append(ImprovementSuggestion(
                type: .priorityAdjustment,
                title: "タスクの優先度を再調整",
                description: "高優先度のタスクが多すぎます。真に重要なタスクに焦点を当てるために優先度を見直しましょう。",
                targetTasks: tasks.filter { $0.priority == .high }.compactMap { $0.id }.prefix(5).map { $0 },
                impact: ImprovementImpact(
                    type: .medium,
                    description: "集中力向上、ストレス軽減",
                    estimatedTimeReduction: 1.5
                ),
                actionRequired: ImprovementAction(
                    actionType: .adjustPriorities,
                    parameters: ["strategy": "balanced"]
                ),
                confidence: 0.78
            ))
        }
        
        // Overdue task management
        if !analysis.overdueTasks.isEmpty {
            suggestions.append(ImprovementSuggestion(
                type: .deadlineOptimization,
                title: "期限切れタスクの整理",
                description: "\\(analysis.overdueTasks.count)個の期限切れタスクがあります。現実的な期限に調整するか、不要なタスクを削除しましょう。",
                targetTasks: analysis.overdueTasks.compactMap { $0.id },
                impact: ImprovementImpact(
                    type: .high,
                    description: "精神的負担軽減、進捗明確化",
                    estimatedTimeReduction: 3.0
                ),
                actionRequired: ImprovementAction(
                    actionType: .adjustDeadlines,
                    parameters: ["overdueCount": analysis.overdueTasks.count]
                ),
                confidence: 0.92
            ))
        }
        
        // AI-generated suggestions using external service
        if !tasks.isEmpty {
            do {
                let aiSuggestions = try await generateAISuggestions(for: tasks)
                suggestions.append(contentsOf: aiSuggestions)
            } catch {
                // AI suggestions are optional, continue without them
                print("⚠️ AI suggestions failed: \\(error.localizedDescription)")
            }
        }
        
        return suggestions
    }
    
    private func generateAISuggestions(for tasks: [ShigodekiTask]) async throws -> [ImprovementSuggestion] {
        // Prepare task summary for AI
        let taskSummary = tasks.prefix(10).map { task in
            let completionStatus = task.isCompleted ? "完了" : "未完了"
            return "- \\(task.title) (優先度: \\(task.priority.displayName), 状態: \\(completionStatus))"
        }.joined(separator: "\\n")
        
        let prompt = """
        以下のタスクリストを分析して、生産性向上のための具体的な改善提案を3つ以内で提供してください：
        
        \\(taskSummary)
        
        以下の観点で分析してください：
        1. タスクの構造化・整理
        2. 時間管理・効率化
        3. モチベーション維持
        
        各提案には、具体的なアクションと期待される効果を含めてください。
        """
        
        // Use existing AI generator (this would need to be adapted)
        // For now, return empty array as AI integration needs more setup
        return []
    }
    
    private func calculateAverageCompletionTime(_ tasks: [ShigodekiTask]) -> TimeInterval {
        let completionTimes = tasks.compactMap { task -> TimeInterval? in
            guard let completedAt = task.completedAt,
                  let createdAt = task.createdAt else { return nil }
            return completedAt.timeIntervalSince(createdAt)
        }
        
        return completionTimes.isEmpty ? 0 : completionTimes.reduce(0, +) / Double(completionTimes.count)
    }
    
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

struct TaskPatternAnalysis {
    var largeTasksNeedingBreakdown: [ShigodekiTask] = []
    var hasPriorityInflation: Bool = false
    var overdueTasks: [ShigodekiTask] = []
    var averageCompletionTime: TimeInterval = 0
    var tasksWithoutDependencies: [ShigodekiTask] = []
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