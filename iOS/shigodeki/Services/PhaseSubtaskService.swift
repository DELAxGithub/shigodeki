import Foundation

struct PhaseSubtaskService {
    // MARK: - Public Methods
    
    static func loadSubtasks(
        task: ShigodekiTask,
        project: Project,
        phase: Phase,
        subtaskManager: SubtaskManager
    ) async -> [Subtask] {
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
    
    static func addSubtask(
        title: String,
        task: ShigodekiTask,
        project: Project,
        phase: Phase,
        subtaskManager: SubtaskManager
    ) async throws -> Subtask {
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
    
    static func deleteSubtask(
        _ subtask: Subtask,
        task: ShigodekiTask,
        project: Project,
        phase: Phase,
        subtaskManager: SubtaskManager
    ) async throws {
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
    
    static func toggleSubtask(
        _ subtask: Subtask,
        subtaskManager: SubtaskManager
    ) async throws -> Subtask {
        var updatedSubtask = subtask
        updatedSubtask.isCompleted.toggle()
        
        return try await subtaskManager.updatePhaseSubtask(updatedSubtask)
    }
}