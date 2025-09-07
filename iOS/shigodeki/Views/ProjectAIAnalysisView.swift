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
    
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ProjectAnalysisHeader(project: project)
                
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
        
        let prompt = ProjectAnalysisEngine.buildAnalysisPrompt(
            for: selectedAnalysisType,
            project: project,
            phaseManager: phaseManager
        )
        
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
    
}


#Preview {
    let sampleProject = Project(name: "Sample Project", description: "A sample project for preview", ownerId: "user1")
    ProjectAIAnalysisView(project: sampleProject, phaseManager: PhaseManager(), aiGenerator: AITaskGenerator())
}