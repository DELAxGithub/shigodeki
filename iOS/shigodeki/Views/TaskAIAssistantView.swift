import SwiftUI
import UIKit

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
        case photo = "photo"
        
        var id: String { rawValue }
        
        var displayName: String {
            switch self {
            case .subtasks: return "サブタスク生成"
            case .improvements: return "改善提案"
            case .related: return "関連タスク"
            case .custom: return "カスタム提案"
            case .photo: return "写真から提案"
            }
        }
        
        var icon: String {
            switch self {
            case .subtasks: return "list.bullet.indent"
            case .improvements: return "wand.and.stars"
            case .related: return "link"
            case .custom: return "text.bubble"
            case .photo: return "camera.viewfinder"
            }
        }
        
        var description: String {
            switch self {
            case .subtasks: return "選択したタスクを細分化したサブタスクを生成"
            case .improvements: return "既存タスクの効率化や改善案を提案"
            case .related: return "プロジェクトに関連する新しいタスクを提案"
            case .custom: return "自由なプロンプトでタスクを生成"
            case .photo: return "写真から複数のタスク候補を生成"
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
                        case .photo:
                            PhotoTaskBulkGenerationView(
                                taskList: taskList,
                                existingTasks: existingTasks,
                                onTasksReady: { tasks in
                                    onTasksGenerated(tasks)
                                    dismiss()
                                }
                            )
                        }
                        
                        // AI Status and Results
                        if aiGenerator.isGenerating {
                            AIGeneratingStatusView(
                                progressMessage: aiGenerator.progressMessage
                            )
                        }
                        
                        if let error = aiGenerator.error {
                            TaskAIAssistantErrorView(error: error) {
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


#Preview {
    TaskAIAssistantView(
        taskList: TaskList(name: "サンプルタスクリスト", familyId: "family1", createdBy: "user1"),
        existingTasks: [],
        aiGenerator: AITaskGenerator(),
        onTasksGenerated: { _ in }
    )
}

// MARK: - Photo-based bulk generation using TidyPlanKit

private struct PhotoTaskBulkGenerationView: View {
    let taskList: TaskList
    let existingTasks: [ShigodekiTask]
    let onTasksReady: ([ShigodekiTask]) -> Void

    @State private var showCamera = false
    @State private var showLibrary = false
    @State private var isGenerating = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("写真から提案")
                .font(.headline)
            Text("部屋やモノを撮影すると、処分・整理のタスクを自動提案します。")
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                Button { showCamera = true } label: {
                    Label("カメラで撮影", systemImage: "camera")
                }.buttonStyle(.bordered)
                Button { showLibrary = true } label: {
                    Label("写真を選択", systemImage: "photo.on.rectangle")
                }.buttonStyle(.bordered)
            }

            if isGenerating {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("写真を解析して提案を生成中…")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundColor(.red)
            }
        }
        .sheet(isPresented: $showCamera) {
            CameraPicker(source: .camera) { image in
                process(image: image)
            }
        }
        .sheet(isPresented: $showLibrary) {
            CameraPicker(source: .photoLibrary) { image in
                process(image: image)
            }
        }
    }

    private func process(image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.7) else { return }
        generate(from: data)
    }

    private func generate(from imageData: Data) {
        isGenerating = true
        errorMessage = nil
        Task {
            defer { isGenerating = false }
            let apiKey = KeychainManager.shared.getAPIKeyIfAvailable(for: .openAI)
            let allowNetwork = (apiKey?.isEmpty == false)
            let planner = TidyPlanner(apiKey: apiKey)
            let locale = UserLocale(
                country: Locale.current.regionCode ?? "JP",
                city: (Locale.current.regionCode ?? "JP") == "JP" ? "Tokyo" : "Toronto"
            )
            let existing = existingTasks.prefix(6).map { "・\($0.title)" }.joined(separator: "\n")
            let ctx = "タスクリスト: \(taskList.name)\n既存のタスク（抜粋）:\n\(existing)"
            let plan = await planner.generate(from: imageData, locale: locale, allowNetwork: allowNetwork, context: ctx)
            if plan.project == "Fallback Moving Plan" {
                await MainActor.run { errorMessage = "OpenAI未使用: フォールバック結果（キー未設定・通信/JSONエラー）" }
            }
            let tasks: [ShigodekiTask] = plan.tasks.enumerated().map { idx, t in
                let desc: String? = {
                    let checklist = (t.checklist ?? []).map { "• \($0)" }.joined(separator: "\n")
                    return checklist.isEmpty ? nil : checklist
                }()
                return ShigodekiTask(
                    title: t.title,
                    description: desc,
                    assignedTo: nil,
                    createdBy: "ai-generated",
                    dueDate: nil,
                    priority: .medium,
                    listId: taskList.id ?? "",
                    phaseId: "default-phase",
                    projectId: "default-project",
                    order: idx
                )
            }
            await MainActor.run { onTasksReady(tasks) }
        }
    }
}
