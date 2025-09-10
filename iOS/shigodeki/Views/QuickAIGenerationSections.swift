import SwiftUI

// MARK: - Header Section

struct QuickAIHeaderSection: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "brain")
                .font(.system(size: 40))
                .foregroundColor(.blue)
            
            VStack(spacing: 8) {
                Text("AI クイック生成")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("自然言語でやりたいことを説明すると、AIが具体的なタスクに変換します")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Generation Type Selector

struct GenerationTypeSelector: View {
    @Binding var selectedType: GenerationType
    @Binding var naturalLanguageInput: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("生成タイプ")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(GenerationType.allCases) { type in
                    GenerationTypeCard(
                        type: type,
                        isSelected: selectedType == type
                    ) {
                        selectedType = type
                        naturalLanguageInput = ""
                    }
                }
            }
            
            Text(selectedType.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 4)
        }
    }
}

// MARK: - Input Section

struct QuickAIInputSection: View {
    @Binding var naturalLanguageInput: String
    let selectedGenerationType: GenerationType
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("やりたいことを説明してください")
                .font(.headline)
            
            ZStack(alignment: .topLeading) {
                if naturalLanguageInput.isEmpty {
                    VStack {
                        HStack {
                            Text(selectedGenerationType.placeholderText)
                                .foregroundColor(Color(.placeholderText))
                                .padding(.top, 8)
                                .padding(.leading, 4)
                            Spacer()
                        }
                        Spacer()
                    }
                }
                
                TextEditor(text: $naturalLanguageInput)
                    .frame(minHeight: 120)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray6))
            )
            
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.blue)
                    .font(.caption)
                
                Text("詳しく説明するほど、より適切なタスクが生成されます")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Task List Selection Section

struct TaskListSelectionSection: View {
    let taskManager: TaskManager
    @Binding var createNewTaskList: Bool
    @Binding var selectedTaskList: TaskList?
    @Binding var newTaskListName: String
    @Binding var showTaskListPicker: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("タスクの追加先")
                .font(.headline)
            
            VStack(spacing: 8) {
                // Existing task list option
                Button {
                    createNewTaskList = false
                    showTaskListPicker = true
                } label: {
                    HStack {
                        Image(systemName: createNewTaskList ? "circle" : "checkmark.circle.fill")
                            .foregroundColor(createNewTaskList ? .secondary : .blue)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("既存のタスクリストに追加")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            if let selectedTaskList = selectedTaskList {
                                Text(selectedTaskList.name)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                Text(taskManager.taskLists.isEmpty ? "タスクリストが見つかりません" : "タスクリストを選択してください")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .interactiveEffect()
                .disabled(taskManager.taskLists.isEmpty)
                
                // New task list option
                Button {
                    createNewTaskList = true
                    selectedTaskList = nil
                } label: {
                    HStack {
                        Image(systemName: createNewTaskList ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(createNewTaskList ? .blue : .secondary)
                        
                        Text("新しいタスクリストを作成")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .interactiveEffect()
                
                // New task list name input
                if createNewTaskList {
                    TextField("タスクリスト名", text: $newTaskListName)
                        .textFieldStyle(.roundedBorder)
                        .padding(.leading, 28)
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

// MARK: - Generate Button Section

struct GenerateButtonSection: View {
    let isDisabled: Bool
    let disabledReason: String
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Button("タスクを生成") {
                action()
            }
            .buttonStyle(.borderedProminent)
            .disabled(isDisabled)
            .frame(maxWidth: .infinity)
            
            if isDisabled {
                Text(disabledReason)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

// MARK: - AI Status Section

struct QuickAIStatusSection: View {
    @ObservedObject var aiGenerator: AITaskGenerator
    let selectedTaskList: TaskList?
    let newTaskListName: String
    let createNewTaskList: Bool
    let onAccept: (TaskList, [ShigodekiTask]) -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // AI Generation Status
            if aiGenerator.isGenerating {
                AIGeneratingStatusView(
                    progressMessage: aiGenerator.progressMessage
                )
            }
            
            // AI Error
            if let error = aiGenerator.error {
                AIErrorView(
                    message: error.localizedDescription,
                    onRetry: {
                        aiGenerator.error = nil
                    },
                    onOpenSettings: {
                        // TODO: Navigate to settings
                    }
                )
            }
            
            // AI Results
            if let suggestions = aiGenerator.generatedSuggestions {
                QuickAIResultsView(
                    suggestions: suggestions,
                    selectedTaskList: selectedTaskList,
                    newTaskListName: newTaskListName,
                    createNewTaskList: createNewTaskList,
                    onAccept: onAccept,
                    onDismiss: {
                        aiGenerator.clearSuggestions()
                    }
                )
            }
        }
    }
}
