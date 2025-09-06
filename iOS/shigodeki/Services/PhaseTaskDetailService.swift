//
//  PhaseTaskDetailService.swift
//  shigodeki
//
//  Extracted from PhaseTaskDetailView.swift for CLAUDE.md compliance
//  Business logic for task detail operations
//

import Foundation

@MainActor
class PhaseTaskDetailService: ObservableObject {
    private let subtaskManager = SubtaskManager()
    private let projectManager = ProjectManager()
    private let aiGenerator = AITaskGenerator()
    
    // MARK: - Subtask Operations
    
    func loadSubtasks(task: ShigodekiTask, project: Project, phase: Phase) async -> [Subtask] {
        guard let taskId = task.id, let projectId = project.id, let phaseId = phase.id else {
            return []
        }
        
        do {
            return try await subtaskManager.getPhaseSubtasks(taskId: taskId, phaseId: phaseId, projectId: projectId)
        } catch {
            print("❌ Failed to load subtasks: \(error)")
            return []
        }
    }
    
    func addSubtask(title: String, task: ShigodekiTask, project: Project, phase: Phase) async throws -> Subtask {
        guard let taskId = task.id, let projectId = project.id, let phaseId = phase.id else {
            throw PhaseTaskDetailError.missingRequiredId
        }
        
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            throw PhaseTaskDetailError.emptySubtaskTitle
        }
        
        return try await subtaskManager.createPhaseSubtask(
            title: trimmedTitle,
            description: nil,
            assignedTo: nil,
            createdBy: task.createdBy,
            dueDate: nil,
            taskId: taskId,
            phaseId: phaseId,
            projectId: projectId,
            order: nil
        )
    }
    
    func deleteSubtask(_ subtask: Subtask, task: ShigodekiTask, project: Project, phase: Phase) async throws {
        guard let subtaskId = subtask.id,
              let taskId = task.id,
              let projectId = project.id,
              let phaseId = phase.id else {
            throw PhaseTaskDetailError.missingRequiredId
        }
        
        try await subtaskManager.deletePhaseSubtask(
            id: subtaskId,
            taskId: taskId,
            phaseId: phaseId,
            projectId: projectId
        )
    }
    
    func toggleSubtask(_ subtask: Subtask) async throws -> Subtask {
        var updatedSubtask = subtask
        updatedSubtask.isCompleted.toggle()
        
        return try await subtaskManager.updatePhaseSubtask(updatedSubtask)
    }
    
    // MARK: - Member Operations
    
    func loadProjectMembers(project: Project) async -> [ProjectMember] {
        guard let projectId = project.id else {
            return []
        }
        
        do {
            return try await projectManager.getProjectMembers(projectId: projectId)
        } catch {
            print("❌ Failed to load project members: \(error)")
            return []
        }
    }
    
    // MARK: - AI Operations
    
    func generateSubtasksWithAI(task: ShigodekiTask) async -> [ShigodekiTask]? {
        let prompt = "次のタスクを3〜7個の実行可能なサブタスクに分割して、日本語で出力してください。\nタイトル: \(task.title)\n説明: \(task.description ?? "")"
        
        await aiGenerator.generateTaskSuggestions(for: prompt, projectType: nil)
        return aiGenerator.generatedSuggestions?.tasks as [ShigodekiTask]?
    }
    
    func generateTaskDetails(for task: ShigodekiTask) async -> String? {
        return await aiGenerator.generateTaskDetails(for: task)
    }
}

enum PhaseTaskDetailError: Error, LocalizedError {
    case missingRequiredId
    case emptySubtaskTitle
    
    var errorDescription: String? {
        switch self {
        case .missingRequiredId:
            return "必要なIDが不足しています"
        case .emptySubtaskTitle:
            return "サブタスクのタイトルが空です"
        }
    }
}