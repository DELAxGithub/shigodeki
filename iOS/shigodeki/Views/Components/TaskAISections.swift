//
//  TaskAISections.swift
//  shigodeki
//
//  Extracted from PhaseTaskDetailSections.swift for CLAUDE.md compliance
//  AI support functionality UI components
//

import SwiftUI

// MARK: - AI Support Section

struct TaskAISupportSection: View {
    @ObservedObject var aiStateManager: AIStateManager
    @ObservedObject var viewModel: PhaseTaskDetailViewModel
    let task: ShigodekiTask
    let project: Project
    let phase: Phase
    @Binding var showAISettings: Bool
    let onGenerateSubtasks: () async -> Void
    let onOptimisticSubtasksUpdate: (String) -> [String] // 楽観更新用コールバック
    let onConfirmOptimisticUpdate: ([String], [Subtask]) -> Void // 成功時確定用
    let onRevertOptimisticUpdate: ([String]) -> Void // 失敗時巻き戻し用
    
    @State private var isCreatingSubtasks = false
    @State private var subtaskCreationResult: String? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // サブタスク作成中またはフィードバック表示
            if isCreatingSubtasks {
                AIStatusIndicatorView(message: "サブタスクを作成中...")
            } else if let result = subtaskCreationResult {
                HStack {
                    if result.contains("✅") {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else if result.contains("⚠️") {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                    } else {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                    }
                    
                    Text(result)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
                .transition(.opacity)
            }
            
            switch aiStateManager.state {
            case .idle, .checkingConfiguration:
                AIStatusIndicatorView(message: "設定確認中...")
                
            case .needsConfiguration(let guidance):
                AIConfigurationPromptView(
                    guidance: guidance,
                    onNavigateToSettings: { showAISettings = true }
                )
                
            case .ready:
                AIActionButtonsView(
                    onGenerateSubtasks: {
                        // Prevent concurrent actions; only allow when AI is truly ready
                        guard case .ready = aiStateManager.state else {
                            print("⚠️ TaskAISections: Ignoring Subtask Split - AI state not ready: \(aiStateManager.state)")
                            return
                        }
                        print("🟦 Tap: AI Subtask Split")
                        Task {
                            await MainActor.run {
                                isCreatingSubtasks = true
                                subtaskCreationResult = nil
                            }
                            await onGenerateSubtasks()
                            await MainActor.run {
                                isCreatingSubtasks = false
                                subtaskCreationResult = "✅ サブタスクの作成が完了しました"
                                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                                    subtaskCreationResult = nil
                                }
                            }
                        }
                    },
                    onGenerateDetails: { 
                        // Prevent multiple concurrent AI generation requests
                        guard case .ready = aiStateManager.state else { 
                            print("⚠️ TaskAISections: Ignoring Detail Proposal - state not ready")
                            return 
                        }
                        print("🟦 Tap: AI Detail Proposal")
                        aiStateManager.generateDetail(for: task) 
                    },
                    isDisabled: false  // Keep false for .ready state since buttons handle their own loading state
                )
                
            case .loading(let message):
                VStack(alignment: .leading, spacing: 8) {
                    AIStatusIndicatorView(message: message)
                    
                    // Show provider switching progress if message contains switching info
                    if message.contains("プロバイダ切替") {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                                .foregroundColor(.orange)
                                .font(.caption2)
                            Text("プロバイダを切り替えています...")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.leading, 8)
                    }
                }
                
            case .suggestion(let result):
                AIDetailResultView(
                    result: result,
                    onApply: { content in
                        Task {
                            // Update viewModel on main actor first
                            await MainActor.run {
                                viewModel.taskDescription = content
                            }
                            
                            // Save in background, then update state on next frame
                            do {
                                try await viewModel.save()
                                DispatchQueue.main.async {
                                    aiStateManager.applyResult(content)
                                }
                            } catch {
                                print("⚠️ AI提案の説明適用時の保存に失敗: \(error.localizedDescription)")
                                DispatchQueue.main.async {
                                    aiStateManager.applyResult(content)
                                }
                            }
                        }
                    },
                    onEdit: { content in
                        Task {
                            // Update viewModel on main actor first  
                            await MainActor.run {
                                viewModel.taskDescription = content
                            }
                            
                            // Save in background, then update state on next frame
                            do {
                                try await viewModel.save()
                                DispatchQueue.main.async {
                                    aiStateManager.applyResult(content)
                                }
                            } catch {
                                print("⚠️ AI提案の編集適用時の保存に失敗: \(error.localizedDescription)")
                                DispatchQueue.main.async {
                                    aiStateManager.applyResult(content)
                                }
                            }
                        }
                    },
                    onCreateSubtasks: { content in
                        Task {
                            // 先に説明文へAI提案を記録し、参考リンクも追記（自動ハイパーリンク対応はTextでは限定的なためテキストに残す）
                            await MainActor.run {
                                var appended = viewModel.taskDescription
                                if !appended.isEmpty { appended += "\n\n" }
                                appended += "AI提案:\n" + content
                                // 簡易URL抽出して追記
                                let urls = extractURLs(from: content)
                                if !urls.isEmpty {
                                    appended += "\n\n参考リンク:\n" + urls.map { "- \($0)" }.joined(separator: "\n")
                                }
                                viewModel.taskDescription = appended
                            }
                            // 保存は裏で実行（失敗してもサブタスク作成は継続）
                            do { try await viewModel.save() } catch { print("⚠️ AI提案の説明保存に失敗: \(error.localizedDescription)") }
                            
                            // 楽観更新: 即座にUI更新
                            let tempIds = await MainActor.run {
                                isCreatingSubtasks = true
                                subtaskCreationResult = nil
                                return onOptimisticSubtasksUpdate(content)
                            }
                            // 裏でFirestore永続化
                            let tempService = PhaseTaskDetailService()
                            let createdSubtasks = await tempService.createSubtasksFromAIContent(
                                content: content,
                                task: task,
                                project: project,
                                phase: phase
                            )
                            
                            // タグ提案（LLM）: 既存タグに追加（最大3件）。失敗しても無視。
                            do {
                                let aiGen = await SharedManagerStore.shared.getAiGenerator()
                                let prompt = """
                                次の説明に基づいて、このタスクに適した短いタグを最大3つ提案してください。
                                - 出力はJSON配列のみ（例: [\"準備\", \"法務\"]).
                                - 各タグは8文字以内、日本語推奨。重複・記号のみは禁止。
                                説明:\n\(content)
                                """
                                let response = try await aiGen.generateText(prompt: prompt)
                                if let data = response.data(using: .utf8), let arr = try? JSONSerialization.jsonObject(with: data) as? [Any] {
                                    let suggested = arr.compactMap { $0 as? String }.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                                    if !suggested.isEmpty {
                                        await MainActor.run {
                                            let current = Set(viewModel.tags)
                                            let merged = Array((current.union(suggested)).prefix(10))
                                            viewModel.updateTags(merged)
                                        }
                                        // タグも保存（説明保存と別トランザクション）
                                        do { try await viewModel.save() } catch { print("⚠️ タグの保存に失敗: \(error.localizedDescription)") }
                                    }
                                }
                            } catch {
                                print("⚠️ タグ提案に失敗: \(error.localizedDescription)")
                            }
                            
                            // Use DispatchQueue to defer state updates to avoid publish-during-view-updates
                            DispatchQueue.main.async {
                                isCreatingSubtasks = false
                                
                                if !createdSubtasks.isEmpty {
                                    // 成功: 楽観的なサブタスクを正式なものに置換
                                    onConfirmOptimisticUpdate(tempIds, createdSubtasks)
                                    
                                    subtaskCreationResult = "✅ \(createdSubtasks.count)個のサブタスクを作成しました"
                                    print("✅ \(createdSubtasks.count)個のサブタスクを作成しました（楽観更新）")
                                    
                                    // 3秒後にメッセージを自動クリア
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                                        subtaskCreationResult = nil
                                    }
                                } else {
                                    // 失敗: 楽観的なサブタスクを削除
                                    onRevertOptimisticUpdate(tempIds)
                                    
                                    subtaskCreationResult = "⚠️ AI提案からサブタスクを抽出できませんでした"
                                    print("⚠️ AI提案からサブタスクを抽出できませんでした")
                                    
                                    // 5秒後にメッセージを自動クリア
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                                        subtaskCreationResult = nil
                                    }
                                }
                                
                                // Defer aiStateManager update to next frame
                                DispatchQueue.main.async {
                                    aiStateManager.applyResult(content)
                                }
                            }
                        }
                    },
                    onReject: {
                        aiStateManager.dismissResult()
                    }
                )
                
            case .error(let message):
                AIErrorView(
                    message: message,
                    onRetry: { aiStateManager.retry() },
                    onOpenSettings: { showAISettings = true }
                )
            }
        }
    }
}

// MARK: - Local helpers

private func extractURLs(from text: String) -> [String] {
    // 粗めのURL抽出（http/https のみ）。最大5件。
    let pattern = #"https?://[A-Za-z0-9._~:/?#\[\]@!$&'()*+,;=%-]+"#
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
    let nsrange = NSRange(text.startIndex..., in: text)
    let matches = regex.matches(in: text, options: [], range: nsrange)
    var urls: [String] = []
    for m in matches {
        if let r = Range(m.range, in: text) {
            let s = String(text[r])
            if !urls.contains(s) { urls.append(s) }
        }
    }
    return Array(urls.prefix(5))
}
