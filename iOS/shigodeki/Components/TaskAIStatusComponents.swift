//
//  TaskAIStatusComponents.swift
//  shigodeki
//
//  Created by Claude on 2025-01-04.
//

import SwiftUI

// MARK: - AI Task Data
typealias AITaskData = AITaskSuggestion.TaskSuggestion

// MARK: - Status & Result Components

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
            AIResultsHeader(taskCount: suggestions.tasks.count)
            
            AITaskPreviewList(tasks: suggestions.tasks)
            
            AIResultsActionButtons(
                onAccept: onAccept,
                onDismiss: onDismiss
            )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .stroke(Color.blue, lineWidth: 1)
        )
    }
}

// MARK: - Supporting Components

struct AIResultsHeader: View {
    let taskCount: Int
    
    var body: some View {
        HStack {
            Image(systemName: "sparkles")
                .foregroundColor(.blue)
            
            Text("AI提案結果")
                .font(.headline)
            
            Spacer()
        }
    }
}

struct AITaskPreviewList: View {
    let tasks: [AITaskData]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("\(tasks.count)個のタスクが生成されました")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            LazyVStack(alignment: .leading, spacing: 8) {
                ForEach(Array(tasks.prefix(3))) { task in
                    AITaskPreviewRow(task: task)
                }
                
                if tasks.count > 3 {
                    Text("他に\(tasks.count - 3)個のタスク")
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
        }
    }
}

struct AITaskPreviewRow: View {
    let task: AITaskData
    
    var body: some View {
        HStack {
            Circle()
                .fill(priorityColor(task.priority))
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                
                if let rationale = task.rationale, rationale.isEmpty == false {
                    Text(rationale)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                } else if let description = task.description, description.isEmpty == false {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                if let dueLabel = formattedDue(task.due) {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                        Text(dueLabel)
                    }
                    .font(.caption2)
                    .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    private func priorityColor(_ priority: AITaskPriority?) -> Color {
        guard let priority else { return .gray }
        switch priority {
        case .low: return .green
        case .normal, .medium: return .yellow
        case .high, .urgent: return .red
        }
    }

    private func formattedDue(_ raw: String?) -> String? {
        guard let raw = raw, raw.isEmpty == false else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: raw) {
            formatter.dateFormat = "yyyy年M月d日"
            return formatter.string(from: date)
        }
        return raw
    }
}

struct AIResultsActionButtons: View {
    let onAccept: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
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
}

struct TaskPickerView: View {
    let tasks: [ShigodekiTask]
    @Binding var selectedTask: ShigodekiTask?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(tasks, id: \.id) { task in
                    TaskPickerRow(
                        task: task,
                        isSelected: selectedTask?.id == task.id
                    ) {
                        selectedTask = task
                        dismiss()
                    }
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

struct TaskPickerRow: View {
    let task: ShigodekiTask
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
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
                    
                    TaskPickerRowInfo(task: task)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .interactiveEffect()
    }
}

struct TaskPickerRowInfo: View {
    let task: ShigodekiTask
    
    var body: some View {
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
}
