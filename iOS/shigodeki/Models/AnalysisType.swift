//
//  AnalysisType.swift
//  shigodeki
//
//  Extracted from ProjectAIAnalysisView.swift for CLAUDE.md compliance
//  Analysis type definitions for AI project analysis
//

import SwiftUI

enum AnalysisType: String, CaseIterable, Identifiable {
    case progress = "progress"
    case bottlenecks = "bottlenecks"
    case nextSteps = "nextsteps"
    case risks = "risks"
    case timeline = "timeline"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .progress:
            return "進捗分析"
        case .bottlenecks:
            return "ボトルネック分析"
        case .nextSteps:
            return "次のステップ"
        case .risks:
            return "リスク分析"
        case .timeline:
            return "タイムライン分析"
        }
    }
    
    var description: String {
        switch self {
        case .progress:
            return "プロジェクトの現在の進捗状況を分析し、達成率や遅延要因を評価"
        case .bottlenecks:
            return "プロジェクト進行を阻害している要因を特定し、解決策を提案"
        case .nextSteps:
            return "現在の状況に基づいて、次に取るべきアクションを優先度順に提案"
        case .risks:
            return "プロジェクトに潜在するリスクを特定し、対策を提案"
        case .timeline:
            return "現在のペースでの完了予測と、スケジュール調整の提案"
        }
    }
    
    var icon: String {
        switch self {
        case .progress:
            return "chart.bar.fill"
        case .bottlenecks:
            return "exclamationmark.triangle.fill"
        case .nextSteps:
            return "arrow.right.circle.fill"
        case .risks:
            return "shield.fill"
        case .timeline:
            return "calendar.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .progress:
            return .blue
        case .bottlenecks:
            return .orange
        case .nextSteps:
            return .green
        case .risks:
            return .red
        case .timeline:
            return .purple
        }
    }
}