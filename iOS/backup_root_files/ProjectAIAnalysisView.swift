//
//  ProjectAIAnalysisView.swift
//  shigodeki
//
//  Created by Claude on 2025-08-29.
//

import SwiftUI

struct ProjectAIAnalysisView: View {
    let project: Project
    @ObservedObject var phaseManager: PhaseManager
    @ObservedObject var aiGenerator: AITaskGenerator
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedAnalysisType: AnalysisType = .progress
    @State private var analysisResult: String = ""
    @State private var isAnalyzing = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
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
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("AI プロジェクト分析")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text(project.name)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "brain")
                            .font(.title)
                            .foregroundColor(.blue)
                    }
                    
                    Text("プロジェクトの状況を AI が分析し、具体的なアドバイスを提供します")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(Color(.systemGray6))
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Analysis Type Selection
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("分析タイプを選択")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                
                                Spacer()
                            }
                            
                            LazyVStack(spacing: 8) {
                                ForEach(AnalysisType.allCases) { analysisType in
                                    AnalysisTypeCard(
                                        analysisType: analysisType,
                                        isSelected: selectedAnalysisType == analysisType,
                                        onTap: {
                                            selectedAnalysisType = analysisType
                                            analysisResult = ""
                                        }
                                    )
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top)
                        
                        // Generate Button
                        Button(action: generateAnalysis) {
                            HStack {
                                if isAnalyzing {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .foregroundColor(.white)
                                } else {
                                    Image(systemName: "sparkles")
                                }
                                
                                Text(isAnalyzing ? "分析中..." : "AI 分析を開始")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(aiGenerator.availableProviders.isEmpty ? Color.gray : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(isAnalyzing || aiGenerator.availableProviders.isEmpty)
                        .padding(.horizontal)
                        
                        // Results
                        if !analysisResult.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: selectedAnalysisType.icon)
                                        .font(.title3)
                                        .foregroundColor(selectedAnalysisType.color)
                                    
                                    Text("分析結果")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                    
                                    Spacer()
                                }
                                
                                Text(analysisResult)
                                    .font(.body)
                                    .lineSpacing(2)
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(12)
                            }
                            .padding(.horizontal)
                        }
                        
                        Spacer(minLength: 20)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
            }
            .alert("エラー", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func generateAnalysis() {
        guard !aiGenerator.availableProviders.isEmpty else {
            errorMessage = "API設定が必要です"
            showingError = true
            return
        }
        
        isAnalyzing = true
        analysisResult = ""
        
        let prompt = buildAnalysisPrompt(for: selectedAnalysisType)
        
        Task {
            do {
                let result = try await aiGenerator.generateText(prompt: prompt)
                
                await MainActor.run {
                    analysisResult = result
                    isAnalyzing = false
                }
                
            } catch {
                await MainActor.run {
                    errorMessage = "分析の生成に失敗しました: \(error.localizedDescription)"
                    showingError = true
                    isAnalyzing = false
                }
            }
        }
    }
    
    private func buildAnalysisPrompt(for analysisType: AnalysisType) -> String {
        let projectInfo = buildProjectContext()
        
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
    
    private func buildProjectContext() -> String {
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

struct AnalysisTypeCard: View {
    let analysisType: ProjectAIAnalysisView.AnalysisType
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(analysisType.color.opacity(isSelected ? 0.2 : 0.1))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: analysisType.icon)
                        .font(.title3)
                        .foregroundColor(analysisType.color)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(analysisType.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(analysisType.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(analysisType.color)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? analysisType.color.opacity(0.1) : Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? analysisType.color : Color.clear, lineWidth: 2)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    let sampleProject = Project(name: "Sample Project", description: "A sample project for preview", ownerId: "user1")
    ProjectAIAnalysisView(project: sampleProject, phaseManager: PhaseManager(), aiGenerator: AITaskGenerator())
}