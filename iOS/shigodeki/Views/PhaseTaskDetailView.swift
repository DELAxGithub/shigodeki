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
    @ObservedObject private var aiStateManager = AIStateManager.shared
    @StateObject private var sectionManager = PhaseSectionManager()
    @StateObject private var tagManager = TagManager()
    @StateObject private var service = PhaseTaskDetailService()
    @StateObject private var helpers: PhaseTaskDetailViewHelpers
    @StateObject private var optimisticManager = OptimisticUpdateManager()
    
    @State private var subtasks: [Subtask] = []
    @State private var newSubtaskTitle: String = ""
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var localImages: [UIImage] = []
    @State private var projectMembers: [ProjectMember] = []
    @State private var selectedSectionId: String? = nil
    @State private var showingTagEditor = false
    @State private var showAISettings = false
    
    // 🚨 FIX: 初期化が一度だけ実行されることを保証するためのフラグ
    @State private var hasInitialized = false
    
    // 楽観更新用の一時的なサブタスク管理
    @State private var optimisticSubtasks: [String] = [] // 一時的なID管理
    
    init(task: ShigodekiTask, project: Project, phase: Phase) {
        self.task = task
        self.project = project
        self.phase = phase
        self._viewModel = StateObject(wrappedValue: PhaseTaskDetailViewModel(task: task, project: project, phase: phase))
        
        // 🚨 FIX: 依存性注入でServiceを共有し、重複インスタンス作成を防止
        let sharedService = PhaseTaskDetailService()
        self._service = StateObject(wrappedValue: sharedService)
        self._helpers = StateObject(wrappedValue: PhaseTaskDetailViewHelpers(service: sharedService))
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
                onToggleSubtask: { subtask in
                    print("🔄 isMainThread:", Thread.isMainThread) // デバッグ用
                    
                    // 1. 即座にローカル状態を更新（楽観的更新）- MainActor保証
                    Task { @MainActor in
                        guard let index = subtasks.firstIndex(where: { $0.id == subtask.id }) else { return }
                        
                        subtasks[index].isCompleted.toggle()
                        let newState = subtasks[index].isCompleted
                        print("🔄 楽観的更新: サブタスク「\(subtask.title)」の完了状態を \(newState) に変更")
                        
                        // 2. バックグラウンドでFirebase同期
                        do {
                            let updatedSubtask = try await helpers.toggleSubtaskReturnOne(subtask)
                            
                            // 3. 同期成功時は該当要素のみを確定更新
                            await MainActor.run {
                                if let localIndex = subtasks.firstIndex(where: { $0.id == subtask.id }) {
                                    subtasks[localIndex] = updatedSubtask // completedAt含む完全なデータで上書き
                                    print("✅ Firebase同期完了: サブタスク確定更新 - id:\(updatedSubtask.id ?? "nil"), completed:\(updatedSubtask.isCompleted), completedAt:\(updatedSubtask.completedAt?.description ?? "nil")")
                                }
                            }
                        } catch {
                            // 4. エラー時は元の状態に巻き戻し
                            await MainActor.run {
                                if let index = subtasks.firstIndex(where: { $0.id == subtask.id }) {
                                    subtasks[index].isCompleted.toggle()
                                    print("❌ 同期失敗: サブタスクの状態を巻き戻しました - \(error)")
                                }
                            }
                        }
                    }
                },
                onDeleteSubtask: { subtask in
                    print("🗑️ isMainThread:", Thread.isMainThread) // デバッグ用
                    
                    // 1. 即座にローカルから削除（楽観的更新）- MainActor保証
                    Task { @MainActor in
                        let backupSubtask = subtask
                        subtasks.removeAll { $0.id == subtask.id }
                        print("🗑️ 楽観的削除: サブタスク「\(subtask.title)」をリストから除去")
                        
                        // 2. バックグラウンドでFirebase同期
                        do {
                            let updatedSubtasks = try await helpers.deleteSubtask(
                                subtask,
                                task: task,
                                project: project,
                                phase: phase
                            )
                            // 3. 同期成功時は正式データで更新
                            await MainActor.run {
                                subtasks = updatedSubtasks
                                print("✅ Firebase削除完了: サブタスクリストを更新")
                            }
                        } catch {
                            // 4. エラー時は削除したサブタスクを復元
                            await MainActor.run {
                                subtasks.append(backupSubtask)
                                subtasks.sort { $0.order < $1.order }
                                print("❌ 削除失敗: サブタスク「\(backupSubtask.title)」を復元しました - \(error)")
                            }
                        }
                    }
                },
                onPromoteSubtask: { subtask in
                    print("⬆️ isMainThread:", Thread.isMainThread) // デバッグ用
                    
                    // 1. 即座にローカルから削除（楽観的更新）- MainActor保証
                    Task { @MainActor in
                        let backupSubtask = subtask
                        subtasks.removeAll { $0.id == subtask.id }
                        print("⬆️ 楽観的繰り上げ: サブタスク「\(subtask.title)」をリストから除去")
                        
                        // 2. バックグラウンドでタスクに繰り上げ
                        do {
                            let updatedSubtasks = try await helpers.promoteSubtaskToTask(
                                subtask,
                                task: task,
                                project: project,
                                phase: phase,
                                taskListId: task.listId
                            )
                            // 3. 繰り上げ成功時は正式データで更新
                            await MainActor.run {
                                subtasks = updatedSubtasks
                                print("✅ サブタスク「\(subtask.title)」をタスクに繰り上げました")
                            }
                        } catch {
                            // 4. エラー時は削除したサブタスクを復元
                            await MainActor.run {
                                subtasks.append(backupSubtask)
                                subtasks.sort { $0.order < $1.order }
                                print("❌ 繰り上げ失敗: サブタスク「\(backupSubtask.title)」を復元しました - \(error)")
                            }
                        }
                    }
                },
                onAddSubtask: { 
                    guard !newSubtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                    print("➕ isMainThread:", Thread.isMainThread) // デバッグ用
                    
                    // 1. 即座にローカルに追加（楽観的更新）- MainActor保証
                    Task { @MainActor in
                        let titleToAdd = newSubtaskTitle
                        
                        let tempSubtask = Subtask(
                            title: titleToAdd,
                            description: nil,
                            assignedTo: nil,
                            createdBy: task.createdBy,
                            dueDate: nil,
                            taskId: task.id ?? "",
                            listId: "",
                            phaseId: phase.id ?? "",
                            projectId: project.id ?? "",
                            order: subtasks.count
                        )
                        var optimisticSubtask = tempSubtask
                        optimisticSubtask.id = "temp_\(UUID().uuidString)"
                        optimisticSubtask.createdAt = Date()
                        
                        subtasks.append(optimisticSubtask)
                        newSubtaskTitle = ""
                        print("➕ 楽観的追加: サブタスク「\(titleToAdd)」をリストに追加")
                        
                        // 2. バックグラウンドでFirebase同期
                        do {
                            let updatedSubtasks = try await helpers.addSubtask(
                                title: titleToAdd,
                                task: task,
                                project: project,
                                phase: phase
                            )
                            // 3. 同期成功時は正式データで更新
                            await MainActor.run {
                                subtasks = updatedSubtasks
                                print("✅ Firebase追加完了: サブタスクリストを更新")
                            }
                        } catch {
                            // 4. エラー時は楽観的に追加したサブタスクを削除し、タイトルを復元
                            await MainActor.run {
                                subtasks.removeAll { $0.id == optimisticSubtask.id }
                                newSubtaskTitle = titleToAdd
                                print("❌ 追加失敗: サブタスクを削除し、入力を復元しました - \(error)")
                            }
                        }
                    }
                }
            )
            
            TaskRelatedLinksSection(task: task)
            
            TaskAISupportSection(
                aiStateManager: aiStateManager,
                viewModel: viewModel,
                task: task,
                project: project,
                phase: phase,
                showAISettings: $showAISettings,
                onGenerateSubtasks: { 
                    await MainActor.run {
                        // no-op: spinner is handled in TaskAISupportSection; we just await the work
                    }
                    let updated = await helpers.aiSplitWithDirectSave(
                        task: task,
                        project: project,
                        phase: phase
                    )
                    await MainActor.run { subtasks = updated }
                },
                onOptimisticSubtasksUpdate: { content in
                    let result = optimisticManager.addOptimisticSubtasks(
                        from: content,
                        currentSubtasks: subtasks,
                        task: task,
                        phase: phase,
                        project: project
                    )
                    subtasks = result.updatedSubtasks
                    return result.tempIds
                },
                onConfirmOptimisticUpdate: { tempIds, confirmedSubtasks in
                    subtasks = optimisticManager.confirmOptimisticSubtasks(
                        currentSubtasks: subtasks,
                        tempIds: tempIds,
                        confirmedSubtasks: confirmedSubtasks
                    )
                },
                onRevertOptimisticUpdate: { tempIds in
                    subtasks = optimisticManager.revertOptimisticSubtasks(
                        currentSubtasks: subtasks,
                        tempIds: tempIds
                    )
                }
            )
        }
        .navigationTitle("タスク詳細")
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
                .onDisappear {
                    // Refresh provider availability and AI state after settings update
                    Task { @MainActor in
                        let aiGen = await SharedManagerStore.shared.getAiGenerator()
                        aiGen.updateAvailableProviders()
                        AIStateManager.shared.checkConfiguration()
                    }
                }
        }
        .toolbar { 
            ToolbarItem(placement: .navigationBarTrailing) { 
                Button("保存") { 
                    Task { 
                        do {
                            try await helpers.saveTask(viewModel: viewModel)
                            dismiss()
                        } catch {
                            print("⚠️ 保存エラー: \(error)")
                        }
                    } 
                } 
                .disabled(!viewModel.canSave)
            } 
        }
        .onAppear {
            // 🚨 FIX: hasInitializedフラグをチェックし、初回のみ実行
            if !hasInitialized {
                // Initialize AI state immediately when view appears (only if not already initialized)
                if case .idle = aiStateManager.state {
                    aiStateManager.checkConfiguration()
                }
                hasInitialized = true
                print("📱 PhaseTaskDetailView: Initialized AI state successfully (once).")
            } else {
                print("📱 PhaseTaskDetailView: Skipping duplicate initialization.")
            }
        }
        .task {
            // Serialize initialization: first load basic data, then initialize components
            let result = await helpers.loadInitialData(
                task: task,
                project: project,
                phase: phase,
                sectionManager: sectionManager
            )
            
            await MainActor.run {
                subtasks = result.subtasks
                projectMembers = result.projectMembers
                selectedSectionId = result.selectedSectionId
            }
            
            // Initialize view components after data is loaded to prevent race conditions
            helpers.initializeView(
                viewModel: viewModel,
                tagManager: tagManager,
                aiStateManager: aiStateManager
            )
        }
    }
}

