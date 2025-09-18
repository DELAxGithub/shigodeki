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
        
        await aiGenerator.generateTaskSuggestions(for: prompt, projectType: nil)
        let suggestions = await aiGenerator.generatedSuggestions?.tasks
        
        if let suggestions = suggestions {
            logger.info("✅ AI generated \(suggestions.count) subtask suggestions")
            return suggestions
        } else {
            logger.warning("⚠️ AI generation returned no suggestions")
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
            logger.error("❌ Required IDs missing for subtask creation: taskId=\(task.id ?? "nil"), projectId=\(project.id ?? "nil"), phaseId=\(phase.id ?? "nil")")
            return [] 
        }
        
        let prompt = """
        次のタスクを3〜7個の実行可能なサブタスクに分割して、日本語で出力してください。
        タイトル: \(task.title)
        説明: \(task.description ?? "")
        """
        
        await aiGenerator.generateTaskSuggestions(for: prompt, projectType: nil)
        guard let suggestions = await aiGenerator.generatedSuggestions?.tasks else { 
            logger.warning("⚠️ AI subtask generation returned no suggestions for task: \(task.title)")
            return [] 
        }

        var createdSubtasks: [Subtask] = []
        for (index, suggestion) in suggestions.enumerated() {
            do {
                let subtask = try await subtaskManager.createPhaseSubtask(
                    title: suggestion.title.trimmingCharacters(in: .whitespacesAndNewlines),
                    description: preferredRationale(from: suggestion),
                    assignedTo: nil,
                    createdBy: task.createdBy,
                    dueDate: nil,
                    taskId: taskId,
                    phaseId: phaseId,
                    projectId: projectId,
                    order: index
                )
                createdSubtasks.append(subtask)
                logger.info("✅ Subtask created successfully: \(suggestion.title)")
            } catch {
                logger.error("❌ Subtask creation failed: \(suggestion.title) - \(error.localizedDescription)")
            }
        }
        
        return createdSubtasks
    }
    
    static func generateTaskDetails(
        for task: ShigodekiTask,
        aiGenerator: AITaskGenerator
    ) async -> String? {
        do {
            return try await aiGenerator.generateTaskDetails(for: task)
        } catch {
            logger.error("❌ Task detail generation failed: \(error.localizedDescription)")
            return nil
        }
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
        var extractedTasks: [ExtractedTask] = []
        // まずLLMでの抽出を試みる（実行手順セクションを優先的に抽出させる）
        do {
            let aiGen = await SharedManagerStore.shared.getAiGenerator()
            extractedTasks = try await extractTasksWithLLM(from: content, using: aiGen)
        } catch {
            logger.warning("⚠️ LLM抽出に失敗: \(error.localizedDescription). ルール抽出にフォールバック")
        }
        // LLMで抽出できなかった場合のみ、ルールベース抽出にフォールバック
        if extractedTasks.isEmpty {
            extractedTasks = extractTasksFromStructuredContent(content)
        }
        
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

    /// LLMに詳細文から実行手順のタイトルのみを抽出させる
    private static func extractTasksWithLLM(from content: String, using aiGenerator: AITaskGenerator) async throws -> [ExtractedTask] {
        // 明確なフォーマット指示（JSON配列の文字列のみ）
        let prompt = """
        次の説明文から「実行手順（ステップバイステップ）」に該当するステップのタイトルだけを抽出してください。
        制約:
        - 出力はJSON配列のみ。前後に説明やコードブロックは不要。
          優先形式: [{"title":"...","description":"一言の補足"}, ...]
          代替許容: ["タイトル1", "タイトル2"]
        - 各タイトルは1行の短い命令文。文末の句読点は不要。
        - 「必要な準備」「完了の判断基準」「注意点」「所要時間」などの見出しは含めない。
        - ステップ番号は削除してタイトルのみ。
        - 最大12件。

        テキスト:
        ---
        \(content)
        ---
        """

        let raw = try await aiGenerator.generateText(prompt: prompt)

        if let data = raw.data(using: .utf8),
           let arr = try? JSONSerialization.jsonObject(with: data) as? [Any] {
            // 形式1: 配列の各要素が辞書（title/description）
            var extracted: [ExtractedTask] = []
            for item in arr {
                if let dict = item as? [String: Any] {
                    let titleRaw = (dict["title"] as? String) ?? ""
                    let descrRaw = (dict["description"] as? String) ?? ""
                    let title = normalizedTitle(titleRaw)
                    let descr = descrRaw.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                    if !title.isEmpty {
                        extracted.append(ExtractedTask(title: title, description: descr))
                    }
                } else if let s = item as? String {
                    let title = normalizedTitle(s)
                    if !title.isEmpty { extracted.append(ExtractedTask(title: title, description: "")) }
                }
            }
            if !extracted.isEmpty { return extracted }
        }

        // JSONでない場合は、行抽出をフォールバックとして適用
        let fallback = extractSteps(in: raw)
        return fallback
    }
    
    /// 構造化されたAI提案テキストからタスクを抽出
    /// 優先順位:
    /// 1) 「実行手順（ステップバイステップ）」セクション内の手順のみを抽出
    /// 2) 見つからない場合に限り、従来のリスト検出（全体）にフォールバック
    private static func extractTasksFromStructuredContent(_ content: String) -> [ExtractedTask] {
        // まず「実行手順」セクションを特定して、その内部のみを解析する
        if let stepSection = sliceExecutionStepsSection(from: content) {
            let steps = extractSteps(in: stepSection)
            if !steps.isEmpty { return steps }
        }

        // フォールバック: 旧ロジック（全文スキャン）。
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
                        extractedTasks.append(ExtractedTask(title: normalizedTitle(title), description: ""))
                    }
                }
            }
        }

        // パターン2: ダッシュリスト "- タスク名" の形式（番号付きが見つからない場合）
        if extractedTasks.isEmpty {
            let dashPattern = #"^[\-・•]\s+([^\n]+)"#
            let dashRegex = try? NSRegularExpression(pattern: dashPattern, options: [.anchorsMatchLines])
            if let regex = dashRegex {
                let matches = regex.matches(in: content, options: [], range: NSRange(content.startIndex..., in: content))
                for match in matches {
                    if let titleRange = Range(match.range(at: 1), in: content) {
                        let title = String(content[titleRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                        if !title.isEmpty && !title.contains("：") { // セクションヘッダー除外
                            extractedTasks.append(ExtractedTask(title: normalizedTitle(title), description: ""))
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
                        let raw = String(content[titleRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                        // セクション見出しの可能性が高いものは除外
                        if !raw.isEmpty && !raw.contains("：") && !raw.contains("実行手順") {
                            extractedTasks.append(ExtractedTask(title: normalizedTitle(raw), description: ""))
                        }
                    }
                }
            }
        }

        return extractedTasks
    }

    /// 「実行手順」セクションのみを切り出す
    /// - 先頭見出し例: "1. 実行手順（ステップバイステップ）" / "1. 実行手順" / "実行手順"
    /// - 終端: 次のトップレベル番号見出し（例: "2. 必要な準備や前提条件" など）直前まで
    private static func sliceExecutionStepsSection(from content: String) -> String? {
        let headerPattern = #"(?m)^\s*(\d+\.\s*)?(?:実行手順（ステップバイステップ）|実行手順|ステップバイステップ)\s*[:：]?\s*$"#
        let nextSectionPattern = #"(?m)^\s*\d+\.\s+.+$"#

        guard let headerRegex = try? NSRegularExpression(pattern: headerPattern),
              let nextRegex = try? NSRegularExpression(pattern: nextSectionPattern) else {
            return nil
        }

        let fullRange = NSRange(content.startIndex..., in: content)
        guard let headerMatch = headerRegex.firstMatch(in: content, options: [], range: fullRange) else {
            return nil
        }

        let sectionStart = headerMatch.range.upperBound

        // 次のトップレベル見出し（例: 2. ...）を検索
        let tailRange = NSRange(location: sectionStart, length: fullRange.length - sectionStart)
        let nextMatch = nextRegex.firstMatch(in: content, options: [], range: tailRange)

        let sectionEnd = nextMatch?.range.lowerBound ?? fullRange.length

        if sectionStart < sectionEnd {
            // Convert NSRange offsets (UTF-16) to String.Index safely
            let utf16 = content.utf16
            let startUTF16 = utf16.index(utf16.startIndex, offsetBy: sectionStart)
            let endUTF16 = utf16.index(utf16.startIndex, offsetBy: sectionEnd)
            if let start = String.Index(startUTF16, within: content),
               let end = String.Index(endUTF16, within: content), start <= end {
                let slice = String(content[start..<end])
                return slice.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            }
        }

        return nil
    }

    /// 実行手順セクション内の行からステップを抽出
    private static func extractSteps(in section: String) -> [ExtractedTask] {
        var steps: [ExtractedTask] = []

        // 優先0: "ステップ1: ..." / "Step 1: ..." の形式（医療・手順系の出力で多い）
        let stepLabelPattern = #"(?m)^\s*(?:ステップ|Step)\s*(\d+)\s*[:：]\s*(.+)$"#
        if let regex = try? NSRegularExpression(pattern: stepLabelPattern) {
            let matches = regex.matches(in: section, options: [], range: NSRange(section.startIndex..., in: section))
            for m in matches {
                if let r = Range(m.range(at: 2), in: section) {
                    let title = String(section[r]).trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                    if !title.isEmpty {
                        steps.append(ExtractedTask(title: normalizedTitle(title), description: ""))
                    }
                }
            }
        }
        
        // 優先1: (1) 形式 / （1）形式 / 1) 形式
        let parenNumberPattern = #"(?m)^\s*[\(（]?\s*(\d+)[\)）\.]?\s+([^\n]+)$"#
        if steps.isEmpty, let regex = try? NSRegularExpression(pattern: parenNumberPattern) {
            let matches = regex.matches(in: section, options: [], range: NSRange(section.startIndex..., in: section))
            for m in matches {
                if let r = Range(m.range(at: 2), in: section) {
                    let title = String(section[r]).trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                    if !title.isEmpty {
                        steps.append(ExtractedTask(title: normalizedTitle(title), description: ""))
                    }
                }
            }
        }

        // 優先2: "- "や「・」の箇条書き
        if steps.isEmpty {
            let dashPattern = #"(?m)^\s*[\-・•]\s+([^\n]+)$"#
            if let regex = try? NSRegularExpression(pattern: dashPattern) {
                let matches = regex.matches(in: section, options: [], range: NSRange(section.startIndex..., in: section))
                for m in matches {
                    if let r = Range(m.range(at: 1), in: section) {
                        let title = String(section[r]).trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                        if !title.isEmpty {
                            steps.append(ExtractedTask(title: normalizedTitle(title), description: ""))
                        }
                    }
                }
            }
        }

        // 優先3: セクション内に更に 1. 2. ... が書かれている場合
        if steps.isEmpty {
            let numberPattern = #"(?m)^\s*\d+\.\s+([^\n]+)$"#
            if let regex = try? NSRegularExpression(pattern: numberPattern) {
                let matches = regex.matches(in: section, options: [], range: NSRange(section.startIndex..., in: section))
                for m in matches {
                    if let r = Range(m.range(at: 1), in: section) {
                        let title = String(section[r]).trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                        if !title.isEmpty {
                            steps.append(ExtractedTask(title: normalizedTitle(title), description: ""))
                        }
                    }
                }
            }
        }

        // 冗長な末尾句読点や全角コロン等を正規化し、重複を削除
        var seen = Set<String>()
        let unique = steps.compactMap { task -> ExtractedTask? in
            let key = task.title
            if seen.contains(key) { return nil }
            seen.insert(key)
            return task
        }

        // 多すぎる場合は最大10件に制限（UI保護）
        return Array(unique.prefix(10))
    }

    /// タイトル末尾のコロンや句点を除去し、簡易正規化
    private static func normalizedTitle(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let withoutTrailing = trimmed.replacingOccurrences(of: #"[：:。．]+$"#, with: "", options: .regularExpression)
        return withoutTrailing
    }
}

private extension PhaseAIService {
    static func preferredRationale(from suggestion: AITaskSuggestion.TaskSuggestion) -> String? {
        if let rationale = suggestion.rationale, rationale.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            return rationale.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let description = suggestion.description, description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            return description.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }
}

// MARK: - Supporting Types
// Note: ExtractedTask is defined in Models/ExtractedTask.swift
