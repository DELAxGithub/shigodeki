import Foundation
import SwiftUI

/// Service responsible for building AI prompts for task generation and analysis
struct AITaskPromptBuilder {
    
    /// Builds an enhanced prompt with project type context and general guidelines
    static func buildEnhancedPrompt(userPrompt: String, projectType: ProjectType?) -> String {
        var prompt = userPrompt
        
        // Add project type context if available
        if let projectType = projectType {
            let typeContext = getProjectTypeContext(projectType)
            prompt = "\(typeContext)\n\nProject request: \(prompt)"
        }
        
        // Add general context for better task generation
        let generalContext = """
        
        Additional context:
        - This is for a task management app where users organize work into projects, phases, and tasks
        - Tasks can have subtasks for detailed breakdown
        - Include time estimates that are realistic and helpful
        - Consider dependencies between tasks when creating phases
        - Focus on actionable, specific tasks rather than vague goals
        """
        
        return prompt + generalContext
    }
    
    /// Builds a prompt for generating detailed task descriptions and implementation steps
    static func buildTaskDetailPrompt(for task: ShigodekiTask) -> String {
        let baseDescription = task.description?.isEmpty == false ? task.description! : "詳細な説明はありません"
        
        return """
        以下のタスクについて、実行可能で詳細な説明を日本語で生成してください：

        タスク名: \(task.title)
        現在の説明: \(baseDescription)

        以下の要素を含めて、実用的で具体的な詳細を提供してください：
        1. 実行手順（ステップバイステップ）
        2. 必要な準備や前提条件
        3. 完了の判断基準
        4. 注意点や考慮事項
        5. 推定所要時間

        結果は実際にタスクを実行する人が参考にできるよう、具体的で実用的な内容にしてください。
        """
    }
    
    // MARK: - Private Methods
    
    private static func getProjectTypeContext(_ projectType: ProjectType) -> String {
        switch projectType {
        case .work:
            return "This is a work/professional project. Focus on business objectives, deliverables, and professional workflows."
        case .personal:
            return "This is a personal project. Consider work-life balance, personal goals, and individual capacity."
        case .family:
            return "This is a family project involving multiple family members. Consider coordination, age-appropriate tasks, and family schedules."
        case .creative:
            return "This is a creative project. Focus on artistic processes, inspiration phases, and creative milestones."
        case .learning:
            return "This is a learning/educational project. Include research phases, practice tasks, and knowledge building steps."
        case .health:
            return "This is a health and wellness project. Consider gradual progress, sustainability, and health best practices."
        case .travel:
            return "This is a travel project. Include planning phases, booking tasks, and travel logistics."
        case .home:
            return "This is a home improvement or household project. Consider practical steps, safety, and maintenance."
        case .financial:
            return "This is a financial planning project. Focus on research, analysis, and systematic financial steps."
        case .social:
            return "This is a social or community project. Consider group coordination, communication, and social dynamics."
        case .custom:
            return "This is a custom project type. Adapt suggestions to be flexible and broadly applicable."
        }
    }
}