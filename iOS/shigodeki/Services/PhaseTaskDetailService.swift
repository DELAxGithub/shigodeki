//
//  PhaseTaskDetailService.swift
//  shigodeki
//
//  Extracted from PhaseTaskDetailView.swift for CLAUDE.md compliance
//  Business logic for task detail operations
//

import Foundation
import os

private let logger = Logger(subsystem: "com.shigodeki.app", category: "PhaseTaskDetailService")

@MainActor
class PhaseTaskDetailService: ObservableObject {
    // Issue #91対応: デッドロック回避のため直接インスタンス化
    // 将来的にはDIパターンに移行予定
    private let subtaskManager: SubtaskManager
    private let projectManager: ProjectManager 
    private let aiGenerator: AITaskGenerator
    
    // MARK: - Initializers
    
    /// デフォルトイニシャライザ（直接インスタンス化）
    /// 🚨 CTO Fix: AI処理時は SharedManagerStore から動的取得するように修正済み
    init() {
        // 初期化ログを減らすため、デバッグビルドでのみ出力
        #if DEBUG
        logger.info("🔧 PhaseTaskDetailService initialized with dynamic AI dependency resolution")
        #endif
        self.subtaskManager = SubtaskManager()
        self.projectManager = ProjectManager()
        
        // 🚨 CTO Fix: AI関連メソッドで SharedManagerStore.shared.getAiGenerator() を使用
        // この aiGenerator は初期化目的でのみ保持（実際は使用されない）
        self.aiGenerator = AITaskGenerator()
    }
    
    /// 依存注入イニシャライザ（推奨パターン）
    /// - Parameters:
    ///   - subtaskManager: 注入するSubtaskManager
    ///   - aiGenerator: 注入するAITaskGenerator  
    ///   - projectManager: 注入するProjectManager
    private init(
        subtaskManager: SubtaskManager,
        aiGenerator: AITaskGenerator,
        projectManager: ProjectManager
    ) {
        logger.info("✅ PhaseTaskDetailService initialized with dependency injection")
        self.subtaskManager = subtaskManager
        self.aiGenerator = aiGenerator
        self.projectManager = projectManager
    }
    
    /// Factory method for dependency injection
    static func createWithDependencies(
        subtaskManager: SubtaskManager,
        aiGenerator: AITaskGenerator,
        projectManager: ProjectManager
    ) -> PhaseTaskDetailService {
        return PhaseTaskDetailService(
            subtaskManager: subtaskManager,
            aiGenerator: aiGenerator,
            projectManager: projectManager
        )
    }
    
    // MARK: - Subtask Operations
    
    func loadSubtasks(task: ShigodekiTask, project: Project, phase: Phase) async -> [Subtask] {
        return await PhaseSubtaskService.loadSubtasks(
            task: task,
            project: project,
            phase: phase,
            subtaskManager: subtaskManager
        )
    }
    
    func addSubtask(title: String, task: ShigodekiTask, project: Project, phase: Phase) async throws -> Subtask {
        return try await PhaseSubtaskService.addSubtask(
            title: title,
            task: task,
            project: project,
            phase: phase,
            subtaskManager: subtaskManager
        )
    }
    
    func deleteSubtask(_ subtask: Subtask, task: ShigodekiTask, project: Project, phase: Phase) async throws {
        try await PhaseSubtaskService.deleteSubtask(
            subtask,
            task: task,
            project: project,
            phase: phase,
            subtaskManager: subtaskManager
        )
    }
    
    func toggleSubtask(_ subtask: Subtask) async throws -> Subtask {
        return try await PhaseSubtaskService.toggleSubtask(
            subtask,
            subtaskManager: subtaskManager
        )
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
    
    func generateSubtasksWithAI(task: ShigodekiTask) async -> [AITaskSuggestion.TaskSuggestion]? {
        // 🚨 CTO Fix: 動的に最新のAITaskGeneratorを取得し、メモリ最適化に対応
        let dynamicAIGenerator = await SharedManagerStore.shared.getAiGenerator()
        return await PhaseAIService.generateSubtasksWithAI(
            task: task,
            aiGenerator: dynamicAIGenerator
        )
    }
    
    /// AI生成結果を直接Subtaskとして永続化する関数
    func createSubtasksFromAI(task: ShigodekiTask, project: Project, phase: Phase) async -> [Subtask] {
        // 🚨 CTO Fix: 動的に最新のAITaskGeneratorを取得し、メモリ最適化に対応
        let dynamicAIGenerator = await SharedManagerStore.shared.getAiGenerator()
        return await PhaseAIService.createSubtasksFromAI(
            task: task,
            project: project,
            phase: phase,
            aiGenerator: dynamicAIGenerator,
            subtaskManager: subtaskManager
        )
    }
    
    func generateTaskDetails(for task: ShigodekiTask) async -> String? {
        // 🚨 CTO Fix: 動的に最新のAITaskGeneratorを取得し、メモリ最適化に対応
        let dynamicAIGenerator = await SharedManagerStore.shared.getAiGenerator()
        return await PhaseAIService.generateTaskDetails(
            for: task,
            aiGenerator: dynamicAIGenerator
        )
    }
    
    /// AI提案テキストを構造解析してサブタスクを作成
    func createSubtasksFromAIContent(
        content: String,
        task: ShigodekiTask,
        project: Project,
        phase: Phase
    ) async -> [Subtask] {
        // Note: この関数はAITaskGeneratorを直接使用しないため、変更不要
        return await PhaseAIService.createSubtasksFromAIContent(
            content: content,
            task: task,
            project: project,
            phase: phase,
            subtaskManager: subtaskManager
        )
    }
    
    // MARK: - Subtask Promotion
    
    /// サブタスクをタスクに繰り上げる
    func promoteSubtaskToTask(
        subtask: Subtask,
        parentTask: ShigodekiTask,
        project: Project,
        phase: Phase,
        taskListId: String
    ) async throws -> String {
        // 🚨 CTO Fix: 動的にEnhancedTaskManagerを取得し、メモリ最適化に対応
        let enhancedTaskManager = await SharedManagerStore.shared.getTaskManager()
        
        return try await SubtaskPromotionService.promoteSubtaskToTask(
            subtask: subtask,
            parentTask: parentTask,
            project: project,
            phase: phase,
            taskListId: taskListId,
            enhancedTaskManager: enhancedTaskManager,
            subtaskManager: subtaskManager
        )
    }
    
}

// MARK: - Supporting Types


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