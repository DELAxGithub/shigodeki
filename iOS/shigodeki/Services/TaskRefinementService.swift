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
        guard !tasks.isEmpty else { return [] }
        
        // Prepare task summary for AI
        let taskSummary = tasks.prefix(10).map { task in
            let completionStatus = task.isCompleted ? "完了" : "未完了"
            let subtaskInfo = task.subtaskCount > 0 ? ", サブタスク: \(task.subtaskCount)個" : ""
            return "- \(task.title) (優先度: \(task.priority.displayName), 状態: \(completionStatus)\(subtaskInfo))"
        }.joined(separator: "\n")
        
        let prompt = """
        以下のタスクリストを分析して、生産性向上のための具体的な改善提案を3つ以内で提供してください。

        タスクリスト:
        \(taskSummary)
        
        分析観点:
        1. タスクの構造化・整理（大きすぎるタスクの分割、関連タスクのグループ化）
        2. 時間管理・効率化（優先度の調整、実行順序の最適化）
        3. モチベーション維持（達成感の向上、進捗の可視化）
        
        各提案は以下の形式で出力してください（JSONでは**ありません**。プレーンテキスト）:
        
        提案1:
        タイトル: [具体的なアクション]
        説明: [詳細な説明とその理由]
        影響: [期待される効果]
        信頼度: [0.0-1.0の数値]
        
        提案2:
        ...
        """
        
        // Get available providers and use the first one
        let availableProviders = KeychainManager.shared.getConfiguredProviders()
        guard let provider = availableProviders.first else {
            throw AIClientError.apiKeyNotConfigured
        }
        
        // Get universal client based on provider
        let universalClient = getUniversalClient(for: provider)
        
        do {
            let response = try await universalClient.generateText(
                prompt: prompt,
                system: "あなたは生産性とタスク管理の専門家です。具体的で実行可能な改善提案を提供してください。",
                temperature: 0.7
            )
            
            return parseAIResponse(response)
            
        } catch {
            // AI suggestions are optional, log the error but don't fail
            print("⚠️ AI suggestions failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    private static func getUniversalClient(for provider: KeychainManager.APIProvider) -> UniversalAIClient {
        switch provider {
        case .openAI:
            return OpenAIClient()
        case .claude:
            return ClaudeClient()
        case .gemini:
            return GeminiClient()
        }
    }
    
    private static func parseAIResponse(_ response: String) -> [ImprovementSuggestion] {
        var suggestions: [ImprovementSuggestion] = []
        
        // Parse the AI response to extract suggestions
        // This is a simple parser - in production, you might want structured output
        let sections = response.components(separatedBy: "提案")
        
        for (index, section) in sections.enumerated() {
            guard index > 0 else { continue } // Skip first empty section
            
            let lines = section.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            
            var title = ""
            var description = ""
            var impact = ""
            var confidence = 0.7
            
            for line in lines {
                if line.hasPrefix("タイトル:") {
                    title = String(line.dropFirst(4)).trimmingCharacters(in: .whitespacesAndNewlines)
                } else if line.hasPrefix("説明:") {
                    description = String(line.dropFirst(3)).trimmingCharacters(in: .whitespacesAndNewlines)
                } else if line.hasPrefix("影響:") {
                    impact = String(line.dropFirst(3)).trimmingCharacters(in: .whitespacesAndNewlines)
                } else if line.hasPrefix("信頼度:") {
                    let confidenceStr = String(line.dropFirst(4)).trimmingCharacters(in: .whitespacesAndNewlines)
                    confidence = Double(confidenceStr) ?? 0.7
                }
            }
            
            if !title.isEmpty && !description.isEmpty {
                let suggestion = ImprovementSuggestion(
                    type: .taskBreakdown, // Default type, could be smarter
                    title: title,
                    description: description,
                    targetTasks: [], // AI doesn't specify specific tasks
                    impact: ImprovementImpact(
                        type: .medium,
                        description: impact.isEmpty ? "AI提案による改善" : impact,
                        estimatedTimeReduction: 1.0
                    ),
                    actionRequired: ImprovementAction(
                        actionType: .createSubtasks,
                        parameters: ["aiGenerated": true]
                    ),
                    confidence: confidence
                )
                
                suggestions.append(suggestion)
            }
        }
        
        return suggestions
    }
}