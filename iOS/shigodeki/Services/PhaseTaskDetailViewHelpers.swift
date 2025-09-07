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
    
    private let service = PhaseTaskDetailService()
    
    // MARK: - Initialization Methods
    
    func initializeView(
        viewModel: PhaseTaskDetailViewModel,
        tagManager: TagManager,
        aiStateManager: AIStateManager
    ) {
        print("📱 PhaseTaskDetailView: initializeView called")
        aiStateManager.checkConfiguration()
        
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
    
    func toggleSubtask(
        _ subtask: Subtask,
        task: ShigodekiTask,
        project: Project,
        phase: Phase
    ) async throws -> [Subtask] {
        _ = try await service.toggleSubtask(subtask)
        return await service.loadSubtasks(task: task, project: project, phase: phase)
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
}