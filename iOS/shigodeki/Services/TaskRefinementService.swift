import Foundation

struct TaskRefinementService {
    // MARK: - Public Methods
    
    static func generateImprovements(
        from analysis: TaskPatternAnalysis, 
        tasks: [ShigodekiTask]
    ) async throws -> [ImprovementSuggestion] {
        var suggestions: [ImprovementSuggestion] = []
        
        // Large task breakdown suggestions
        for task in analysis.largeTasksNeedingBreakdown.prefix(3) {
            suggestions.append(ImprovementSuggestion(
                type: .taskBreakdown,
                title: "「\(task.title)」を小さなタスクに分割",
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
                description: "\(analysis.overdueTasks.count)個の期限切れタスクがあります。現実的な期限に調整するか、不要なタスクを削除しましょう。",
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
                print("⚠️ AI suggestions failed: \(error.localizedDescription)")
            }
        }
        
        return suggestions
    }
    
    // MARK: - Private Methods
    
    private static func generateAISuggestions(for tasks: [ShigodekiTask]) async throws -> [ImprovementSuggestion] {
        // Prepare task summary for AI
        let taskSummary = tasks.prefix(10).map { task in
            let completionStatus = task.isCompleted ? "完了" : "未完了"
            return "- \(task.title) (優先度: \(task.priority.displayName), 状態: \(completionStatus))"
        }.joined(separator: "\n")
        
        let prompt = """
        以下のタスクリストを分析して、生産性向上のための具体的な改善提案を3つ以内で提供してください：
        
        \(taskSummary)
        
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
}