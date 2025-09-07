import Foundation
import os

private let logger = Logger(subsystem: "com.shigodeki.app", category: "PhaseAIService")

struct PhaseAIService {
    // MARK: - Public Methods
    
    static func generateSubtasksWithAI(
        task: ShigodekiTask,
        aiGenerator: AITaskGenerator
    ) async -> [AITaskSuggestion.TaskSuggestion]? {
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
    
    static func createSubtasksFromAI(
        task: ShigodekiTask,
        project: Project,
        phase: Phase,
        aiGenerator: AITaskGenerator,
        subtaskManager: SubtaskManager
    ) async -> [Subtask] {
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
    
    static func generateTaskDetails(
        for task: ShigodekiTask,
        aiGenerator: AITaskGenerator
    ) async -> String? {
        return await aiGenerator.generateTaskDetails(for: task)
    }
    
    static func createSubtasksFromAIContent(
        content: String,
        task: ShigodekiTask,
        project: Project,
        phase: Phase,
        subtaskManager: SubtaskManager
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
    
    // MARK: - Private Methods
    
    /// 構造化されたAI提案テキストからタスクを抽出
    private static func extractTasksFromStructuredContent(_ content: String) -> [ExtractedTask] {
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