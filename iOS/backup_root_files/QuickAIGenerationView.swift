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
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection
                    
                    // Generation Type Selection
                    generationTypeSelector
                    
                    // Input Section
                    inputSection
                    
                    // Task List Selection
                    taskListSelectionSection
                    
                    // Generate Button
                    generateButtonSection
                    
                    // AI Status and Results
                    aiStatusSection
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
    
    // MARK: - View Components
    
    private var headerSection: some View {
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
    
    private var generationTypeSelector: some View {
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
                        isSelected: selectedGenerationType == type
                    ) {
                        selectedGenerationType = type
                        // Clear input when type changes
                        naturalLanguageInput = ""
                    }
                }
            }
            
            Text(selectedGenerationType.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 4)
        }
    }
    
    private var inputSection: some View {
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
    
    private var taskListSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("タスクの追加先")
                .font(.headline)
            
            VStack(spacing: 8) {
                // Existing task list option
                Button {
                    createNewTaskList = false
                    if taskManager.taskLists.isEmpty {
                        // If no task lists exist, show picker anyway for consistency
                        showTaskListPicker = true
                    } else {
                        showTaskListPicker = true
                    }
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
    
    private var generateButtonSection: some View {
        VStack(spacing: 12) {
            Button("タスクを生成") {
                generateTasks()
            }
            .buttonStyle(.borderedProminent)
            .disabled(isGenerateButtonDisabled)
            .frame(maxWidth: .infinity)
            
            if isGenerateButtonDisabled {
                Text(generateButtonDisabledReason)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    private var aiStatusSection: some View {
        VStack(spacing: 16) {
            // AI Generation Status
            if aiGenerator.isGenerating {
                AIGeneratingStatusView(
                    progressMessage: aiGenerator.progressMessage
                )
            }
            
            // AI Error
            if let error = aiGenerator.error {
                AIErrorView(error: error) {
                    aiGenerator.error = nil
                }
            }
            
            // AI Results
            if let suggestions = aiGenerator.generatedSuggestions {
                QuickAIResultsView(
                    suggestions: suggestions,
                    selectedTaskList: selectedTaskList,
                    newTaskListName: newTaskListName,
                    createNewTaskList: createNewTaskList,
                    onAccept: { taskList, tasks in
                        handleTaskGeneration(taskList: taskList, tasks: tasks)
                    },
                    onDismiss: {
                        aiGenerator.clearSuggestions()
                    }
                )
            }
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
        let prompt = buildPromptForGenerationType()
        
        Task {
            await aiGenerator.generateTaskSuggestions(
                for: prompt,
                projectType: mapGenerationTypeToProjectType()
            )
        }
    }
    
    private func buildPromptForGenerationType() -> String {
        let baseInput = naturalLanguageInput.trimmingCharacters(in: .whitespacesAndNewlines)
        
        switch selectedGenerationType {
        case .quickTasks:
            return """
            以下の要求を実行可能なタスクリストに変換してください：
            
            \(baseInput)
            
            シンプルで実行しやすいタスクを5-8個程度生成してください。
            """
            
        case .structuredProject:
            return """
            以下のプロジェクトを段階的な計画に分解してください：
            
            \(baseInput)
            
            プロジェクトの成功に必要な主要なフェーズとタスクを含めてください。
            各タスクは具体的で測定可能にしてください。
            """
            
        case .dailyPlanning:
            return """
            以下の状況に基づいて今日または明日の行動計画を立ててください：
            
            \(baseInput)
            
            時間管理を考慮し、優先度の高いタスクから順番に配置してください。
            現実的で実行可能な計画にしてください。
            """
            
        case .brainstorm:
            return """
            以下のアイデアやテーマを具体的なアクションプランに展開してください：
            
            \(baseInput)
            
            アイデアを実現するための段階的なステップと、
            各ステップで必要な具体的なタスクを生成してください。
            """
        }
    }
    
    private func mapGenerationTypeToProjectType() -> ProjectType {
        switch selectedGenerationType {
        case .quickTasks: return .personal
        case .structuredProject: return .work
        case .dailyPlanning: return .personal
        case .brainstorm: return .creative
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

// MARK: - Supporting Views

struct GenerationTypeCard: View {
    let type: QuickAIGenerationView.GenerationType
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
    }
}

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

#Preview {
    QuickAIGenerationView(
        family: Family(name: "テスト家族", members: ["user1"]),
        taskManager: TaskManager(),
        aiGenerator: AITaskGenerator()
    )
}