//
//  PhaseTaskDetailViewHelpers.swift
//  shigodeki
//
//  Extracted from PhaseTaskDetailView.swift for CLAUDE.md compliance
//  Helper methods for task detail view operations
//

import Foundation
import SwiftUI

@MainActor
class PhaseTaskDetailViewHelpers: ObservableObject {
    
    // 🚨 FIX: 依存性注入でServiceインスタンスを受け取り、重複召喚を防止
    private let service: PhaseTaskDetailService
    
    init(service: PhaseTaskDetailService) {
        self.service = service
    }
    
    // MARK: - Initialization Methods
    
    func initializeView(
        viewModel: PhaseTaskDetailViewModel,
        tagManager: TagManager,
        aiStateManager: AIStateManager
    ) {
        print("📱 PhaseTaskDetailViewHelpers: initializeView called")
        // IMPORTANT: AI configuration check is centralized in PhaseTaskDetailView.onAppear
        // Do NOT call aiStateManager.checkConfiguration() here to prevent duplicate logs
        
        Task {
            if let projectId = viewModel.projectId {
                await tagManager.loadTags(projectId: projectId)
                tagManager.startListening(projectId: projectId)
            }
        }
    }
    
    func loadInitialData(
        task: ShigodekiTask,
        project: Project,
        phase: Phase,
        sectionManager: PhaseSectionManager
    ) async -> (subtasks: [Subtask], projectMembers: [ProjectMember], selectedSectionId: String?) {
        
        async let subtasksTask = service.loadSubtasks(task: task, project: project, phase: phase)
        async let membersTask = service.loadProjectMembers(project: project)
        
        let (loadedSubtasks, loadedMembers) = await (subtasksTask, membersTask)
        
        await MainActor.run {
            sectionManager.startListening(phaseId: phase.id ?? "", projectId: project.id ?? "")
        }
        
        return (loadedSubtasks, loadedMembers, task.sectionId)
    }
    
    // MARK: - Save Operations
    
    func saveTask(viewModel: PhaseTaskDetailViewModel) async throws {
        try await viewModel.save()
    }
    
    // MARK: - Subtask Operations
    
    func addSubtask(
        title: String,
        task: ShigodekiTask,
        project: Project,
        phase: Phase
    ) async throws -> [Subtask] {
        _ = try await service.addSubtask(title: title, task: task, project: project, phase: phase)
        return await service.loadSubtasks(task: task, project: project, phase: phase)
    }
    
    func deleteSubtask(
        _ subtask: Subtask,
        task: ShigodekiTask,
        project: Project,
        phase: Phase
    ) async throws -> [Subtask] {
        try await service.deleteSubtask(subtask, task: task, project: project, phase: phase)
        return await service.loadSubtasks(task: task, project: project, phase: phase)
    }
    
    /// サブタスクの完了状態を切り替え、更新済みの単一Subtaskを返す（リスト再取得なし）
    func toggleSubtaskReturnOne(_ subtask: Subtask) async throws -> Subtask {
        return try await service.toggleSubtask(subtask)
    }
    
    // MARK: - AI Operations
    
    func aiSplitWithDirectSave(
        task: ShigodekiTask,
        project: Project,
        phase: Phase
    ) async -> [Subtask] {
        let createdSubtasks = await service.createSubtasksFromAI(task: task, project: project, phase: phase)
        if !createdSubtasks.isEmpty {
            print("✅ \(createdSubtasks.count)個のサブタスクを自動作成しました")
        } else {
            print("❌ AI生成またはサブタスク作成に失敗しました")
        }
        return await service.loadSubtasks(task: task, project: project, phase: phase)
    }
    
    func generateSubtasksWithLoop(
        task: ShigodekiTask,
        project: Project,
        phase: Phase,
        onAddSubtask: @escaping (String) async throws -> Void
    ) async {
        if let suggestions = await service.generateSubtasksWithAI(task: task) {
            for suggestion in suggestions {
                do {
                    try await onAddSubtask(suggestion.title)
                } catch {
                    print("❌ Failed to add AI-generated subtask: \(error)")
                }
            }
        }
    }
    
    // MARK: - Subtask Promotion
    
    /// サブタスクをタスクに繰り上げて、サブタスクリストを更新
    func promoteSubtaskToTask(
        _ subtask: Subtask,
        task: ShigodekiTask,
        project: Project,
        phase: Phase,
        taskListId: String
    ) async throws -> [Subtask] {
        _ = try await service.promoteSubtaskToTask(
            subtask: subtask,
            parentTask: task,
            project: project,
            phase: phase,
            taskListId: taskListId
        )
        
        // 繰り上げ後、更新されたサブタスクリストを返す
        return await service.loadSubtasks(task: task, project: project, phase: phase)
    }
}