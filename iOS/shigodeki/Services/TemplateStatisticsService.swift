//
//  TemplateStatisticsService.swift
//  shigodeki
//
//  Extracted from ProjectTemplate.swift for CLAUDE.md compliance
//  Template statistics calculation and analysis service
//

import Foundation

struct TemplateStats: Codable, Hashable {
    let totalPhases: Int
    let totalTaskLists: Int
    let totalTasks: Int
    let totalSubtasks: Int
    let estimatedCompletionHours: Double
    let optionalTaskCount: Int
    let averagePhaseComplexity: Double
    
    init(template: ProjectTemplate) {
        self.totalPhases = template.phases.count
        self.totalTaskLists = template.phases.reduce(0) { $0 + $1.taskLists.count }
        self.totalTasks = template.phases.reduce(0) { phaseSum, phase in
            phaseSum + phase.taskLists.reduce(0) { taskListSum, taskList in
                taskListSum + taskList.tasks.count
            }
        }
        self.totalSubtasks = template.phases.reduce(0) { phaseSum, phase in
            phaseSum + phase.taskLists.reduce(0) { taskListSum, taskList in
                taskListSum + taskList.tasks.reduce(0) { taskSum, task in
                    taskSum + task.subtasks.count
                }
            }
        }
        self.estimatedCompletionHours = template.phases.reduce(0.0) { phaseSum, phase in
            phaseSum + phase.taskLists.reduce(0.0) { taskListSum, taskList in
                taskListSum + taskList.tasks.reduce(0.0) { taskSum, task in
                    taskSum + (task.estimatedHours ?? 1.0)
                }
            }
        }
        self.optionalTaskCount = template.phases.reduce(0) { phaseSum, phase in
            phaseSum + phase.taskLists.reduce(0) { taskListSum, taskList in
                taskListSum + taskList.tasks.filter { $0.isOptional }.count
            }
        }
        self.averagePhaseComplexity = totalTasks > 0 ? Double(totalTasks) / Double(totalPhases) : 0.0
    }
    
    var completionTimeRange: String {
        let days = Int(estimatedCompletionHours / 8) // 1日8時間想定
        switch days {
        case 0: return "数時間"
        case 1: return "1日"
        case 2...7: return "\(days)日"
        case 8...30: return "\(days/7)週間"
        case 31...365: return "\(days/30)ヶ月"
        default: return "\(days/365)年"
        }
    }
    
    var complexityLevel: TemplateDifficulty {
        switch averagePhaseComplexity {
        case 0..<5: return .beginner
        case 5..<15: return .intermediate
        case 15..<30: return .advanced
        default: return .expert
        }
    }
}

@MainActor
class TemplateStatisticsService: ObservableObject {
    
    // MARK: - Template Analysis
    
    func generateStats(for template: ProjectTemplate) -> TemplateStats {
        return TemplateStats(template: template)
    }
    
    func analyzeTemplateComplexity(_ template: ProjectTemplate) -> TemplateComplexityAnalysis {
        let stats = TemplateStats(template: template)
        
        return TemplateComplexityAnalysis(
            template: template,
            stats: stats,
            complexity: calculateComplexityScore(stats),
            recommendations: generateRecommendations(for: stats)
        )
    }
    
    // MARK: - Complexity Analysis
    
    private func calculateComplexityScore(_ stats: TemplateStats) -> Double {
        let phaseComplexity = min(Double(stats.totalPhases) / 10.0, 1.0) * 0.2
        let taskComplexity = min(Double(stats.totalTasks) / 100.0, 1.0) * 0.4
        let subtaskComplexity = min(Double(stats.totalSubtasks) / 200.0, 1.0) * 0.2
        let timeComplexity = min(stats.estimatedCompletionHours / 160.0, 1.0) * 0.2
        
        return phaseComplexity + taskComplexity + subtaskComplexity + timeComplexity
    }
    
    private func generateRecommendations(for stats: TemplateStats) -> [String] {
        var recommendations: [String] = []
        
        if stats.totalPhases > 10 {
            recommendations.append("フェーズ数が多いため、関連するフェーズをグループ化することを検討してください")
        }
        
        if stats.averagePhaseComplexity > 20 {
            recommendations.append("各フェーズの複雑度が高いため、タスクをより細かく分割することを推奨します")
        }
        
        if stats.optionalTaskCount > stats.totalTasks / 2 {
            recommendations.append("オプショナルタスクが多いため、コアタスクを明確にすることを推奨します")
        }
        
        if stats.estimatedCompletionHours > 160 {
            recommendations.append("完了予想時間が長いため、マイルストーンの設定を検討してください")
        }
        
        return recommendations
    }
}

struct TemplateComplexityAnalysis {
    let template: ProjectTemplate
    let stats: TemplateStats
    let complexity: Double
    let recommendations: [String]
    
    var complexityDescription: String {
        switch complexity {
        case 0..<0.3: return "シンプル"
        case 0.3..<0.6: return "標準"
        case 0.6..<0.8: return "複雑"
        default: return "非常に複雑"
        }
    }
}