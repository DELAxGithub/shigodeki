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
    /// 緊急対応用 - @MainActor + get async プロパティの相互作用によるSIGABRT回避
    init() {
        logger.info("🔧 PhaseTaskDetailService initialized with direct instantiation (fallback mode)")
        self.subtaskManager = SubtaskManager()
        self.projectManager = ProjectManager()
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
    
    func generateSubtasksWithAI(task: ShigodekiTask) async -> [AITaskSuggestion.TaskSuggestion]? {
        logger.info("🤖 Starting AI subtask generation for task: \(task.title, privacy: .public)")
        logger.debug("🧵 Current thread: \(Thread.current), MainActor: \(Thread.isMainThread)")
        
        let prompt = "次のタスクを3〜7個の実行可能なサブタスクに分割して、日本語で出力してください。\nタイトル: \(task.title)\n説明: \(task.description ?? "")"
        
        do {
            await aiGenerator.generateTaskSuggestions(for: prompt, projectType: nil)
            let suggestions = aiGenerator.generatedSuggestions?.tasks
            
            if let suggestions = suggestions {
                logger.info("✅ AI generated \(suggestions.count) subtask suggestions")
                return suggestions
            } else {
                logger.warning("⚠️ AI generation returned no suggestions")
                return nil
            }
        } catch {
            logger.error("❌ AI generation failed: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// AI生成結果を直接Subtaskとして永続化する関数
    func createSubtasksFromAI(task: ShigodekiTask, project: Project, phase: Phase) async -> [Subtask] {
        guard let taskId = task.id, let projectId = project.id, let phaseId = phase.id else { 
            print("❌ 必要なIDが不足しています")
            return [] 
        }
        
        let prompt = """
        次のタスクを3〜7個の実行可能なサブタスクに分割して、日本語で出力してください。
        タイトル: \(task.title)
        説明: \(task.description ?? "")
        """
        
        await aiGenerator.generateTaskSuggestions(for: prompt, projectType: nil)
        guard let suggestions = aiGenerator.generatedSuggestions?.tasks else { 
            print("❌ AI生成に失敗しました")
            return [] 
        }

        var createdSubtasks: [Subtask] = []
        for (index, suggestion) in suggestions.enumerated() {
            do {
                let subtask = try await subtaskManager.createPhaseSubtask(
                    title: suggestion.title.trimmingCharacters(in: .whitespacesAndNewlines),
                    description: suggestion.description.isEmpty ? nil : suggestion.description,
                    assignedTo: nil,
                    createdBy: task.createdBy,
                    dueDate: nil,
                    taskId: taskId,
                    phaseId: phaseId,
                    projectId: projectId,
                    order: index
                )
                createdSubtasks.append(subtask)
                print("✅ サブタスク作成成功: \(suggestion.title)")
            } catch {
                print("❌ サブタスク作成失敗: \(suggestion.title) - \(error)")
            }
        }
        
        return createdSubtasks
    }
    
    func generateTaskDetails(for task: ShigodekiTask) async -> String? {
        return await aiGenerator.generateTaskDetails(for: task)
    }
    
    /// AI提案テキストを構造解析してサブタスクを作成
    func createSubtasksFromAIContent(
        content: String,
        task: ShigodekiTask,
        project: Project,
        phase: Phase
    ) async -> [Subtask] {
        guard let taskId = task.id, let projectId = project.id, let phaseId = phase.id else {
            logger.error("❌ 必要なIDが不足しています（サブタスクのAI分割用）")
            return []
        }
        
        logger.info("🤖 AI提案からサブタスクを構造解析して作成開始")
        logger.debug("Content preview: \(content.prefix(100))...")
        
        // AI提案テキストから実行手順を抽出
        let extractedTasks = extractTasksFromStructuredContent(content)
        
        if extractedTasks.isEmpty {
            logger.warning("⚠️ AI提案から実行手順を抽出できませんでした")
            return []
        }
        
        logger.info("📝 抽出されたタスク数: \(extractedTasks.count)")
        
        var createdSubtasks: [Subtask] = []
        
        // 抽出されたタスクを順番にサブタスクとして作成
        for (index, extractedTask) in extractedTasks.enumerated() {
            do {
                let subtask = try await subtaskManager.createPhaseSubtask(
                    title: extractedTask.title,
                    description: extractedTask.description.isEmpty ? nil : extractedTask.description,
                    assignedTo: nil,
                    createdBy: task.createdBy,
                    taskId: taskId,
                    phaseId: phaseId,
                    projectId: projectId,
                    order: index
                )
                createdSubtasks.append(subtask)
                logger.info("✅ サブタスク作成成功: \(extractedTask.title)")
            } catch {
                logger.error("❌ サブタスク作成失敗: \(extractedTask.title) - \(error.localizedDescription)")
                // エラーが発生しても他のタスク作成は続行
                continue
            }
        }
        
        logger.info("🎉 AI提案からサブタスク作成完了: \(createdSubtasks.count)/\(extractedTasks.count)")
        return createdSubtasks
    }
    
    // MARK: - Private Helper Methods
    
    /// 構造化されたAI提案テキストからタスクを抽出
    private func extractTasksFromStructuredContent(_ content: String) -> [ExtractedTask] {
        var extractedTasks: [ExtractedTask] = []
        
        // パターン1: 番号付きリスト "(a) タスク名" の形式
        let numberedPattern = #"\([a-z]\)\s*([^\n]+)"#
        let numberedRegex = try? NSRegularExpression(pattern: numberedPattern, options: [])
        
        if let regex = numberedRegex {
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
        
        // パターン2: ダッシュリスト "- タスク名" の形式（番号付きが見つからない場合）
        if extractedTasks.isEmpty {
            let dashPattern = #"^-\s*([^\n]+)"#
            let dashRegex = try? NSRegularExpression(pattern: dashPattern, options: [.anchorsMatchLines])
            
            if let regex = dashRegex {
                let matches = regex.matches(in: content, options: [], range: NSRange(content.startIndex..., in: content))
                for match in matches {
                    if let titleRange = Range(match.range(at: 1), in: content) {
                        let title = String(content[titleRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                        if !title.isEmpty && !title.contains("：") { // セクションヘッダー除外
                            extractedTasks.append(ExtractedTask(title: title, description: ""))
                        }
                    }
                }
            }
        }
        
        // パターン3: 数字リスト "1. タスク名" の形式（他が見つからない場合）
        if extractedTasks.isEmpty {
            let numberPattern = #"^\d+\.\s*([^\n]+)"#
            let numberRegex = try? NSRegularExpression(pattern: numberPattern, options: [.anchorsMatchLines])
            
            if let regex = numberRegex {
                let matches = regex.matches(in: content, options: [], range: NSRange(content.startIndex..., in: content))
                for match in matches {
                    if let titleRange = Range(match.range(at: 1), in: content) {
                        let title = String(content[titleRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                        if !title.isEmpty && !title.contains("：") { // セクションヘッダー除外
                            extractedTasks.append(ExtractedTask(title: title, description: ""))
                        }
                    }
                }
            }
        }
        
        return extractedTasks
    }
}

// MARK: - Supporting Types

/// AI提案から抽出されたタスク情報
private struct ExtractedTask {
    let title: String
    let description: String
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