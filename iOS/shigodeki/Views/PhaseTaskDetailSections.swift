//
//  PhaseTaskDetailSections.swift
//  shigodeki
//
//  Extracted from PhaseTaskDetailView.swift for CLAUDE.md compliance
//  Task detail form section components
//

import SwiftUI
import PhotosUI

// MARK: - Basic Info Section

struct TaskBasicInfoSection: View {
    @ObservedObject var viewModel: PhaseTaskDetailViewModel
    let task: ShigodekiTask
    
    var body: some View {
        Section("基本") {
            TextField("タイトル", text: $viewModel.title)
            TextField("説明", text: $viewModel.taskDescription)
            Toggle("完了", isOn: $viewModel.isCompleted)
            
            Picker("優先度", selection: $viewModel.priority) {
                ForEach(TaskPriority.allCases, id: \.self) { priority in
                    Text(priority.displayName).tag(priority)
                }
            }
            
            DatePicker("締切", 
                      selection: Binding(
                        get: { task.dueDate ?? Date() },
                        set: { _ in }
                      ), 
                      displayedComponents: [.date, .hourAndMinute])
                .environment(\.locale, Locale(identifier: "ja_JP"))
                .opacity(task.dueDate == nil ? 0.6 : 1)
        }
    }
}

// MARK: - Task Description Section

struct TaskDescriptionSection: View {
    @ObservedObject var viewModel: PhaseTaskDetailViewModel
    
    var body: some View {
        if !viewModel.taskDescription.isEmpty {
            Section("詳細説明") {
                ScrollView {
                    VStack(alignment: .leading) {
                        Text(viewModel.taskDescription)
                            .textSelection(.enabled)
                            .padding(.vertical, 8)
                    }
                }
                .frame(maxHeight: 150)
            }
        }
    }
}

// MARK: - Assignment and Tags Section

struct TaskAssignmentTagsSection: View {
    @ObservedObject var viewModel: PhaseTaskDetailViewModel
    @ObservedObject var tagManager: TagManager
    @ObservedObject var sectionManager: PhaseSectionManager
    let projectMembers: [ProjectMember]
    let task: ShigodekiTask
    @Binding var showingTagEditor: Bool
    @Binding var selectedSectionId: String?
    
    var body: some View {
        Section("担当・タグ・セクション") {
            // TODO: Implement AssigneeSectionView component
            // AssigneeSectionView(
            //     members: projectMembers,
            //     assignedTo: $viewModel.assignedTo
            // )
            
            // Tags Section
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
                            print("Tag tapped: \(tagName)")
                        },
                        onEditTags: { 
                            showingTagEditor.toggle() 
                        }
                    )
                }
            }
            
            // Section Picker
            if !sectionManager.sections.isEmpty {
                // TODO: Implement SectionPickerView component
                // SectionPickerView(
                //     sections: sectionManager.sections,
                //     selectedSectionId: Binding(
                //         get: { selectedSectionId ?? task.sectionId }, 
                //         set: { selectedSectionId = $0 }
                //     ),
                //     onChange: { _ in }
                // )
            } else {
                ProgressView().frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }
}

// MARK: - Subtasks Section

struct TaskSubtasksSection: View {
    let subtasks: [Subtask]
    @Binding var newSubtaskTitle: String
    let onToggleSubtask: (Subtask) -> Void
    let onDeleteSubtask: (Subtask) -> Void
    let onAddSubtask: () -> Void
    
    var body: some View {
        Section("サブタスク") {
            if subtasks.isEmpty {
                Text("サブタスクはありません")
                    .foregroundColor(.secondary)
            } else {
                ForEach(subtasks) { subtask in
                    HStack {
                        Button(action: { onToggleSubtask(subtask) }) {
                            Image(systemName: subtask.isCompleted ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(subtask.isCompleted ? .green : .secondary)
                        }
                        
                        Text(subtask.title)
                        Spacer()
                        
                        Menu {
                            Button("削除", role: .destructive) { 
                                onDeleteSubtask(subtask) 
                            }
                        } label: { 
                            Image(systemName: "ellipsis.circle") 
                        }
                    }
                }
            }
            
            HStack {
                TextField("サブタスクを追加", text: $newSubtaskTitle)
                Button("追加") { 
                    onAddSubtask() 
                }
                .disabled(newSubtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
}

// MARK: - Related Links Section

struct TaskRelatedLinksSection: View {
    let task: ShigodekiTask
    
    var body: some View {
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
                    set: { _ in }
                ))
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.URL)
                .autocapitalization(.none)
                .disableAutocorrection(true)
            }
        }
    }
}

// MARK: - AI Support Section

struct TaskAISupportSection: View {
    @ObservedObject var aiStateManager: AIStateManager
    @ObservedObject var viewModel: PhaseTaskDetailViewModel
    let task: ShigodekiTask
    let project: Project
    let phase: Phase
    @Binding var showAISettings: Bool
    let onGenerateSubtasks: () -> Void
    let onOptimisticSubtasksUpdate: (String) -> [String] // 楽観更新用コールバック
    let onConfirmOptimisticUpdate: ([String], [Subtask]) -> Void // 成功時確定用
    let onRevertOptimisticUpdate: ([String]) -> Void // 失敗時巻き戻し用
    
    @State private var isCreatingSubtasks = false
    @State private var subtaskCreationResult: String? = nil
    
    var body: some View {
        Section(header: Text("AI支援")) {
            // サブタスク作成中またはフィードバック表示
            if isCreatingSubtasks {
                AIStatusIndicatorView(message: "サブタスクを作成中...")
            } else if let result = subtaskCreationResult {
                HStack {
                    if result.contains("✅") {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else if result.contains("⚠️") {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                    } else {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                    }
                    
                    Text(result)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
                .transition(.opacity)
            }
            
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
                    onGenerateSubtasks: onGenerateSubtasks,
                    onGenerateDetails: { aiStateManager.generateDetail(for: task) }
                )
                
            case .loading(let message):
                AIStatusIndicatorView(message: message)
                
            case .suggestion(let result):
                AIDetailResultView(
                    result: result,
                    onApplyToDescription: { content in
                        viewModel.taskDescription = content
                        Task {
                            do {
                                try await viewModel.save()
                                await MainActor.run {
                                    aiStateManager.applyResult(content)
                                }
                            } catch {
                                print("⚠️ AI提案の説明適用時の保存に失敗: \(error.localizedDescription)")
                                await MainActor.run {
                                    aiStateManager.applyResult(content)
                                }
                            }
                        }
                    },
                    onApplyToSubtasks: { content in
                        Task {
                            // 楽観更新: 即座にUI更新
                            let tempIds = await MainActor.run {
                                isCreatingSubtasks = true
                                subtaskCreationResult = nil
                                return onOptimisticSubtasksUpdate(content)
                            }
                            
                            do {
                                // 裏でFirestore永続化
                                let tempService = PhaseTaskDetailService()
                                let createdSubtasks = await tempService.createSubtasksFromAIContent(
                                    content: content,
                                    task: task,
                                    project: project,
                                    phase: phase
                                )
                                
                                await MainActor.run {
                                    isCreatingSubtasks = false
                                    
                                    if !createdSubtasks.isEmpty {
                                        // 成功: 楽観的なサブタスクを正式なものに置換
                                        onConfirmOptimisticUpdate(tempIds, createdSubtasks)
                                        
                                        subtaskCreationResult = "✅ \(createdSubtasks.count)個のサブタスクを作成しました"
                                        print("✅ \(createdSubtasks.count)個のサブタスクを作成しました（楽観更新）")
                                        
                                        // 3秒後にメッセージを自動クリア
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                                            subtaskCreationResult = nil
                                        }
                                    } else {
                                        // 失敗: 楽観的なサブタスクを削除
                                        onRevertOptimisticUpdate(tempIds)
                                        
                                        subtaskCreationResult = "⚠️ AI提案からサブタスクを抽出できませんでした"
                                        print("⚠️ AI提案からサブタスクを抽出できませんでした")
                                        
                                        // 5秒後にメッセージを自動クリア
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                                            subtaskCreationResult = nil
                                        }
                                    }
                                    
                                    aiStateManager.applyResult(content)
                                }
                            } catch {
                                await MainActor.run {
                                    isCreatingSubtasks = false
                                    
                                    // 失敗: 楽観的なサブタスクを削除
                                    onRevertOptimisticUpdate(tempIds)
                                    
                                    subtaskCreationResult = "❌ サブタスク作成エラー: \(error.localizedDescription)"
                                    print("❌ サブタスク作成エラー: \(error.localizedDescription)")
                                    
                                    // 5秒後にエラーメッセージを自動クリア
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                                        subtaskCreationResult = nil
                                    }
                                    
                                    aiStateManager.applyResult(content)
                                }
                            }
                        }
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
}