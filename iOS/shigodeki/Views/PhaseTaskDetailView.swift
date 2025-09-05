//
//  PhaseTaskDetailView.swift
//  shigodeki
//

import SwiftUI
import PhotosUI

struct PhaseTaskDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var sharedManagers: SharedManagerStore
    let project: Project
    let phase: Phase
    let task: ShigodekiTask
    @StateObject private var viewModel: PhaseTaskDetailViewModel
    @StateObject private var subtaskManager = SubtaskManager()
    @StateObject private var aiGenerator = AITaskGenerator()
    @StateObject private var aiStateManager = AIStateManager() // シンプルな初期化に戻す
    @StateObject private var sectionManager = PhaseSectionManager()
    @StateObject private var projectManager = ProjectManager()
    @StateObject private var tagManager = TagManager()
    @State private var subtasks: [Subtask] = []
    @State private var newSubtaskTitle: String = ""
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var localImages: [UIImage] = []
    @State private var projectMembers: [ProjectMember] = []
    @State private var newTagText: String = ""
    @State private var selectedSectionId: String? = nil
    // Note: selectedTags moved to viewModel.tags for proper persistence
    @State private var showingTagEditor = false
    @State private var showAISettings = false
    
    init(task: ShigodekiTask, project: Project, phase: Phase) {
        self.task = task
        self.project = project
        self.phase = phase
        self._viewModel = StateObject(wrappedValue: PhaseTaskDetailViewModel(task: task, project: project, phase: phase))
    }
    
    var body: some View {
        Form {
            Section("基本") {
                TextField("タイトル", text: $viewModel.title)
                TextField("説明", text: $viewModel.taskDescription)
                Toggle("完了", isOn: $viewModel.isCompleted)
                Picker("優先度", selection: $viewModel.priority) {
                    ForEach(TaskPriority.allCases, id: \.self) { p in Text(p.displayName).tag(p) }
                }
                DatePicker("締切", selection: Binding(get: { task.dueDate ?? Date() }, set: { _ in }), displayedComponents: [.date, .hourAndMinute])
                    .environment(\.locale, Locale(identifier: "ja_JP"))
                    .opacity(task.dueDate == nil ? 0.6 : 1)
            }
            
            // Issues #57 & #60 Fix: Add scrollable description section with auto-linking
            if !viewModel.taskDescription.isEmpty {
                Section("詳細説明") {
                    ScrollView {
                        VStack(alignment: .leading) {
                            // Issue #60: Auto-link URLs in description text
                            Text(viewModel.taskDescription)
                                .textSelection(.enabled)
                                .textSelection(.enabled)
                                .padding(.vertical, 8)
                        }
                    }
                    .frame(maxHeight: 150) // Issue #57: Scrollable with max height
                }
            }
            
            Section("担当・タグ・セクション") {
                AssigneeSectionView(
                    members: projectMembers,
                    assignedTo: $viewModel.assignedTo
                )
                // Tags Section with TagDisplayView
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("タグ")
                            .font(.headline)
                        
                        Spacer()
                        
                        Button(action: { showingTagEditor = true }) {
                            Text(showingTagEditor ? "完了" : "編集")
                                .font(.caption)
                                .foregroundColor(.accentColor)
                        }
                    }
                    
                    if viewModel.tags.isEmpty {
                        Text("タグが設定されていません")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        TaskDetailTagsView(
                            tags: viewModel.tags,
                            tagMasters: tagManager.tags.filter { $0.projectId == viewModel.projectId ?? "" },
                            isEditing: showingTagEditor,
                            onTagTapped: { tagName in
                                // TODO: Handle tag filter or navigation
                                print("Tag tapped: \(tagName)")
                            },
                            onEditTags: { 
                                showingTagEditor.toggle() 
                            }
                        )
                    }
                }
                // クラッシュ対策: セクションデータが読み込まれるまでPickerを表示しない
                if !sectionManager.sections.isEmpty {
                    SectionPickerView(
                        sections: sectionManager.sections,
                        selectedSectionId: Binding(get: { selectedSectionId ?? task.sectionId }, set: { selectedSectionId = $0 }),
                        onChange: { _ in /* Section change logic disabled for Issue #61 fix */ }
                    )
                } else {
                    ProgressView().frame(maxWidth: .infinity, alignment: .center)
                }
            }
            AttachmentsSectionView(
                selectedPhotos: $selectedPhotos,
                localImages: $localImages,
                onImageData: { _ in /* Attachment logic disabled for Issue #61 fix */ }
            )
            Section("サブタスク") {
                if subtasks.isEmpty {
                    Text("サブタスクはありません").foregroundColor(.secondary)
                } else {
                    ForEach(subtasks) { st in
                        HStack {
                            Button(action: { toggleSubtask(st) }) {
                                Image(systemName: st.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(st.isCompleted ? .green : .secondary)
                            }
                            Text(st.title)
                            Spacer()
                            Menu {
                                Button("削除", role: .destructive) { deleteSubtask(st) }
                            } label: { Image(systemName: "ellipsis.circle") }
                        }
                    }
                }
                HStack {
                    TextField("サブタスクを追加", text: $newSubtaskTitle)
                    Button("追加") { addSubtask() }
                        .disabled(newSubtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            // Issue #59 Fix: Add URL link section
            Section("関連リンク") {
                if let linkURL = task.linkURL, !linkURL.isEmpty {
                    Link(destination: URL(string: linkURL) ?? URL(string: "https://example.com")!) {
                        HStack {
                            Image(systemName: "link")
                                .foregroundColor(.blue)
                            Text(linkURL)
                                .foregroundColor(.blue)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                } else {
                    Text("関連リンクがありません")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    TextField("https://example.com", text: Binding(
                        get: { task.linkURL ?? "" },
                        set: { _ in /* Link URL editing disabled for Issue #61 fix */ }
                    ))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                }
            }
            
            Section("AI支援") {
                switch aiStateManager.state {
                case .idle, .checkingConfiguration:
                    AIStatusIndicatorView(message: "設定確認中...")
                    
                case .needsConfiguration(let guidance):
                    AIConfigurationPromptView(
                        guidance: guidance,
                        onNavigateToSettings: { showAISettings = true }
                    )
                    
                case .ready:
                    AIActionButtonsView(
                        onGenerateSubtasks: { aiSplit() },
                        onGenerateDetails: { aiStateManager.generateDetail(for: task) }
                    )
                    
                case .loading(let message):
                    AIStatusIndicatorView(message: message)
                    
                case .suggestion(let result):
                    AIDetailResultView(
                        result: result,
                        onApply: { content in
                            viewModel.taskDescription = content
                            aiStateManager.applyResult(content)
                        },
                        onEdit: { content in
                            viewModel.taskDescription = content
                            aiStateManager.applyResult(content)
                        },
                        onReject: {
                            aiStateManager.dismissResult()
                        }
                    )
                    
                case .error(let message):
                    AIErrorView(
                        message: message,
                        onRetry: { aiStateManager.retry() },
                        onOpenSettings: { showAISettings = true }
                    )
                }
            }
        }
        .navigationTitle("タスク詳細")
        .onAppear {
            // Initialize AI state manager
            aiStateManager.checkConfiguration()
            
            // Initialize tag manager - tags are now managed by viewModel
            Task {
                if let projectId = viewModel.projectId {
                    await tagManager.loadTags(projectId: projectId)
                    tagManager.startListening(projectId: projectId)
                }
            }
        }
        .onDisappear {
            tagManager.stopListening()
        }
        .sheet(isPresented: $showingTagEditor) {
            TaskTagEditorSheet(
                currentTags: viewModel.tags,
                availableTags: tagManager.tags.filter { $0.projectId == viewModel.projectId ?? "" },
                projectId: viewModel.projectId ?? "",
                createdBy: task.createdBy,
                onSave: { updatedTags in
                    viewModel.updateTags(updatedTags)
                }
            )
        }
        .sheet(isPresented: $showAISettings) {
            APISettingsView()
        }
        .toolbar { 
            ToolbarItem(placement: .navigationBarTrailing) { 
                Button("保存") { 
                    Task { 
                        do {
                            try await viewModel.save()
                            dismiss() // 成功時のみ画面を閉じる
                        } catch {
                            // エラー時は画面を閉じずユーザーにフィードバック
                            print("⚠️ 保存エラー: \(error)")
                            // TODO: エラーアラートやハプティックフィードバックを追加
                        }
                    } 
                } 
                .disabled(!viewModel.canSave)
            } 
        }
        .task {
            await loadSubtasks()
            await loadMembers()
            sectionManager.startListening(phaseId: phase.id ?? "", projectId: project.id ?? "")
            selectedSectionId = task.sectionId
        }
    }
}


extension PhaseTaskDetailView {
    private func persistChanges() {
        Task {
            do {
                try await viewModel.save()
            } catch {
                print("❌ Failed to save task changes: \(error)")
            }
        }
    }

    private func loadSubtasks() async {
        guard let tid = task.id, let pid = project.id, let phid = phase.id else { return }
        do { let list = try await subtaskManager.getPhaseSubtasks(taskId: tid, phaseId: phid, projectId: pid); await MainActor.run { subtasks = list } } catch { }
    }
    private func addSubtask() {
        guard let tid = task.id, let pid = project.id, let phid = phase.id else { return }
        let title = newSubtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        Task {
            do {
                _ = try await subtaskManager.createPhaseSubtask(title: title, description: nil, assignedTo: nil, createdBy: task.createdBy, dueDate: nil, taskId: tid, phaseId: phid, projectId: pid, order: nil)
                newSubtaskTitle = ""
                await loadSubtasks()
            } catch { }
        }
    }
    private func deleteSubtask(_ st: Subtask) {
        guard let tid = task.id, let pid = project.id, let phid = phase.id else { return }
        Task { do { try await subtaskManager.deletePhaseSubtask(id: st.id ?? "", taskId: tid, phaseId: phid, projectId: pid); await loadSubtasks() } catch { } }
    }
    private func toggleSubtask(_ st: Subtask) {
        var tmp = st; tmp.isCompleted.toggle()
        Task { do { _ = try await subtaskManager.updatePhaseSubtask(tmp); await loadSubtasks() } catch { } }
    }
    private func aiSplit() {
        let base = "次のタスクを3〜7個の実行可能なサブタスクに分割して、日本語で出力してください。\nタイトル: \(task.title)\n説明: \(task.description ?? "")"
        Task { @MainActor in
            await aiGenerator.generateTaskSuggestions(for: base, projectType: nil)
            if let suggestions = aiGenerator.generatedSuggestions {
                for s in suggestions.tasks { newSubtaskTitle = s.title; addSubtask() }
            }
        }
    }
    private func aiDetail() {
        guard let taskId = task.id, let projectId = project.id, let phaseId = phase.id else { return }
        
        Task { @MainActor in
            if let generatedDetail = await aiGenerator.generateTaskDetails(for: task) {
                // Update task description with AI-generated detail
                // Note: For now just displaying the detail, TODO: implement task update
                print("AI Generated Detail for task '\(task.title)':")
                print(generatedDetail)
                
                // TODO: Implement task update functionality once proper update method is available
            }
        }
    }

    private func loadMembers() async {
        guard let pid = project.id else { return }
        do { let members = try await projectManager.getProjectMembers(projectId: pid); await MainActor.run { projectMembers = members } } catch { }
    }
    private func addTag() {
        /* Add tag functionality disabled for Issue #61 fix */
    }
    private func changeSection(to sectionId: String?) {
        /* Section change functionality disabled for Issue #61 fix */
    }
    
    // Issue #60 Fix: Auto-link URLs in description text
}

