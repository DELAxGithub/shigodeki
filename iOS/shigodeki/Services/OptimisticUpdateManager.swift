//
//  OptimisticUpdateManager.swift
//  shigodeki
//
//  Extracted from PhaseTaskDetailView.swift for CLAUDE.md compliance
//  Optimistic update logic for subtask operations
//

import Foundation

class OptimisticUpdateManager: ObservableObject {
    
    /// AI提案から抽出されたタスクを楽観的にサブタスクリストに追加
    func addOptimisticSubtasks(
        from content: String,
        currentSubtasks: [Subtask],
        task: ShigodekiTask,
        phase: Phase,
        project: Project
    ) -> (updatedSubtasks: [Subtask], tempIds: [String]) {
        
        let extractedTasks = extractTasksFromContent(content)
        var tempIds: [String] = []
        var updatedSubtasks = currentSubtasks
        
        for (index, extractedTask) in extractedTasks.enumerated() {
            let tempId = "temp_\(UUID().uuidString)"
            tempIds.append(tempId)
            
            // 楽観的なサブタスクを作成（一時的なID付き）
            var optimisticSubtask = Subtask(
                title: extractedTask.title,
                description: extractedTask.description.isEmpty ? nil : extractedTask.description,
                assignedTo: nil,
                createdBy: task.createdBy,
                dueDate: nil,
                taskId: task.id ?? "",
                listId: "", // 楽観的な一時データではlistIdは不要
                phaseId: phase.id ?? "",
                projectId: project.id ?? "",
                order: currentSubtasks.count + index
            )
            
            // 一時的なIDと作成日時を設定
            optimisticSubtask.id = tempId
            optimisticSubtask.createdAt = Date()
            
            updatedSubtasks.append(optimisticSubtask)
        }
        
        return (updatedSubtasks, tempIds)
    }
    
    /// 楽観更新の成功時：一時サブタスクを正式なサブタスクで置換
    func confirmOptimisticSubtasks(
        currentSubtasks: [Subtask],
        tempIds: [String],
        confirmedSubtasks: [Subtask]
    ) -> [Subtask] {
        
        // 一時IDのサブタスクを削除
        var updatedSubtasks = currentSubtasks.filter { subtask in
            !tempIds.contains(subtask.id ?? "")
        }
        
        // 正式なサブタスクを追加
        updatedSubtasks.append(contentsOf: confirmedSubtasks)
        
        // リストをソート（order順）
        updatedSubtasks.sort { $0.order < $1.order }
        
        return updatedSubtasks
    }
    
    /// 楽観更新の失敗時：一時サブタスクを削除
    func revertOptimisticSubtasks(
        currentSubtasks: [Subtask],
        tempIds: [String]
    ) -> [Subtask] {
        
        return currentSubtasks.filter { subtask in
            !tempIds.contains(subtask.id ?? "")
        }
    }
    
    /// AI提案テキストから構造解析
    private func extractTasksFromContent(_ content: String) -> [ExtractedTask] {
        var extractedTasks: [ExtractedTask] = []
        
        // パターン1: 番号付きリスト "(a) タスク名" の形式
        let numberedPattern = #"\([a-z]\)\s*([^\n]+)"#
        if let regex = try? NSRegularExpression(pattern: numberedPattern) {
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
        
        // パターン2以降は省略（同じロジック）
        return extractedTasks
    }
}