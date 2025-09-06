//
//  TaskAIGenerationViews.swift
//  shigodeki
//
//  Created by Claude on 2025-01-04.
//

import SwiftUI

// MARK: - Task Generation Views

struct SubtaskGenerationView: View {
    @Binding var selectedTask: ShigodekiTask?
    @Binding var showTaskPicker: Bool
    let existingTasks: [ShigodekiTask]
    @ObservedObject var aiGenerator: AITaskGenerator
    let onGenerate: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("サブタスク生成")
                .font(.headline)
            
            Text("既存のタスクを選択して、より詳細なサブタスクに分解します。")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            TaskSelectionButton(
                selectedTask: selectedTask,
                placeholder: "タスクを選択してください",
                onTap: { showTaskPicker = true }
            )
            
            Button("サブタスクを生成") {
                onGenerate()
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedTask == nil || aiGenerator.isGenerating)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(radius: 2)
        )
    }
}

struct ImprovementSuggestionView: View {
    @Binding var selectedTask: ShigodekiTask?
    @Binding var showTaskPicker: Bool
    let existingTasks: [ShigodekiTask]
    @ObservedObject var aiGenerator: AITaskGenerator
    let onGenerate: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("改善提案")
                .font(.headline)
            
            Text("既存のタスクを選択して、効率化や改善案を提案してもらいます。")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            TaskSelectionButton(
                selectedTask: selectedTask,
                placeholder: "改善したいタスクを選択してください",
                onTap: { showTaskPicker = true }
            )
            
            Button("改善提案を生成") {
                onGenerate()
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedTask == nil || aiGenerator.isGenerating)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(radius: 2)
        )
    }
}

struct RelatedTasksView: View {
    let taskList: TaskList
    let existingTasks: [ShigodekiTask]
    @ObservedObject var aiGenerator: AITaskGenerator
    let onGenerate: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("関連タスク")
                .font(.headline)
            
            Text("現在のタスクリストの内容を分析し、プロジェクトに関連する新しいタスクを提案します。")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            TaskListInfoView(
                taskList: taskList,
                existingTasks: existingTasks
            )
            
            Button("関連タスクを生成") {
                onGenerate()
            }
            .buttonStyle(.borderedProminent)
            .disabled(aiGenerator.isGenerating)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(radius: 2)
        )
    }
}

struct CustomPromptView: View {
    @Binding var prompt: String
    let taskList: TaskList
    @ObservedObject var aiGenerator: AITaskGenerator
    let onGenerate: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("カスタム提案")
                .font(.headline)
            
            Text("自由なプロンプトでタスクを生成できます。具体的な要求を入力してください。")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            CustomPromptTextEditor(prompt: $prompt)
            
            Button("カスタムタスクを生成") {
                onGenerate()
            }
            .buttonStyle(.borderedProminent)
            .disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || aiGenerator.isGenerating)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(radius: 2)
        )
    }
}

// MARK: - Supporting Components

struct TaskSelectionButton: View {
    let selectedTask: ShigodekiTask?
    let placeholder: String
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                if let task = selectedTask {
                    VStack(alignment: .leading) {
                        Text(task.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        if let description = task.description {
                            Text(description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                    }
                } else {
                    Text(placeholder)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray6))
            )
        }
        .buttonStyle(.plain)
    }
}

struct TaskListInfoView: View {
    let taskList: TaskList
    let existingTasks: [ShigodekiTask]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("タスクリスト: \(taskList.name)")
                .font(.subheadline)
                .fontWeight(.medium)
            
            Text("既存タスク: \(existingTasks.count)個")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("完了済み: \(existingTasks.filter { $0.isCompleted }.count)個")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6))
        )
    }
}

struct CustomPromptTextEditor: View {
    @Binding var prompt: String
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            if prompt.isEmpty {
                VStack {
                    HStack {
                        Text("例: 「マーケティング戦略の立案」「チームビルディング活動」「品質改善のための施策」")
                            .foregroundColor(Color(.placeholderText))
                            .padding(.top, 8)
                            .padding(.leading, 4)
                        Spacer()
                    }
                    Spacer()
                }
            }
            
            TextEditor(text: $prompt)
                .frame(minHeight: 100)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6))
        )
    }
}