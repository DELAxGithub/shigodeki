//
//  ProjectAnalysisEngine.swift
//  shigodeki
//
//  Extracted from ProjectAIAnalysisView.swift for CLAUDE.md compliance
//  Project analysis engine service
//

import Foundation

class ProjectAnalysisEngine {
    
    @MainActor
    static func buildAnalysisPrompt(
        for analysisType: AnalysisType,
        project: Project,
        phaseManager: PhaseManager
    ) -> String {
        let projectInfo = buildProjectContext(project: project, phaseManager: phaseManager)
        
        let basePrompt = """
        プロジェクト名: \(project.name)
        プロジェクト説明: \(project.description ?? "説明なし")
        
        \(projectInfo)
        
        """
        
        switch analysisType {
        case .progress:
            return basePrompt + """
            このプロジェクトの進捗状況を分析してください。以下の観点で評価をお願いします：
            
            1. 全体的な進捗率の評価
            2. 各フェーズの完了状況
            3. 予定との比較（遅れている場合はその要因）
            4. 進捗を加速するための具体的な提案
            
            分析は具体的で実行可能な内容でお願いします。
            """
            
        case .bottlenecks:
            return basePrompt + """
            このプロジェクトの進行を阻害している要因（ボトルネック）を特定し、解決策を提案してください：
            
            1. 現在のボトルネックの特定
            2. それぞれの影響度と緊急度の評価
            3. 具体的な解決策の提案
            4. 予防策の提案
            
            実務的で実行可能な解決策を重点的にお願いします。
            """
            
        case .nextSteps:
            return basePrompt + """
            現在の状況を踏まえて、次に取るべきアクションを優先度順に提案してください：
            
            1. 最優先で着手すべきタスク（3つ）
            2. 中期的に取り組むべき課題（3-5つ）
            3. 長期的な改善点
            4. 各アクションの推定工数と依存関係
            
            具体的で実行可能な内容でお願いします。
            """
            
        case .risks:
            return basePrompt + """
            このプロジェクトに潜在するリスクを特定し、対策を提案してください：
            
            1. 技術的リスク
            2. スケジュールリスク
            3. リソースリスク
            4. 品質リスク
            5. 各リスクの発生確率と影響度
            6. 具体的な対策・緩和策
            
            実践的なリスク管理の観点で分析してください。
            """
            
        case .timeline:
            return basePrompt + """
            現在の進捗ペースを分析し、タイムラインに関する評価と提案をしてください：
            
            1. 現在のペースでの完了予測
            2. 当初予定との比較
            3. スケジュール短縮の可能性
            4. クリティカルパスの特定
            5. リソース配分の最適化提案
            
            現実的なスケジュール調整の提案をお願いします。
            """
        }
    }
    
    @MainActor
    private static func buildProjectContext(project: Project, phaseManager: PhaseManager) -> String {
        var context = ""
        
        // Phase information
        let phases = phaseManager.phases
        if !phases.isEmpty {
            context += "フェーズ一覧:\n"
            for (index, phase) in phases.enumerated() {
                let status = phase.isCompleted ? "完了" : "進行中"
                context += "\(index + 1). \(phase.name) - \(status)\n"
                if let description = phase.description, !description.isEmpty {
                    context += "   説明: \(description)\n"
                }
            }
            context += "\n"
        }
        
        // Progress summary
        let completedPhases = phases.filter { $0.isCompleted }.count
        let totalPhases = phases.count
        
        if totalPhases > 0 {
            context += "進捗サマリー:\n"
            context += "完了フェーズ: \(completedPhases)/\(totalPhases)\n"
            context += "進捗率: \(Int(Double(completedPhases) / Double(totalPhases) * 100))%\n\n"
        }
        
        return context
    }
}