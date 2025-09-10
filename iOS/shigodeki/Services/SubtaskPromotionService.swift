//
//  SubtaskPromotionService.swift
//  shigodeki
//
//  Service for promoting subtasks to full tasks
//

import Foundation

// LLMを用いたタスク詳細生成を行うための補助
import SwiftUI

struct SubtaskPromotionService {
    
    /// サブタスクをタスクに繰り上げる
    /// - Parameters:
    ///   - subtask: 繰り上げるサブタスク
    ///   - task: 親タスク
    ///   - project: プロジェクト
    ///   - phase: フェーズ
    ///   - enhancedTaskManager: EnhancedTaskManager（タスク作成用）
    ///   - subtaskManager: サブタスクマネージャー（サブタスク削除用）
    /// - Returns: 作成されたタスクのID
    static func promoteSubtaskToTask(
        subtask: Subtask,
        parentTask: ShigodekiTask,
        project: Project,
        phase: Phase,
        taskListId: String,
        enhancedTaskManager: EnhancedTaskManager,
        subtaskManager: SubtaskManager
    ) async throws -> String {
        
        guard let subtaskId = subtask.id,
              let taskId = parentTask.id,
              let projectId = project.id,
              let phaseId = phase.id else {
            throw SubtaskPromotionError.missingRequiredId
        }
        
        // 1. サブタスクの内容でタスクを作成
        let createdTask = try await enhancedTaskManager.createPhaseTask(
            title: subtask.title,
            description: subtask.description,
            assignedTo: subtask.assignedTo,
            createdBy: subtask.createdBy,
            dueDate: subtask.dueDate,
            priority: .medium, // デフォルト優先度
            sectionId: parentTask.sectionId, // 親タスクと同じセクションに配置
            sectionName: parentTask.sectionName,
            phaseId: phaseId,
            projectId: projectId,
            order: nil // 自動採番
        )
        
        guard let newTaskId = createdTask.id else {
            throw SubtaskPromotionError.taskCreationFailed("Created task has no ID")
        }
        
        // 2. （オプション）LLMで詳細説明を自動生成し、タスクに反映
        do {
            let aiGenerator = await SharedManagerStore.shared.getAiGenerator()
            if let details = try? await PhaseAIService.generateTaskDetails(for: createdTask, aiGenerator: aiGenerator) {
                var enriched = createdTask
                // 既存説明がある場合は追記、無ければ置換
                if let existing = createdTask.description, !existing.isEmpty {
                    enriched.description = existing + "\n\nAI提案:\n" + details
                } else {
                    enriched.description = details
                }
                _ = try? await enhancedTaskManager.updatePhaseTask(enriched)
            }
        }
        
        // 3. 作成成功後にサブタスクを削除
        try await subtaskManager.deletePhaseSubtask(
            id: subtaskId,
            taskId: taskId,
            phaseId: phaseId,
            projectId: projectId
        )
        
        print("✅ Subtask '\(subtask.title)' promoted to task with ID: \(newTaskId)")
        
        return newTaskId
    }
}

// MARK: - Error Types

enum SubtaskPromotionError: Error, LocalizedError {
    case missingRequiredId
    case taskCreationFailed(String)
    case subtaskDeletionFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .missingRequiredId:
            return "必要なIDが不足しています"
        case .taskCreationFailed(let message):
            return "タスク作成に失敗しました: \(message)"
        case .subtaskDeletionFailed(let message):
            return "サブタスク削除に失敗しました: \(message)"
        }
    }
}
