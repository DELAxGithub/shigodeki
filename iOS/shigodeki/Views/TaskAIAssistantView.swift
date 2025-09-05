import SwiftUI

struct TaskAIAssistantView: View {
    let taskList: TaskList
    let existingTasks: [ShigodekiTask]
    @ObservedObject var aiGenerator: AITaskGenerator
    let onTasksGenerated: ([ShigodekiTask]) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedAssistantMode: AssistantMode = .subtasks
    @State private var selectedTask: ShigodekiTask?
    @State private var customPrompt = ""
    @State private var showTaskPicker = false
    
    enum AssistantMode: String, CaseIterable, Identifiable {
        case subtasks = "subtasks"
        case improvements = "improvements"
        case related = "related"
        case custom = "custom"
        
        var id: String { rawValue }
        
        var displayName: String {
            switch self {
            case .subtasks: return "サブタスク生成"
            case .improvements: return "改善提案"
            case .related: return "関連タスク"
            case .custom: return "カスタム提案"
            }
        }
        
        var icon: String {
            switch self {
            case .subtasks: return "list.bullet.indent"
            case .improvements: return "wand.and.stars"
            case .related: return "link"
            case .custom: return "text.bubble"
            }
        }
        
        var description: String {
            switch self {
            case .subtasks: return "選択したタスクを細分化したサブタスクを生成"
            case .improvements: return "既存タスクの効率化や改善案を提案"
            case .related: return "プロジェクトに関連する新しいタスクを提案"
            case .custom: return "自由なプロンプトでタスクを生成"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "brain")
                        .font(.system(size: 40))
                        .foregroundColor(.blue)
                    
                    VStack(spacing: 8) {
                        Text("AI タスクアシスタント")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("「\(taskList.name)」の改善を支援します")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                
                // Main content
                ScrollView {
                    LazyVStack(spacing: 16) {
                        // Assistant mode selection
                        AssistantModeSelector(
                            selectedMode: $selectedAssistantMode,
                            modes: AssistantMode.allCases
                        )
                        
                        // Mode-specific content
                        switch selectedAssistantMode {
                        case .subtasks:
                            SubtaskGenerationView(
                                selectedTask: $selectedTask,
                                showTaskPicker: $showTaskPicker,
                                existingTasks: existingTasks,
                                aiGenerator: aiGenerator,
                                onGenerate: generateSubtasks
                            )
                            
                        case .improvements:
                            ImprovementSuggestionView(
                                selectedTask: $selectedTask,
                                showTaskPicker: $showTaskPicker,
                                existingTasks: existingTasks,
                                aiGenerator: aiGenerator,
                                onGenerate: generateImprovements
                            )
                            
                        case .related:
                            RelatedTasksView(
                                taskList: taskList,
                                existingTasks: existingTasks,
                                aiGenerator: aiGenerator,
                                onGenerate: generateRelatedTasks
                            )
                            
                        case .custom:
                            CustomPromptView(
                                prompt: $customPrompt,
                                taskList: taskList,
                                aiGenerator: aiGenerator,
                                onGenerate: generateCustomTasks
                            )
                        }
                        
                        // AI Status and Results
                        if aiGenerator.isGenerating {
                            AIGeneratingStatusView(
                                progressMessage: aiGenerator.progressMessage
                            )
                        }
                        
                        if let error = aiGenerator.error {
                            AIErrorView(error: error) {
                                aiGenerator.error = nil
                            }
                        }
                        
                        if let suggestions = aiGenerator.generatedSuggestions {
                            AIResultsView(
                                suggestions: suggestions,
                                onAccept: {
                                    handleGeneratedSuggestions(suggestions)
                                },
                                onDismiss: {
                                    aiGenerator.clearSuggestions()
                                }
                            )
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("AI アシスタント")
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
            .sheet(isPresented: $showTaskPicker) {
                TaskPickerView(
                    tasks: existingTasks,
                    selectedTask: $selectedTask
                )
            }
        }
    }
    
    // MARK: - Generation Functions
    
    private func generateSubtasks() {
        guard let task = selectedTask else { return }
        
        let prompt = """
        以下のタスクをより詳細なサブタスクに分解してください：
        
        タスク: \(task.title)
        説明: \(task.description ?? "なし")
        優先度: \(task.priority.displayName)
        
        このタスクを完了するために必要な具体的なステップを、実行可能なサブタスクとして生成してください。
        """
        
        Task {
            await aiGenerator.generateTaskSuggestions(for: prompt, projectType: .custom)
        }
    }
    
    private func generateImprovements() {
        guard let task = selectedTask else { return }
        
        let prompt = """
        以下のタスクの効率化や改善案を提案してください：
        
        タスク: \(task.title)
        説明: \(task.description ?? "なし")
        
        このタスクをより効率的に、または効果的に実行するための具体的な改善案や代替案を提案してください。
        """
        
        Task {
            await aiGenerator.generateTaskSuggestions(for: prompt, projectType: .custom)
        }
    }
    
    private func generateRelatedTasks() {
        let completedTasks = existingTasks.filter { $0.isCompleted }.map { $0.title }
        let pendingTasks = existingTasks.filter { !$0.isCompleted }.map { $0.title }
        
        let prompt = """
        タスクリスト「\(taskList.name)」に関連する新しいタスクを提案してください。
        
        既存の完了済みタスク:
        \(completedTasks.isEmpty ? "なし" : completedTasks.joined(separator: ", "))
        
        未完了のタスク:
        \(pendingTasks.isEmpty ? "なし" : pendingTasks.joined(separator: ", "))
        
        このプロジェクトの継続や発展のために必要な新しいタスクを提案してください。
        """
        
        Task {
            await aiGenerator.generateTaskSuggestions(for: prompt, projectType: .custom)
        }
    }
    
    private func generateCustomTasks() {
        let enhancedPrompt = """
        タスクリスト「\(taskList.name)」のコンテキストで、以下の要求に基づいてタスクを生成してください：
        
        \(customPrompt)
        
        既存のタスクと重複せず、実行可能で具体的なタスクを生成してください。
        """
        
        Task {
            await aiGenerator.generateTaskSuggestions(for: enhancedPrompt, projectType: .custom)
        }
    }
    
    private func handleGeneratedSuggestions(_ suggestions: AITaskSuggestion) {
        // Convert AI suggestions to ShigodekiTask objects
        // This is a simplified implementation - in practice, you'd need proper task creation
        let generatedTasks: [ShigodekiTask] = suggestions.tasks.map { taskSuggestion in
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
        
        onTasksGenerated(generatedTasks)
        dismiss()
    }
    
    private func mapAIPriority(_ aiPriority: AITaskPriority) -> TaskPriority {
        switch aiPriority {
        case .low: return .low
        case .medium: return .medium
        case .high: return .high
        case .urgent: return .high
        }
    }
}

// MARK: - Supporting Views

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

struct AIErrorView: View {
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

#Preview {
    TaskAIAssistantView(
        taskList: TaskList(name: "サンプルタスクリスト", familyId: "family1", createdBy: "user1"),
        existingTasks: [],
        aiGenerator: AITaskGenerator(),
        onTasksGenerated: { _ in }
    )
}