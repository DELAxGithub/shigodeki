//
//  TaskImprovementSuggestionView.swift
//  shigodeki
//
//  Created by Claude on 2025-08-30.
//

import SwiftUI

struct TaskImprovementSuggestionView: View {
    @EnvironmentObject private var sharedManagers: SharedManagerStore
    @State private var improvementEngine: TaskImprovementEngine?
    @State private var selectedSuggestions: Set<UUID> = []
    @State private var showingApplyConfirmation = false
    @State private var isEngineLoaded = false
    
    let userId: String
    
    init(userId: String) {
        self.userId = userId
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Analysis State Header
                analysisHeaderSection
                
                // Content Area
                Group {
                    if let engine = improvementEngine {
                        switch engine.analysisState {
                        case .idle:
                            idleStateView
                        case .analyzing, .applying:
                            analysisProgressView(engine: engine)
                        case .completed:
                            suggestionsListView(engine: engine)
                        case .applied:
                            appliedStateView
                        case .failed:
                            errorStateView(engine: engine)
                        }
                    } else {
                        loadingStateView
                    }
                }
            }
            .navigationTitle("タスク改善提案")
            .navigationBarItems(
                leading: refreshButton,
                trailing: analyzeButton
            )
        }
        .onAppear {
            Task {
                await loadImprovementEngine()
            }
        }
        .alert("改善提案を適用", isPresented: $showingApplyConfirmation) {
            Button("適用する") {
                applySelectedImprovements()
            }
            Button("キャンセル", role: .cancel) { }
        } message: {
            Text("選択した\(selectedSuggestions.count)個の改善提案を適用しますか？")
        }
    }
    
    // MARK: - Analysis Header
    private var analysisHeaderSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("AI タスク分析")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(improvementEngine?.analysisMessage ?? "エンジンを読み込み中...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                analysisStateIndicator
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            if let engine = improvementEngine, 
               engine.analysisState == .analyzing || engine.analysisState == .applying {
                ProgressView(value: engine.analysisProgress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    .padding(.horizontal, 16)
            }
        }
        .background(Color(.secondarySystemBackground))
    }
    
    private var analysisStateIndicator: some View {
        Group {
            if let engine = improvementEngine {
                switch engine.analysisState {
                case .idle:
                    Image(systemName: "play.circle")
                        .foregroundColor(.gray)
                case .analyzing:
                    ProgressView()
                        .scaleEffect(0.8)
                case .completed:
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                case .applying:
                    ProgressView()
                        .scaleEffect(0.8)
                case .applied:
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                case .failed:
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                }
            } else {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
        .font(.title2)
    }
    
    // MARK: - State Views
    private var loadingStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ProgressView()
                .scaleEffect(1.5)
            
            VStack(spacing: 8) {
                Text("エンジンを読み込み中")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("TaskImprovementEngineを初期化しています")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
        .padding()
    }
    
    private var idleStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "lightbulb.max")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            VStack(spacing: 8) {
                Text("タスク改善分析")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("AIがあなたのタスクを分析して\n改善提案を生成します")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: startAnalysis) {
                HStack {
                    Image(systemName: "brain.head.profile")
                    Text("分析開始")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
            }
            
            Spacer()
        }
        .padding()
    }
    
    private func analysisProgressView(engine: TaskImprovementEngine) -> some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                
                Text(engine.analysisMessage)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                
                Text("\(Int(engine.analysisProgress * 100))% 完了")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
    }
    
    private func suggestionsListView(engine: TaskImprovementEngine) -> some View {
        VStack(spacing: 0) {
            // Summary Header
            HStack {
                Text("\(engine.improvements.count)個の改善提案")
                    .font(.headline)
                
                Spacer()
                
                if !selectedSuggestions.isEmpty {
                    Button("選択した提案を適用") {
                        showingApplyConfirmation = true
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.secondarySystemBackground))
            
            // Suggestions List
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(engine.improvements, id: \.id) { suggestion in
                        SuggestionRowView(
                            suggestion: suggestion,
                            isSelected: selectedSuggestions.contains(suggestion.id),
                            onToggle: { toggleSuggestionSelection(suggestion.id) }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
        }
    }
    
    private var appliedStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            VStack(spacing: 8) {
                Text("適用完了")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("改善提案が正常に適用されました")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("新しい分析を開始") {
                if let engine = improvementEngine {
                    engine.reset()
                    startAnalysis()
                }
            }
            .font(.headline)
            .foregroundColor(.white)
            .padding()
            .background(Color.blue)
            .cornerRadius(12)
            
            Spacer()
        }
        .padding()
    }
    
    private func errorStateView(engine: TaskImprovementEngine) -> some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.red)
            
            VStack(spacing: 8) {
                Text("分析エラー")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                if let error = engine.error {
                    Text(error.localizedDescription)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            Button("再試行") {
                engine.reset()
                startAnalysis()
            }
            .font(.headline)
            .foregroundColor(.white)
            .padding()
            .background(Color.blue)
            .cornerRadius(12)
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Navigation Buttons
    private var refreshButton: some View {
        Button("リセット") {
            improvementEngine?.reset()
        }
        .disabled(improvementEngine?.analysisState == .analyzing || improvementEngine?.analysisState == .applying)
    }
    
    private var analyzeButton: some View {
        Button("分析") {
            startAnalysis()
        }
        .disabled(improvementEngine?.analysisState == .analyzing || improvementEngine?.analysisState == .applying)
    }
    
    // MARK: - Actions
    private func loadImprovementEngine() async {
        let engine = await sharedManagers.getTaskImprovementEngine()
        await MainActor.run {
            self.improvementEngine = engine
            self.isEngineLoaded = true
            
            // Auto-start analysis if engine is idle
            if engine.analysisState == .idle {
                startAnalysis()
            }
        }
    }
    
    private func startAnalysis() {
        guard let engine = improvementEngine else { return }
        Task {
            await engine.analyzeUserTasks(userId: userId)
        }
    }
    
    private func toggleSuggestionSelection(_ suggestionId: UUID) {
        if selectedSuggestions.contains(suggestionId) {
            selectedSuggestions.remove(suggestionId)
        } else {
            selectedSuggestions.insert(suggestionId)
        }
    }
    
    private func applySelectedImprovements() {
        guard let engine = improvementEngine else { return }
        Task {
            do {
                try await engine.applyImprovements(selectedSuggestions)
                selectedSuggestions.removeAll()
            } catch {
                print("Error applying improvements: \(error)")
            }
        }
    }
}

// MARK: - Supporting Views

struct SuggestionRowView: View {
    let suggestion: ImprovementSuggestion
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header Row
            HStack {
                Button(action: onToggle) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundColor(isSelected ? .blue : .gray)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(suggestion.title)
                            .font(.headline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        impactBadge
                    }
                    
                    HStack {
                        Image(systemName: suggestion.type.iconName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(suggestion.type.displayName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("信頼度: \(Int(suggestion.confidence * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Description
            Text(suggestion.description)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
            
            // Impact Details
            HStack {
                Label(suggestion.impact.description, systemImage: "chart.line.uptrend.xyaxis")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if suggestion.impact.estimatedTimeReduction > 0 {
                    Label("\(suggestion.impact.estimatedTimeReduction, specifier: "%.1f")時間/週 削減", systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.blue : Color(.separator), lineWidth: isSelected ? 2 : 1)
        )
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
    
    private var impactBadge: some View {
        Text(suggestion.impact.type.displayName)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(suggestion.impact.type.color.opacity(0.2))
            .foregroundColor(suggestion.impact.type.color)
            .cornerRadius(8)
    }
}

// MARK: - Extensions

extension ImprovementType {
    var displayName: String {
        switch self {
        case .taskBreakdown: return "タスク分割"
        case .priorityAdjustment: return "優先度調整"
        case .deadlineOptimization: return "期限最適化"
        case .dependencyMapping: return "依存関係整理"
        case .categoryReorganization: return "カテゴリ整理"
        }
    }
}

#Preview {
    TaskImprovementSuggestionView(userId: "preview-user")
}