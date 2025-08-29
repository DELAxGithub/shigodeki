//
//  TaskImprovementSuggestionView.swift
//  shigodeki
//
//  Created by Claude on 2025-08-29.
//

import SwiftUI

struct TaskImprovementSuggestionView: View {
    @ObservedObject var taskManager: TaskManager
    @ObservedObject var aiGenerator: AITaskGenerator
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedImprovementType: ImprovementType = .productivity
    @State private var selectedTasks: Set<String> = []
    @State private var suggestions: [TaskSuggestion] = []
    @State private var isGenerating = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    private let maxSelectedTasks = 10
    
    enum ImprovementType: String, CaseIterable, Identifiable {
        case productivity = "productivity"
        case clarity = "clarity"
        case priority = "priority"
        case workflow = "workflow"
        case automation = "automation"
        
        var id: String { rawValue }
        
        var title: String {
            switch self {
            case .productivity:
                return "生産性向上"
            case .clarity:
                return "明確性改善"
            case .priority:
                return "優先度最適化"
            case .workflow:
                return "ワークフロー改善"
            case .automation:
                return "自動化提案"
            }
        }
        
        var description: String {
            switch self {
            case .productivity:
                return "タスクの効率性を高める方法を提案"
            case .clarity:
                return "タスクの説明や目標をより明確にする提案"
            case .priority:
                return "タスクの優先度を最適化する提案"
            case .workflow:
                return "タスクの順序や依存関係を改善する提案"
            case .automation:
                return "繰り返しタスクの自動化方法を提案"
            }
        }
        
        var icon: String {
            switch self {
            case .productivity:
                return "speedometer"
            case .clarity:
                return "eye.fill"
            case .priority:
                return "exclamationmark.triangle.fill"
            case .workflow:
                return "arrow.triangle.swap"
            case .automation:
                return "gearshape.2.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .productivity:
                return .blue
            case .clarity:
                return .green
            case .priority:
                return .orange
            case .workflow:
                return .purple
            case .automation:
                return .red
            }
        }
    }
    
    struct TaskSuggestion: Identifiable {
        let id = UUID()
        let taskId: String
        let taskTitle: String
        let improvementType: ImprovementType
        let suggestions: [String]
        let reasoning: String
    }
    
    private var allTasks: [ShigodekiTask] {
        taskManager.tasks.values.flatMap { $0 }
    }
    
    private var incompleteTasks: [ShigodekiTask] {
        allTasks.filter { !$0.isCompleted }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("AI タスク改善提案")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("既存タスクの改善案を AI が提案")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "lightbulb.fill")
                            .font(.title)
                            .foregroundColor(.yellow)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Improvement Type Selection
                        VStack(alignment: .leading, spacing: 12) {
                            Text("改善タイプ")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .padding(.horizontal)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                                ForEach(ImprovementType.allCases) { type in
                                    ImprovementTypeCard(
                                        type: type,
                                        isSelected: selectedImprovementType == type,
                                        onTap: {
                                            selectedImprovementType = type
                                            selectedTasks.removeAll()
                                            suggestions.removeAll()
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // Task Selection
                        if !incompleteTasks.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("改善対象タスク")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                    
                                    Spacer()
                                    
                                    Text("\(selectedTasks.count)/\(maxSelectedTasks)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal)
                                
                                LazyVStack(spacing: 8) {
                                    ForEach(incompleteTasks.prefix(20)) { task in
                                        TaskSelectionRow(
                                            task: task,
                                            isSelected: selectedTasks.contains(task.id ?? ""),
                                            onToggle: { isSelected in
                                                guard let taskId = task.id else { return }
                                                
                                                if isSelected && selectedTasks.count < maxSelectedTasks {
                                                    selectedTasks.insert(taskId)
                                                } else if !isSelected {
                                                    selectedTasks.remove(taskId)
                                                }
                                            }
                                        )
                                    }
                                }
                                .padding(.horizontal)
                                
                                if incompleteTasks.count > 20 {
                                    Text("最初の20件のタスクを表示しています")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal)
                                }
                            }
                        }
                        
                        // Generate Button
                        Button(action: generateSuggestions) {
                            HStack {
                                if isGenerating {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .foregroundColor(.white)
                                } else {
                                    Image(systemName: "sparkles")
                                }
                                
                                Text(isGenerating ? "提案生成中..." : "改善提案を生成")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(canGenerate ? Color.blue : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(!canGenerate || isGenerating)
                        .padding(.horizontal)
                        
                        // Suggestions Results
                        if !suggestions.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Image(systemName: selectedImprovementType.icon)
                                        .font(.title3)
                                        .foregroundColor(selectedImprovementType.color)
                                    
                                    Text("改善提案")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                    
                                    Spacer()
                                }
                                .padding(.horizontal)
                                
                                LazyVStack(spacing: 12) {
                                    ForEach(suggestions) { suggestion in
                                        SuggestionCard(suggestion: suggestion)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        
                        Spacer(minLength: 20)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") {
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
    
    private var canGenerate: Bool {
        !selectedTasks.isEmpty && !aiGenerator.availableProviders.isEmpty
    }
    
    private func generateSuggestions() {
        guard canGenerate else {
            if aiGenerator.availableProviders.isEmpty {
                errorMessage = "API設定が必要です"
            } else {
                errorMessage = "改善対象のタスクを選択してください"
            }
            showingError = true
            return
        }
        
        isGenerating = true
        suggestions.removeAll()
        
        let selectedTaskObjects = incompleteTasks.filter { task in
            selectedTasks.contains(task.id ?? "")
        }
        
        let prompt = buildImprovementPrompt(for: selectedTaskObjects, type: selectedImprovementType)
        
        Task {
            do {
                let result = try await aiGenerator.generateText(prompt: prompt)
                let parsedSuggestions = parseSuggestionsFromResponse(result, tasks: selectedTaskObjects)
                
                await MainActor.run {
                    suggestions = parsedSuggestions
                    isGenerating = false
                }
                
            } catch {
                await MainActor.run {
                    errorMessage = "改善提案の生成に失敗しました: \(error.localizedDescription)"
                    showingError = true
                    isGenerating = false
                }
            }
        }
    }
    
    private func buildImprovementPrompt(for tasks: [ShigodekiTask], type: ImprovementType) -> String {
        let taskList = tasks.enumerated().map { index, task in
            var taskInfo = "\(index + 1). \(task.title)"
            if let description = task.description, !description.isEmpty {
                taskInfo += "\n   説明: \(description)"
            }
            if let dueDate = task.dueDate {
                taskInfo += "\n   期限: \(DateFormatter.taskDueDate.string(from: dueDate))"
            }
            taskInfo += "\n   優先度: \(task.priority.displayName)"
            return taskInfo
        }.joined(separator: "\n\n")
        
        let basePrompt = """
        以下のタスクについて、\(type.title)の観点から改善提案をしてください：
        
        \(taskList)
        
        """
        
        let specificInstructions = switch type {
        case .productivity:
            """
            各タスクについて、生産性を高めるための具体的な改善案を提案してください：
            - タスクの分割や統合の提案
            - 効率的な実行方法
            - 必要なツールやリソース
            - 時間短縮のアイデア
            """
        case .clarity:
            """
            各タスクについて、より明確で実行しやすくするための改善案を提案してください：
            - 目標の明確化
            - 成功基準の設定
            - 説明の改善
            - 具体的なアクションステップ
            """
        case .priority:
            """
            各タスクについて、優先度の最適化に関する提案をしてください：
            - 現在の優先度の妥当性
            - 優先度変更の提案と理由
            - 他タスクとの相対的重要度
            - 緊急度と重要度の分析
            """
        case .workflow:
            """
            各タスクについて、ワークフロー改善の提案をしてください：
            - タスク間の依存関係の整理
            - 実行順序の最適化
            - 並行実行の可能性
            - ボトルネックの解消
            """
        case .automation:
            """
            各タスクについて、自動化の可能性と方法を提案してください：
            - 自動化可能な部分の特定
            - 自動化ツールの提案
            - テンプレート化の提案
            - 繰り返し作業の効率化
            """
        }
        
        return basePrompt + specificInstructions + """
        
        回答形式：
        各タスクに対して以下の形式で回答してください：
        
        【タスク名】
        改善提案：
        1. 具体的な改善案1
        2. 具体的な改善案2
        3. 具体的な改善案3
        理由：改善が必要な理由と期待される効果
        
        実用的で実行可能な提案をお願いします。
        """
    }
    
    private func parseSuggestionsFromResponse(_ response: String, tasks: [ShigodekiTask]) -> [TaskSuggestion] {
        var suggestions: [TaskSuggestion] = []
        
        // Simple parsing - in a real app, this would be more robust
        let sections = response.components(separatedBy: "【")
        
        for section in sections.dropFirst() {
            let parts = section.components(separatedBy: "】")
            guard parts.count >= 2 else { continue }
            
            let taskTitle = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let content = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Find matching task
            guard let matchingTask = tasks.first(where: { $0.title.contains(taskTitle) || taskTitle.contains($0.title) }),
                  let taskId = matchingTask.id else { continue }
            
            // Parse suggestions and reasoning
            let lines = content.components(separatedBy: .newlines)
            var suggestionsList: [String] = []
            var reasoning = ""
            var inReasoningSection = false
            
            for line in lines {
                let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                
                if trimmedLine.hasPrefix("理由：") {
                    inReasoningSection = true
                    reasoning = String(trimmedLine.dropFirst(3)).trimmingCharacters(in: .whitespacesAndNewlines)
                } else if inReasoningSection && !trimmedLine.isEmpty {
                    reasoning += " " + trimmedLine
                } else if !inReasoningSection && (trimmedLine.hasPrefix("1.") || trimmedLine.hasPrefix("2.") || trimmedLine.hasPrefix("3.")) {
                    let suggestion = String(trimmedLine.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !suggestion.isEmpty {
                        suggestionsList.append(suggestion)
                    }
                }
            }
            
            if !suggestionsList.isEmpty {
                let suggestion = TaskSuggestion(
                    taskId: taskId,
                    taskTitle: matchingTask.title,
                    improvementType: selectedImprovementType,
                    suggestions: suggestionsList,
                    reasoning: reasoning
                )
                suggestions.append(suggestion)
            }
        }
        
        return suggestions
    }
}

struct ImprovementTypeCard: View {
    let type: TaskImprovementSuggestionView.ImprovementType
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(type.color.opacity(isSelected ? 0.2 : 0.1))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: type.icon)
                        .font(.title3)
                        .foregroundColor(type.color)
                }
                
                VStack(spacing: 2) {
                    Text(type.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(type.description)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? type.color.opacity(0.1) : Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? type.color : Color.clear, lineWidth: 2)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct TaskSelectionRow: View {
    let task: ShigodekiTask
    let isSelected: Bool
    let onToggle: (Bool) -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: {
                onToggle(!isSelected)
            }) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(isSelected ? .blue : .gray)
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                if let description = task.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                HStack {
                    Circle()
                        .fill(task.priority.swiftUIColor)
                        .frame(width: 8, height: 8)
                    
                    Text(task.priority.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let dueDate = task.dueDate {
                        Text("•")
                            .foregroundColor(.secondary)
                        
                        Text(DateFormatter.taskDueDate.string(from: dueDate))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct SuggestionCard: View {
    let suggestion: TaskImprovementSuggestionView.TaskSuggestion
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(suggestion.taskTitle)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(suggestion.improvementType.title)
                        .font(.caption)
                        .foregroundColor(suggestion.improvementType.color)
                }
                
                Spacer()
                
                Image(systemName: suggestion.improvementType.icon)
                    .font(.title3)
                    .foregroundColor(suggestion.improvementType.color)
            }
            
            // Suggestions
            VStack(alignment: .leading, spacing: 6) {
                Text("改善提案:")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                ForEach(Array(suggestion.suggestions.enumerated()), id: \.offset) { index, suggestionText in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(index + 1).")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text(suggestionText)
                            .font(.subheadline)
                    }
                }
            }
            
            // Reasoning
            if !suggestion.reasoning.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("理由:")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text(suggestion.reasoning)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    TaskImprovementSuggestionView(taskManager: TaskManager(), aiGenerator: AITaskGenerator())
}