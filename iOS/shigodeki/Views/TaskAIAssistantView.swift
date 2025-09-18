import SwiftUI
import UIKit
import Combine

struct TaskAIAssistantView: View {
    let taskList: TaskList
    let existingTasks: [ShigodekiTask]
    @ObservedObject var aiGenerator: AITaskGenerator
    let onTasksGenerated: ([ShigodekiTask]) -> Void
    let onPreviewDrafts: (([TaskDraft], TaskDraftSource) -> Void)?
    let project: Project?
    let phase: Phase?
    private let additionalContextHint: String?
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var toastCenter: ToastCenter
    @Environment(\.entitlementStore) private var entitlementStore
    @Environment(\.proSubscriptionCoordinator) private var proSubscriptionCoordinator
    @Environment(\.purchaseProductCatalog) private var purchaseProductCatalog
    @State private var selectedAssistantMode: AssistantMode = .subtasks
    @State private var selectedTask: ShigodekiTask?
    @State private var customPrompt = ""
    @State private var showTaskPicker = false
    @State private var usePreviewFlow: Bool
    @State private var entitlementsSnapshot = Entitlements.empty
    @State private var showProPaywall = false
    @State private var proPaywallContext: ProPaywallView.ProPaywallContext?
    @State private var pendingAIAction: PendingAIAction?
    @State private var showPhotoCamera = false
    @State private var showPhotoLibrary = false

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

    private enum PendingAIAction: Equatable {
        case subtasks(ShigodekiTask)
        case improvements(ShigodekiTask)
        case related
        case custom
        case photoCamera
        case photoLibrary

        var analyticsIdentifier: String {
            switch self {
            case .subtasks:
                return "subtasks"
            case .improvements:
                return "improvements"
            case .related:
                return "related"
            case .custom:
                return "custom"
            case .photoCamera:
                return "photo_camera"
            case .photoLibrary:
                return "photo_library"
            }
        }
    }
    
    init(
        taskList: TaskList,
        existingTasks: [ShigodekiTask],
        aiGenerator: AITaskGenerator,
        onTasksGenerated: @escaping ([ShigodekiTask]) -> Void,
        onPreviewDrafts: (([TaskDraft], TaskDraftSource) -> Void)? = nil,
        project: Project? = nil,
        phase: Phase? = nil,
        additionalContextHint: String? = nil
    ) {
        self.taskList = taskList
        self.existingTasks = existingTasks
        self._aiGenerator = ObservedObject(wrappedValue: aiGenerator)
        self.onTasksGenerated = onTasksGenerated
        self.onPreviewDrafts = onPreviewDrafts
        self.project = project
        self.phase = phase
        self.additionalContextHint = additionalContextHint
        self._usePreviewFlow = State(initialValue: FeatureFlags.unifiedPreviewEnabled && FeatureFlags.previewAIEnabled)
    }

    var body: some View {
        NavigationView {
            assistantMainContent
                .navigationTitle("AI アシスタント")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    providerPickerMenu
                }
            }
            .sheet(isPresented: $showTaskPicker) {
                TaskPickerView(
                    tasks: existingTasks,
                    selectedTask: $selectedTask
                )
            }
            .onChange(of: aiGenerator.error) { newError in
                guard let newError else { return }
                switch newError {
                case .invalidJSON, .serviceUnavailable, .rateLimitExceeded:
                    toastCenter.show("AIが混雑中のため、テンプレート候補をご利用ください")
                default:
                    break
                }
            }
            .interactiveDismissDisabled(aiGenerator.isGenerating)
        .onAppear {
            if let entitlements = entitlementStore?.entitlements {
                entitlementsSnapshot = entitlements
            }
        }
        .onReceive(entitlementStore?.$entitlements.eraseToAnyPublisher() ?? Just(Entitlements.empty).eraseToAnyPublisher()) { value in
            entitlementsSnapshot = value
            if value.isPro {
                resumePendingAction()
            }
        }
            .sheet(isPresented: $showProPaywall) {
                if #available(iOS 15.0, *),
                   let coordinator = proSubscriptionCoordinator,
                   let catalog = purchaseProductCatalog {
                    ProPaywallView(
                        coordinator: coordinator,
                        catalog: catalog,
                        context: proPaywallContext ?? ProPaywallView.ProPaywallContext(entryPoint: "task_ai", identifier: pendingAIAction?.analyticsIdentifier),
                        onUnlocked: { _ in
                            showProPaywall = false
                            proPaywallContext = nil
                            resumePendingAction()
                        },
                        onCancel: {
                            showProPaywall = false
                            proPaywallContext = nil
                            pendingAIAction = nil
                        }
                    )
                } else {
                    VStack(spacing: 16) {
                        Text("PRO購読は現在利用できません。")
                            .font(.headline)
                            .multilineTextAlignment(.center)
                        Button("閉じる") {
                            showProPaywall = false
                        }
                    }
                    .padding()
                }
            }
        }
    }

    @ViewBuilder
    private var providerPickerMenu: some View {
        if !requiresProSubscription && !aiGenerator.availableProviders.isEmpty {
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
                Image(systemName: "slider.horizontal.3")
            }
        }
    }

    // MARK: - Generation Functions

    private var assistantMainContent: some View {
        VStack(spacing: 0) {
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

            if previewToggleAvailable {
                Toggle(isOn: $usePreviewFlow) {
                    Text("プレビューで確認")
                }
                .padding()
                .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                .accessibilityIdentifier("TaskAI.PreviewToggle")
            }

            ScrollView {
                LazyVStack(spacing: 16) {
                    AssistantModeSelector(
                        selectedMode: $selectedAssistantMode,
                        modes: AssistantMode.allCases
                    )

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
                            project: project,
                            phase: phase,
                            existingTasks: existingTasks,
                            additionalContextHint: additionalContextHint,
                            usePreviewFlow: previewToggleAvailable && usePreviewFlow,
                            onPreview: { drafts in
                                guard let onPreviewDrafts else { return }
                                onPreviewDrafts(drafts, .photo)
                            },
                            onDirectSave: { tasks in
                                onTasksGenerated(tasks)
                            },
                            showCamera: $showPhotoCamera,
                            showLibrary: $showPhotoLibrary,
                            requiresProAccess: requiresProSubscription,
                            onRequireProUnlock: handlePhotoAccessRequest
                        )
                    }

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
            .sheet(isPresented: $showTaskPicker) {
                TaskPickerView(
                    tasks: existingTasks,
                    selectedTask: $selectedTask
                )
            }
            .onChange(of: aiGenerator.error) { newError in
                guard let newError else { return }
                switch newError {
                case .invalidJSON, .serviceUnavailable, .rateLimitExceeded:
                    toastCenter.show("AIが混雑中のため、テンプレート候補をご利用ください")
                default:
                    break
                }
            }
        }
    }

    private func generateSubtasks() {
        guard let task = selectedTask else { return }
        if requestProUnlock(for: .subtasks(task)) {
            performGenerateSubtasks(for: task)
        }
    }
    
    private func generateImprovements() {
        guard let task = selectedTask else { return }
        if requestProUnlock(for: .improvements(task)) {
            performGenerateImprovements(for: task)
        }
    }
    
    private func generateRelatedTasks() {
        if requestProUnlock(for: .related) {
            performGenerateRelatedTasks()
        }
    }
    
    private func generateCustomTasks() {
        if requestProUnlock(for: .custom) {
            performGenerateCustomTasks()
        }
    }

    private func performGenerateSubtasks(for task: ShigodekiTask) {
        let context = buildAIContext(notes: [
            "モード: サブタスク生成",
            "対象タスク: \(task.title)"
        ])

        let promptBody = """
        以下のタスクをより詳細なサブタスクに分解してください：
        
        タスク: \(task.title)
        説明: \(task.description ?? "なし")
        優先度: \(task.priority.displayName)
        
        このタスクを完了するために必要な具体的なステップを、実行可能なサブタスクとして生成してください。
        """

        Task {
            await aiGenerator.generateTaskSuggestions(for: context + promptBody, projectType: .custom)
        }
    }

    private func performGenerateImprovements(for task: ShigodekiTask) {
        let context = buildAIContext(notes: [
            "モード: 改善提案",
            "対象タスク: \(task.title)"
        ])

        let promptBody = """
        以下のタスクの効率化や改善案を提案してください：
        
        タスク: \(task.title)
        説明: \(task.description ?? "なし")
        
        このタスクをより効率的に、または効果的に実行するための具体的な改善案や代替案を提案してください。
        """

        Task {
            await aiGenerator.generateTaskSuggestions(for: context + promptBody, projectType: .custom)
        }
    }

    private func performGenerateRelatedTasks() {
        let completedTasks = existingTasks.filter { $0.isCompleted }.map { $0.title }
        let pendingTasks = existingTasks.filter { !$0.isCompleted }.map { $0.title }

        let context = buildAIContext(notes: ["モード: 関連タスク生成"])

        let promptBody = """
        タスクリスト「\(taskList.name)」に関連する新しいタスクを提案してください。
        
        既存の完了済みタスク:
        \(completedTasks.isEmpty ? "なし" : completedTasks.joined(separator: ", "))
        
        未完了のタスク:
        \(pendingTasks.isEmpty ? "なし" : pendingTasks.joined(separator: ", "))
        
        このプロジェクトの継続や発展のために必要な新しいタスクを提案してください。
        """

        Task {
            await aiGenerator.generateTaskSuggestions(for: context + promptBody, projectType: .custom)
        }
    }

    private func performGenerateCustomTasks() {
        let context = buildAIContext(notes: ["モード: カスタム提案"])

        let enhancedPrompt = """
        \(context)
        タスクリスト「\(taskList.name)」のコンテキストで、以下の要求に基づいてタスクを生成してください：
        
        \(customPrompt)
        
        既存のタスクと重複せず、実行可能で具体的なタスクを生成してください。
        """

        Task {
            await aiGenerator.generateTaskSuggestions(for: enhancedPrompt, projectType: .custom)
        }
    }

    private func requestProUnlock(for action: PendingAIAction) -> Bool {
        if requiresProSubscription == false {
            return true
        }

        if proAccessUnavailable {
            toastCenter.show("現在PRO購読を開始できません。時間を置いて再試行してください。")
            return false
        }

        pendingAIAction = action
        proPaywallContext = ProPaywallView.ProPaywallContext(entryPoint: "task_ai", identifier: action.analyticsIdentifier)
        showProPaywall = true
        return false
    }

    private func resumePendingAction() {
        guard let action = pendingAIAction else { return }
        pendingAIAction = nil

        switch action {
        case .subtasks(let task):
            performGenerateSubtasks(for: task)
        case .improvements(let task):
            performGenerateImprovements(for: task)
        case .related:
            performGenerateRelatedTasks()
        case .custom:
            performGenerateCustomTasks()
        case .photoCamera:
            showPhotoCamera = true
        case .photoLibrary:
            showPhotoLibrary = true
        }
    }

    private func handlePhotoAccessRequest(_ action: PhotoTaskBulkGenerationView.PhotoAction) {
        let pending: PendingAIAction = {
            switch action {
            case .camera: return .photoCamera
            case .library: return .photoLibrary
            }
        }()

        if requestProUnlock(for: pending) {
            switch action {
            case .camera:
                showPhotoCamera = true
            case .library:
                showPhotoLibrary = true
            }
        }
    }
    
    private func handleGeneratedSuggestions(_ suggestions: AITaskSuggestion) {
        if previewToggleAvailable && usePreviewFlow, let onPreviewDrafts {
            let drafts = AIDraftMapper.map(from: suggestions)
            if drafts.isEmpty == false {
                onPreviewDrafts(drafts, .ai)
            }
            aiGenerator.clearSuggestions()
            return
        }

        // Convert AI suggestions to ShigodekiTask objects
        // This is a simplified implementation - in practice, you'd need proper task creation
        let baseOrder = existingTasks.count
        let generatedTasks: [ShigodekiTask] = suggestions.tasks.enumerated().map { index, taskSuggestion in
            ShigodekiTask(
                title: taskSuggestion.title,
                description: preferredRationale(from: taskSuggestion),
                assignedTo: nil,
                createdBy: "ai-generated",
                dueDate: parseDueDate(taskSuggestion.due),
                priority: mapAIPriority(taskSuggestion.priority),
                listId: taskList.id ?? "",
                phaseId: taskList.phaseId,
                projectId: taskList.projectId,
                order: baseOrder + index
            )
        }
        
        onTasksGenerated(generatedTasks)
        aiGenerator.clearSuggestions()
    }
    
    private func mapAIPriority(_ aiPriority: AITaskPriority?) -> TaskPriority {
        guard let aiPriority else { return .medium }
        switch aiPriority {
        case .low: return .low
        case .normal, .medium: return .medium
        case .high, .urgent: return .high
        }
    }

    private var previewToggleAvailable: Bool {
        guard FeatureFlags.unifiedPreviewEnabled, onPreviewDrafts != nil else { return false }
        switch selectedAssistantMode {
        case .subtasks, .improvements, .related, .custom:
            return FeatureFlags.previewAIEnabled
        case .photo:
            return FeatureFlags.previewPhotoEnabled
        }
    }

    private func buildAIContext(notes: [String] = []) -> String {
        var combinedNotes = notes
        if let hint = additionalContextHint, hint.isEmpty == false {
            combinedNotes.append(hint)
        }

        let block = VisionPlanContextBuilder.build(
            project: project,
            phase: phase,
            taskList: taskList,
            existingTasks: existingTasks,
            additionalNotes: combinedNotes
        )
        guard block.isEmpty == false else { return "" }
        return "コンテクスト:\n\(block)\n\n"
    }

    private func preferredRationale(from suggestion: AITaskSuggestion.TaskSuggestion) -> String? {
        if let rationale = suggestion.rationale, rationale.isEmpty == false {
            return rationale
        }
        if let description = suggestion.description, description.isEmpty == false {
            return description
        }
        if let subtasks = suggestion.subtasks, subtasks.isEmpty == false {
            return subtasks.joined(separator: "\n")
        }
        return nil
    }

    private var requiresProSubscription: Bool {
        FeatureFlags.proSubscriptionEnabled && !entitlementsSnapshot.isPro
    }

    private var proAccessUnavailable: Bool {
        proSubscriptionCoordinator == nil || purchaseProductCatalog == nil || !FeatureFlags.purchasesEnabled
    }

    private func parseDueDate(_ raw: String?) -> Date? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withFullDate]
        if let date = isoFormatter.date(from: raw) {
            return date
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: raw)
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
    enum PhotoAction {
        case camera
        case library
    }

    let taskList: TaskList
    let project: Project?
    let phase: Phase?
    let existingTasks: [ShigodekiTask]
    let additionalContextHint: String?
    let usePreviewFlow: Bool
    let onPreview: ([TaskDraft]) -> Void
    let onDirectSave: ([ShigodekiTask]) -> Void
    @Binding var showCamera: Bool
    @Binding var showLibrary: Bool
    let requiresProAccess: Bool
    let onRequireProUnlock: (PhotoAction) -> Void

    @EnvironmentObject private var toastCenter: ToastCenter
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
                Button { handle(.camera) } label: {
                    Label("カメラで撮影", systemImage: "camera")
                }.buttonStyle(.bordered)
                Button { handle(.library) } label: {
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

    private func handle(_ action: PhotoAction) {
        if requiresProAccess {
            onRequireProUnlock(action)
            return
        }

        switch action {
        case .camera:
            showCamera = true
        case .library:
            showLibrary = true
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
            let hasProvider = KeychainManager.APIProvider.allCases.contains { provider in
                KeychainManager.shared.getAPIKeyIfAvailable(for: provider)?.isEmpty == false
            }
            let allowNetwork = hasProvider
            let coordinator = VisionPlanCoordinator()
            let regionCode = Locale.current.region?.identifier ?? "JP"
            let locale = UserLocale(
                country: regionCode,
                city: regionCode == "JP" ? "Tokyo" : "Toronto"
            )
            let context = VisionPlanContextBuilder.build(
                project: project,
                phase: phase,
                taskList: taskList,
                existingTasks: existingTasks,
                additionalNotes: additionalContextHint.map { [$0] } ?? []
            )

            let plan = await coordinator.generatePlan(from: imageData, locale: locale, allowNetwork: allowNetwork, context: context)
            if plan.project == "Fallback Moving Plan" {
                await MainActor.run {
                    errorMessage = nil
                    toastCenter.show("AIが混雑中のため、テンプレート候補を表示しました")
                }
            }
            let suggestions: [PhotoDraftBuilder.Suggestion] = plan.tasks.map { t in
                let details: String? = {
                    let checklist = (t.checklist ?? []).map { "• \($0)" }.joined(separator: "\n")
                    return checklist.isEmpty ? nil : checklist
                }()
                let dueDate: Date? = t.dueDate
                let priority: TaskPriority = {
                    let score = t.priority ?? 3
                    if score <= 2 { return .low }
                    if score >= 4 { return .high }
                    return .medium
                }()
                let exitLabels: [String] = {
                    guard let tag = t.exit_tag, tag != .keep else { return [] }
                    return [tag.rawValue]
                }()
                return PhotoDraftBuilder.Suggestion(
                    title: t.title,
                    details: details,
                    labels: (t.labels ?? []) + exitLabels,
                    dueDate: dueDate,
                    priority: priority
                )
            }

            if usePreviewFlow {
                let drafts = PhotoDraftBuilder.build(from: suggestions)
                await MainActor.run {
                    if drafts.isEmpty {
                        errorMessage = errorMessage ?? "写真から提案を生成できませんでした"
                    } else {
                        onPreview(drafts)
                    }
                }
                return
            }

            let tasks: [ShigodekiTask] = suggestions.enumerated().map { idx, suggestion in
                ShigodekiTask(
                    title: suggestion.title,
                    description: suggestion.details,
                    assignedTo: nil,
                    createdBy: "ai-generated",
                    dueDate: suggestion.dueDate,
                    priority: suggestion.priority,
                    listId: taskList.id ?? "",
                    phaseId: taskList.phaseId,
                    projectId: taskList.projectId,
                    order: idx
                )
            }

            await MainActor.run { onDirectSave(tasks) }
        }
    }
}
