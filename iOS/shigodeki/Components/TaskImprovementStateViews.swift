//
//  TaskImprovementStateViews.swift
//  shigodeki
//
//  Extracted from TaskImprovementSuggestionView.swift for CLAUDE.md compliance
//  Task improvement state-specific view components
//

import SwiftUI

// MARK: - Loading State View

struct TaskImprovementLoadingView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            ProgressView()
                .scaleEffect(1.2)
            
            Text("分析エンジンを初期化中...")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("タスクデータを読み込んでいます")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Idle State View

struct TaskImprovementIdleView: View {
    let onStartAnalysis: () -> Void
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: "lightbulb.2")
                .font(.system(size: 80))
                .foregroundColor(.orange)
            
            VStack(spacing: 12) {
                Text("タスク改善分析")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("あなたのタスクを分析して、\n効率を向上させる提案をします")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
            
            Button(action: onStartAnalysis) {
                HStack {
                    Image(systemName: "play.fill")
                    Text("分析開始")
                }
                .frame(minWidth: 200)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .padding(.top, 20)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Analysis Progress View

struct TaskAnalysisProgressView: View {
    let engine: TaskImprovementEngine
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            ProgressView()
                .scaleEffect(1.5)
            
            Text("分析中...")
                .font(.title3)
                .fontWeight(.semibold)
            
            if !engine.analysisMessage.isEmpty {
                Text(engine.analysisMessage)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Applied State View

struct TaskImprovementAppliedView: View {
    let onStartNewAnalysis: () -> Void
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
            
            VStack(spacing: 12) {
                Text("改善完了！")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("選択された改善提案が適用されました。\n新しい分析を実行できます。")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
            
            Button(action: onStartNewAnalysis) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("新しい分析を開始")
                }
                .frame(minWidth: 200)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .padding(.top, 20)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Error State View

struct TaskImprovementErrorView: View {
    let engine: TaskImprovementEngine
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 80))
                .foregroundColor(.red)
            
            VStack(spacing: 12) {
                Text("分析に失敗しました")
                    .font(.title2)
                    .fontWeight(.bold)
                
                if let error = engine.error {
                    Text(error.localizedDescription)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                }
            }
            
            Button(action: onRetry) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("再試行")
                }
                .frame(minWidth: 200)
                .padding()
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .padding(.top, 20)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}