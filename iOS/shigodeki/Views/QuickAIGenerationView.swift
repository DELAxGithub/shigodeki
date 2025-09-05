import SwiftUI

struct QuickAIGenerationView: View {
    let family: Family
    let taskManager: TaskManager
    @ObservedObject var aiGenerator: AITaskGenerator
    
    @Environment(\.dismiss) private var dismiss
    @State private var naturalLanguageInput = ""
    @State private var selectedTaskList: TaskList?
    @State private var createNewTaskList = false
    @State private var newTaskListName = ""
    @State private var showTaskListPicker = false
    @State private var selectedGenerationType: GenerationType = .quickTasks
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    QuickAIHeaderSection()
                    
                    GenerationTypeSelector(
                        selectedType: $selectedGenerationType,
                        naturalLanguageInput: $naturalLanguageInput
                    )
                    
                    QuickAIInputSection(
                        naturalLanguageInput: $naturalLanguageInput,
                        selectedGenerationType: selectedGenerationType
                    )
                    
                    TaskListSelectionSection(
                        taskManager: taskManager,
                        createNewTaskList: $createNewTaskList,
                        selectedTaskList: $selectedTaskList,
                        newTaskListName: $newTaskListName,
                        showTaskListPicker: $showTaskListPicker
                    )
                    
                    GenerateButtonSection(
                        isDisabled: isGenerateButtonDisabled,
                        disabledReason: generateButtonDisabledReason,
                        action: generateTasks
                    )
                    
                    QuickAIStatusSection(
                        aiGenerator: aiGenerator,
                        selectedTaskList: selectedTaskList,
                        newTaskListName: newTaskListName,
                        createNewTaskList: createNewTaskList,
                        onAccept: handleTaskGeneration
                    )
                }
                .padding()
            }
            .navigationTitle("クイック AI 生成")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                
                if !aiGenerator.availableProviders.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Picker("AI Provider", selection: $aiGenerator.selectedProvider) {
                                ForEach(aiGenerator.availableProviders, id: \.self) { provider in
                                    HStack {
                                        Text(provider.displayName)
                                        Image(systemName: "checkmark")
                                            .opacity(aiGenerator.selectedProvider == provider ? 1 : 0)
                                    }
                                    .tag(provider)
                                }
                            }
                        } label: {
                            Image(systemName: "gear")
                        }
                    }
                }
            }
            .sheet(isPresented: $showTaskListPicker) {
                TaskListPickerView(
                    taskLists: taskManager.taskLists,
                    selectedTaskList: $selectedTaskList
                )
            }
        }
        .onAppear {
            aiGenerator.updateAvailableProviders()
        }
    }
    
    // MARK: - Computed Properties
    
    private var isGenerateButtonDisabled: Bool {
        let inputEmpty = naturalLanguageInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let noProviders = aiGenerator.availableProviders.isEmpty
        let isGenerating = aiGenerator.isGenerating
        
        if createNewTaskList {
            let nameEmpty = newTaskListName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            return inputEmpty || nameEmpty || noProviders || isGenerating
        } else {
            let noTaskListSelected = selectedTaskList == nil && !taskManager.taskLists.isEmpty
            return inputEmpty || noTaskListSelected || noProviders || isGenerating
        }
    }
    
    private var generateButtonDisabledReason: String {
        if aiGenerator.availableProviders.isEmpty {
            return "AI機能を使用するにはAPIキーの設定が必要です"
        }
        if naturalLanguageInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "やりたいことを入力してください"
        }
        if createNewTaskList && newTaskListName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "新しいタスクリスト名を入力してください"
        }
        if !createNewTaskList && selectedTaskList == nil && !taskManager.taskLists.isEmpty {
            return "タスクリストを選択してください"
        }
        return ""
    }
    
    // MARK: - Actions
    
    private func generateTasks() {
        let prompt = QuickAIPromptBuilder.buildPrompt(
            for: selectedGenerationType,
            input: naturalLanguageInput
        )
        
        Task {
            await aiGenerator.generateTaskSuggestions(
                for: prompt,
                projectType: QuickAIPromptBuilder.mapGenerationTypeToProjectType(selectedGenerationType)
            )
        }
    }
    
    private func handleTaskGeneration(taskList: TaskList, tasks: [ShigodekiTask]) {
        // Here you would implement the actual task creation logic
        // This is a simplified implementation
        print("Generated \(tasks.count) tasks for task list: \(taskList.name)")
        
        // In a real implementation, you would:
        // 1. Create the task list if it's new
        // 2. Add all the generated tasks to Firestore
        // 3. Update the local task manager
        
        aiGenerator.clearSuggestions()
        dismiss()
    }
}

#Preview {
    QuickAIGenerationView(
        family: Family(name: "テスト家族", members: ["user1"]),
        taskManager: TaskManager(),
        aiGenerator: AITaskGenerator()
    )
}