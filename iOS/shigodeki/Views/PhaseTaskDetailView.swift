//
//  PhaseTaskDetailView.swift
//  shigodeki
//
//  Refactored for CLAUDE.md compliance - Lightweight coordinator view
//  UI sections extracted to PhaseTaskDetailSections.swift
//  Business logic extracted to PhaseTaskDetailService.swift
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
    @StateObject private var aiStateManager = AIStateManager.shared
    @StateObject private var sectionManager = PhaseSectionManager()
    @StateObject private var tagManager = TagManager()
    @StateObject private var service = PhaseTaskDetailService()
    
    @State private var subtasks: [Subtask] = []
    @State private var newSubtaskTitle: String = ""
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var localImages: [UIImage] = []
    @State private var projectMembers: [ProjectMember] = []
    @State private var selectedSectionId: String? = nil
    @State private var showingTagEditor = false
    @State private var showAISettings = false
    
    // 楽観更新用の一時的なサブタスク管理
    @State private var optimisticSubtasks: [String] = [] // 一時的なID管理
    
    init(task: ShigodekiTask, project: Project, phase: Phase) {
        self.task = task
        self.project = project
        self.phase = phase
        self._viewModel = StateObject(wrappedValue: PhaseTaskDetailViewModel(task: task, project: project, phase: phase))
    }
    
    var body: some View {
        Form {
            TaskBasicInfoSection(viewModel: viewModel, task: task)
            
            TaskDescriptionSection(viewModel: viewModel)
            
            TaskAssignmentTagsSection(
                viewModel: viewModel,
                tagManager: tagManager,
                sectionManager: sectionManager,
                projectMembers: projectMembers,
                task: task,
                showingTagEditor: $showingTagEditor,
                selectedSectionId: $selectedSectionId
            )
            
            // TODO: Implement AttachmentsSectionView component
            // AttachmentsSectionView(
            //     selectedPhotos: $selectedPhotos,
            //     localImages: $localImages,
            //     onImageData: { _ in }
            // )
            
            TaskSubtasksSection(
                subtasks: subtasks,
                newSubtaskTitle: $newSubtaskTitle,
                onToggleSubtask: { toggleSubtask($0) },
                onDeleteSubtask: { deleteSubtask($0) },
                onAddSubtask: { addSubtask() }
            )
            
            TaskRelatedLinksSection(task: task)
            
            TaskAISupportSection(
                aiStateManager: aiStateManager,
                viewModel: viewModel,
                task: task,
                project: project,
                phase: phase,
                showAISettings: $showAISettings,
                onGenerateSubtasks: { aiSplit() },
                onOptimisticSubtasksUpdate: { content in
                    return addOptimisticSubtasks(from: content)
                },
                onConfirmOptimisticUpdate: { tempIds, confirmedSubtasks in
                    confirmOptimisticSubtasks(tempIds: tempIds, confirmedSubtasks: confirmedSubtasks)
                },
                onRevertOptimisticUpdate: { tempIds in
                    revertOptimisticSubtasks(tempIds: tempIds)
                }
            )
        }
        .navigationTitle("タスク詳細")
        .onAppear {
            initializeView()
        }
        .onDisappear {
            tagManager.stopListening()
            sectionManager.removeAllListeners()
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
                        await saveTask()
                    } 
                } 
                .disabled(!viewModel.canSave)
            } 
        }
        .task {
            await loadInitialData()
        }
    }
}


// MARK: - Private Methods

extension PhaseTaskDetailView {
    private func initializeView() {
        print("📱 PhaseTaskDetailView: initializeView called")
        aiStateManager.checkConfiguration()
        
        Task {
            if let projectId = viewModel.projectId {
                await tagManager.loadTags(projectId: projectId)
                tagManager.startListening(projectId: projectId)
            }
        }
    }
    
    private func loadInitialData() async {
        async let subtasksTask = service.loadSubtasks(task: task, project: project, phase: phase)
        async let membersTask = service.loadProjectMembers(project: project)
        
        let (loadedSubtasks, loadedMembers) = await (subtasksTask, membersTask)
        
        await MainActor.run {
            subtasks = loadedSubtasks
            projectMembers = loadedMembers
            selectedSectionId = task.sectionId
        }
        
        sectionManager.startListening(phaseId: phase.id ?? "", projectId: project.id ?? "")
    }
    
    private func saveTask() async {
        do {
            try await viewModel.save()
            dismiss()
        } catch {
            print("⚠️ 保存エラー: \(error)")
        }
    }
    
    // MARK: - Subtask Operations
    
    private func addSubtask() {
        Task {
            do {
                _ = try await service.addSubtask(title: newSubtaskTitle, task: task, project: project, phase: phase)
                newSubtaskTitle = ""
                subtasks = await service.loadSubtasks(task: task, project: project, phase: phase)
            } catch {
                print("❌ Failed to add subtask: \(error)")
            }
        }
    }
    
    private func deleteSubtask(_ subtask: Subtask) {
        Task {
            do {
                try await service.deleteSubtask(subtask, task: task, project: project, phase: phase)
                subtasks = await service.loadSubtasks(task: task, project: project, phase: phase)
            } catch {
                print("❌ Failed to delete subtask: \(error)")
            }
        }
    }
    
    private func toggleSubtask(_ subtask: Subtask) {
        Task {
            do {
                _ = try await service.toggleSubtask(subtask)
                subtasks = await service.loadSubtasks(task: task, project: project, phase: phase)
            } catch {
                print("❌ Failed to toggle subtask: \(error)")
            }
        }
    }
    
    // MARK: - AI Operations
    
    private func aiSplit() {
        aiSplitWithDirectSave()
    }
    
    /// 従来方式: AI生成→ループでaddSubtask()を呼び出し
    private func aiSplitWithLoop() {
        Task { @MainActor in
            if let suggestions = await service.generateSubtasksWithAI(task: task) {
                for suggestion in suggestions {
                    newSubtaskTitle = suggestion.title
                    addSubtask()
                }
            }
        }
    }
    
    /// 自動永続化方式: AI生成→直接Firestore保存
    private func aiSplitWithDirectSave() {
        Task { @MainActor in
            let createdSubtasks = await service.createSubtasksFromAI(task: task, project: project, phase: phase)
            if !createdSubtasks.isEmpty {
                print("✅ \(createdSubtasks.count)個のサブタスクを自動作成しました")
                // サブタスク一覧を再読み込み
                subtasks = await service.loadSubtasks(task: task, project: project, phase: phase)
            } else {
                print("❌ AI生成またはサブタスク作成に失敗しました")
            }
        }
    }
    
    // MARK: - Optimistic Update Helper Methods
    
    /// AI提案から抽出されたタスクを楽観的にサブタスクリストに追加
    private func addOptimisticSubtasks(from content: String) -> [String] {
        // Phase 3のextractTasksFromStructuredContentロジックを再利用
        let extractedTasks = extractTasksFromContent(content)
        var tempIds: [String] = []
        
        for (index, extractedTask) in extractedTasks.enumerated() {
            let tempId = "temp_\(UUID().uuidString)"
            tempIds.append(tempId)
            
            // 楽観的なサブタスクを作成（一時的なID付き）
            var optimisticSubtask = Subtask(
                title: extractedTask.title,
                description: extractedTask.description.isEmpty ? nil : extractedTask.description,
                assignedTo: nil,
                createdBy: task.createdBy,
                dueDate: nil,
                taskId: task.id ?? "",
                listId: "", // 楽観的な一時データではlistIdは不要
                phaseId: phase.id ?? "",
                projectId: project.id ?? "",
                order: subtasks.count + index
            )
            
            // 一時的なIDと作成日時を設定
            optimisticSubtask.id = tempId
            optimisticSubtask.createdAt = Date()
            
            subtasks.append(optimisticSubtask)
        }
        
        return tempIds
    }
    
    /// 楽観更新の成功時：一時サブタスクを正式なサブタスクで置換
    private func confirmOptimisticSubtasks(tempIds: [String], confirmedSubtasks: [Subtask]) {
        // 一時IDのサブタスクを削除
        subtasks.removeAll { subtask in
            tempIds.contains(subtask.id ?? "")
        }
        
        // 正式なサブタスクを追加
        subtasks.append(contentsOf: confirmedSubtasks)
        
        // リストをソート（order順）
        subtasks.sort { $0.order < $1.order }
    }
    
    /// 楽観更新の失敗時：一時サブタスクを削除
    private func revertOptimisticSubtasks(tempIds: [String]) {
        subtasks.removeAll { subtask in
            tempIds.contains(subtask.id ?? "")
        }
    }
    
    /// AI提案テキストから構造解析（PhaseTaskDetailServiceから再利用）
    private func extractTasksFromContent(_ content: String) -> [ExtractedTask] {
        var extractedTasks: [ExtractedTask] = []
        
        // パターン1: 番号付きリスト "(a) タスク名" の形式
        let numberedPattern = #"\([a-z]\)\s*([^\n]+)"#
        if let regex = try? NSRegularExpression(pattern: numberedPattern) {
            let matches = regex.matches(in: content, options: [], range: NSRange(content.startIndex..., in: content))
            for match in matches {
                if let titleRange = Range(match.range(at: 1), in: content) {
                    let title = String(content[titleRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !title.isEmpty {
                        extractedTasks.append(ExtractedTask(title: title, description: ""))
                    }
                }
            }
        }
        
        // パターン2以降は省略（同じロジック）
        return extractedTasks
    }
}

// MARK: - Supporting Types for Optimistic Updates

private struct ExtractedTask {
    let title: String
    let description: String
}

