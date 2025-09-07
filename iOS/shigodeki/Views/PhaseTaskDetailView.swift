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
                    Task {
                        do {
                            subtasks = try await helpers.toggleSubtask(
                                subtask,
                                task: task,
                                project: project,
                                phase: phase
                            )
                        } catch {
                            print("❌ Failed to toggle subtask: \(error)")
                        }
                    }
                },
                onDeleteSubtask: { subtask in
                    Task {
                        do {
                            subtasks = try await helpers.deleteSubtask(
                                subtask,
                                task: task,
                                project: project,
                                phase: phase
                            )
                        } catch {
                            print("❌ Failed to delete subtask: \(error)")
                        }
                    }
                },
                onAddSubtask: { 
                    Task {
                        do {
                            subtasks = try await helpers.addSubtask(
                                title: newSubtaskTitle,
                                task: task,
                                project: project,
                                phase: phase
                            )
                            newSubtaskTitle = ""
                        } catch {
                            print("❌ Failed to add subtask: \(error)")
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
                    Task { @MainActor in
                        subtasks = await helpers.aiSplitWithDirectSave(
                            task: task,
                            project: project,
                            phase: phase
                        )
                    }
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



