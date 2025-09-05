//
//  TaskAIAssistantComponents.swift
//  shigodeki
//
//  Created by Claude on 2025-09-05.
//

import SwiftUI

struct AssistantModeSelector: View {
    @Binding var selectedMode: TaskAIAssistantView.AssistantMode
    let modes: [TaskAIAssistantView.AssistantMode]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("支援モード")
                .font(.headline)
                .padding(.horizontal)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(modes) { mode in
                    AssistantModeCard(
                        mode: mode,
                        isSelected: selectedMode == mode
                    ) {
                        selectedMode = mode
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

struct AssistantModeCard: View {
    let mode: TaskAIAssistantView.AssistantMode
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: mode.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : .blue)
                
                Text(mode.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
                    .multilineTextAlignment(.center)
            }
            .frame(height: 80)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue : Color(.systemGray6))
            )
        }
        .buttonStyle(.plain)
    }
}

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
            
            Button {
                showTaskPicker = true
            } label: {
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
                        Text("タスクを選択してください")
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
            
            Button {
                showTaskPicker = true
            } label: {
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
                        Text("改善したいタスクを選択してください")
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

struct AIGeneratingStatusView: View {
    let progressMessage: String
    
    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.8)
            
            Text(progressMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
}

struct TaskAIAssistantErrorView: View {
    let error: AIClientError
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                
                Text("生成エラー")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            Text(error.localizedDescription)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button("閉じる") {
                onDismiss()
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .stroke(Color.orange, lineWidth: 1)
        )
    }
}

struct AIResultsView: View {
    let suggestions: AITaskSuggestion
    let onAccept: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.blue)
                
                Text("AI提案結果")
                    .font(.headline)
                
                Spacer()
            }
            
            Text("\(suggestions.tasks.count)個のタスクが生成されました")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Preview of generated tasks
            LazyVStack(alignment: .leading, spacing: 8) {
                ForEach(suggestions.tasks.prefix(3), id: \.title) { task in
                    HStack {
                        Circle()
                            .fill(priorityColor(task.priority))
                            .frame(width: 8, height: 8)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(task.title)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .lineLimit(2)
                            
                            if !task.description.isEmpty {
                                Text(task.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
                
                if suggestions.tasks.count > 3 {
                    Text("他に\(suggestions.tasks.count - 3)個のタスク")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 16)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray6))
            )
            
            HStack {
                Button("キャンセル") {
                    onDismiss()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("タスクを追加") {
                    onAccept()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .stroke(Color.blue, lineWidth: 1)
        )
    }
    
    private func priorityColor(_ priority: AITaskPriority) -> Color {
        switch priority {
        case .low: return .green
        case .medium: return .yellow
        case .high, .urgent: return .red
        }
    }
}

struct TaskPickerView: View {
    let tasks: [ShigodekiTask]
    @Binding var selectedTask: ShigodekiTask?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(tasks, id: \.id) { task in
                    Button {
                        selectedTask = task
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(task.title)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                if let description = task.description, !description.isEmpty {
                                    Text(description)
                                        .font(.subheadline)
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
                                    
                                    if task.isCompleted {
                                        Text("完了済み")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                    }
                                }
                            }
                            
                            Spacer()
                            
                            if selectedTask?.id == task.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("タスクを選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
            }
        }
    }
}