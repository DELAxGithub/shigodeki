import SwiftUI

// MARK: - Generation Type

enum GenerationType: String, CaseIterable, Identifiable {
    case quickTasks = "quick"
    case structuredProject = "structured" 
    case dailyPlanning = "daily"
    case brainstorm = "brainstorm"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .quickTasks: return "クイックタスク"
        case .structuredProject: return "プロジェクト計画"
        case .dailyPlanning: return "日次プランニング"
        case .brainstorm: return "アイデア展開"
        }
    }
    
    var icon: String {
        switch self {
        case .quickTasks: return "bolt.fill"
        case .structuredProject: return "building.2.fill"
        case .dailyPlanning: return "calendar"
        case .brainstorm: return "lightbulb.fill"
        }
    }
    
    var description: String {
        switch self {
        case .quickTasks: return "簡単なタスクを素早く生成"
        case .structuredProject: return "段階的なプロジェクト計画を作成"
        case .dailyPlanning: return "今日やることリストを整理"
        case .brainstorm: return "アイデアを具体的なタスクに展開"
        }
    }
    
    var placeholderText: String {
        switch self {
        case .quickTasks: 
            return "例: 「家の掃除をしたい」「新しいWebサイトを作る」「英語の勉強を始める」"
        case .structuredProject: 
            return "例: 「新商品の開発」「引っ越しの準備」「結婚式の企画」"
        case .dailyPlanning: 
            return "例: 「明日は会議が多い日」「週末の家族時間を充実させたい」"
        case .brainstorm: 
            return "例: 「副業のアイデア」「健康的な生活」「スキルアップ」"
        }
    }
}

// MARK: - Generation Type Card

struct GenerationTypeCard: View {
    let type: GenerationType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: type.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : .blue)
                
                Text(type.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(height: 70)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.blue : Color(.systemGray6))
            )
        }
        .buttonStyle(.plain)
        .interactiveEffect()
    }
}

// MARK: - Task List Picker

struct TaskListPickerView: View {
    let taskLists: [TaskList]
    @Binding var selectedTaskList: TaskList?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                if taskLists.isEmpty {
                    ContentUnavailableView(
                        "タスクリストがありません",
                        systemImage: "list.bullet.rectangle",
                        description: Text("まずタスクリストを作成してください")
                    )
                } else {
                    ForEach(taskLists, id: \.id) { taskList in
                        Button {
                            selectedTaskList = taskList
                            dismiss()
                        } label: {
                            HStack {
                                Circle()
                                    .fill(taskList.color.swiftUIColor)
                                    .frame(width: 16, height: 16)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(taskList.name)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                }
                                
                                Spacer()
                                
                                if selectedTaskList?.id == taskList.id {
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
            }
            .navigationTitle("タスクリストを選択")
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

// MARK: - Quick AI Results View

struct QuickAIResultsView: View {
    let suggestions: AITaskSuggestion
    let selectedTaskList: TaskList?
    let newTaskListName: String
    let createNewTaskList: Bool
    let onAccept: (TaskList, [ShigodekiTask]) -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                
                Text("生成完了")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
            }
            
            // Summary
            VStack(alignment: .leading, spacing: 8) {
                Text("\(suggestions.tasks.count)個のタスクが生成されました")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if createNewTaskList {
                    Text("新しいタスクリスト「\(newTaskListName)」に追加されます")
                        .font(.caption)
                        .foregroundColor(.blue)
                } else if let taskList = selectedTaskList {
                    Text("「\(taskList.name)」に追加されます")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            
            // Task Preview
            LazyVStack(alignment: .leading, spacing: 8) {
                Text("生成されたタスク:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                ForEach(suggestions.tasks.prefix(5), id: \.title) { task in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(priorityColor(task.priority))
                            .frame(width: 6, height: 6)
                        
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
                        
                        Text(task.priority.displayName)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(priorityColor(task.priority).opacity(0.2))
                            )
                            .foregroundColor(priorityColor(task.priority))
                    }
                    .padding(.vertical, 2)
                }
                
                if suggestions.tasks.count > 5 {
                    Text("他に\(suggestions.tasks.count - 5)個のタスク...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 14)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray6))
            )
            
            // Action Buttons
            HStack {
                Button("再生成") {
                    onDismiss()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("タスクを追加") {
                    let taskList: TaskList
                    if createNewTaskList {
                        // Create a temporary TaskList object
                        taskList = TaskList(
                            name: newTaskListName,
                            familyId: "",
                            createdBy: ""
                        )
                    } else {
                        taskList = selectedTaskList!
                    }
                    
                    let tasks = suggestions.tasks.map { taskSuggestion in
                        ShigodekiTask(
                            title: taskSuggestion.title,
                            description: taskSuggestion.description,
                            assignedTo: nil,
                            createdBy: "ai-generated",
                            dueDate: nil,
                            priority: mapAIPriority(taskSuggestion.priority),
                            listId: taskList.id ?? "",
                            phaseId: "default-phase",
                            projectId: "default-project",
                            order: 0
                        )
                    }
                    
                    onAccept(taskList, tasks)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
        )
    }
    
    private func priorityColor(_ priority: AITaskPriority) -> Color {
        switch priority {
        case .low: return .green
        case .medium: return .yellow
        case .high, .urgent: return .red
        }
    }
    
    private func mapAIPriority(_ aiPriority: AITaskPriority) -> TaskPriority {
        switch aiPriority {
        case .low: return .low
        case .medium: return .medium
        case .high, .urgent: return .high
        }
    }
}
