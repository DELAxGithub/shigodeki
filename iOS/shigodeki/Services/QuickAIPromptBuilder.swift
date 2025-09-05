import Foundation

// MARK: - Prompt Building Service

struct QuickAIPromptBuilder {
    static func buildPrompt(for generationType: GenerationType, input: String) -> String {
        let baseInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        switch generationType {
        case .quickTasks:
            return """
            以下の要求を実行可能なタスクリストに変換してください：
            
            \(baseInput)
            
            シンプルで実行しやすいタスクを5-8個程度生成してください。
            """
            
        case .structuredProject:
            return """
            以下のプロジェクトを段階的な計画に分解してください：
            
            \(baseInput)
            
            プロジェクトの成功に必要な主要なフェーズとタスクを含めてください。
            各タスクは具体的で測定可能にしてください。
            """
            
        case .dailyPlanning:
            return """
            以下の状況に基づいて今日または明日の行動計画を立ててください：
            
            \(baseInput)
            
            時間管理を考慮し、優先度の高いタスクから順番に配置してください。
            現実的で実行可能な計画にしてください。
            """
            
        case .brainstorm:
            return """
            以下のアイデアやテーマを具体的なアクションプランに展開してください：
            
            \(baseInput)
            
            アイデアを実現するための段階的なステップと、
            各ステップで必要な具体的なタスクを生成してください。
            """
        }
    }
    
    static func mapGenerationTypeToProjectType(_ generationType: GenerationType) -> ProjectType {
        switch generationType {
        case .quickTasks: return .personal
        case .structuredProject: return .work
        case .dailyPlanning: return .personal
        case .brainstorm: return .creative
        }
    }
}