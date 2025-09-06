import Foundation

// MARK: - Template Complexity Calculator

class TemplateComplexityCalculator {
    
    static func calculateComplexity(_ template: ProjectTemplate) -> ComplexityMetrics {
        let totalTasks = template.phases.reduce(0) { sum, phase in
            sum + phase.taskLists.reduce(0) { listSum, list in
                listSum + list.tasks.count
            }
        }
        
        let totalSubtasks = template.phases.reduce(0) { sum, phase in
            sum + phase.taskLists.reduce(0) { listSum, list in
                listSum + list.tasks.reduce(0) { taskSum, task in
                    taskSum + task.subtasks.count
                }
            }
        }
        
        let averageTasksPerPhase = template.phases.isEmpty ? 0 : Double(totalTasks) / Double(template.phases.count)
        
        let dependencyCount = 0
        
        let estimatedTotalHours = template.phases.reduce(0.0) { sum, phase in
            sum + phase.taskLists.reduce(0.0) { listSum, list in
                listSum + list.tasks.reduce(0.0) { taskSum, task in
                    taskSum + Double(task.estimatedHours ?? 0)
                }
            }
        }
        
        // Calculate complexity score (0.0 - 1.0)
        let taskComplexity = min(1.0, Double(totalTasks) / 100.0) // Normalize to 100 tasks
        let dependencyComplexity = min(1.0, Double(dependencyCount) / 50.0) // Normalize to 50 dependencies
        let phaseComplexity = min(1.0, Double(template.phases.count) / 20.0) // Normalize to 20 phases
        let timeComplexity = min(1.0, estimatedTotalHours / 1000.0) // Normalize to 1000 hours
        
        let complexityScore = (taskComplexity * 0.4) + (dependencyComplexity * 0.3) + 
                             (phaseComplexity * 0.2) + (timeComplexity * 0.1)
        
        let maxRecommendedTasks = calculateMaxRecommendedTasks(for: template)
        
        return ComplexityMetrics(
            totalTasks: totalTasks,
            totalSubtasks: totalSubtasks,
            averageTasksPerPhase: averageTasksPerPhase,
            dependencyCount: dependencyCount,
            estimatedTotalHours: estimatedTotalHours,
            complexityScore: complexityScore,
            maxRecommendedTasks: maxRecommendedTasks
        )
    }
    
    static func generateOptimizationSuggestions(_ template: ProjectTemplate, 
                                               complexity: ComplexityMetrics) -> [ValidationSuggestion] {
        var suggestions: [ValidationSuggestion] = []
        
        // High complexity suggestions
        if complexity.isHighComplexity {
            suggestions.append(ValidationSuggestion(
                type: .optimization,
                message: "テンプレートの複雑度が高いです。フェーズを細分化することを検討してください",
                location: "全体"
            ))
        }
        
        // Too many tasks per phase
        if complexity.averageTasksPerPhase > 20 {
            suggestions.append(ValidationSuggestion(
                type: .optimization,
                message: "フェーズあたりのタスク数が多すぎます。フェーズを分割することを推奨します",
                location: "フェーズ構成"
            ))
        }
        
        // Too many dependencies
        if complexity.dependencyCount > complexity.totalTasks / 2 {
            suggestions.append(ValidationSuggestion(
                type: .performance,
                message: "依存関係が多すぎます。並行実行を妨げる可能性があります",
                location: "タスク依存関係"
            ))
        }
        
        // Very long estimation
        if complexity.estimatedTotalHours > 500 {
            suggestions.append(ValidationSuggestion(
                type: .bestPractice,
                message: "推定時間が長すぎます。より小さなテンプレートに分割することを検討してください",
                location: "時間見積もり"
            ))
        }
        
        return suggestions
    }
    
    private static func calculateMaxRecommendedTasks(for template: ProjectTemplate) -> Int {
        // Base recommendation based on difficulty
        let baseTasks: Int
        switch template.metadata.difficulty ?? TemplateDifficulty.beginner {
        case .beginner: baseTasks = 30
        case .intermediate: baseTasks = 60
        case .advanced: baseTasks = 100
        case .expert: baseTasks = 150
        }
        
        // Adjust based on target audience
        let targetAudience = template.metadata.targetAudience ?? "individual"
        let audienceMultiplier: Double
        switch targetAudience {
        case "individual": audienceMultiplier = 1.0
        case "small team", "smallTeam": audienceMultiplier = 1.5
        case "medium team", "mediumTeam": audienceMultiplier = 2.0
        case "large team", "largeTeam": audienceMultiplier = 3.0
        case "enterprise": audienceMultiplier = 4.0
        default: audienceMultiplier = 1.0
        }
        
        
        return Int(Double(baseTasks) * audienceMultiplier)
    }
}