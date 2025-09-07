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
    let onGenerateSubtasks: () -> Void
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
                    onGenerateSubtasks: onGenerateSubtasks,
                    onGenerateDetails: { aiStateManager.generateDetail(for: task) }
                )
                
            case .loading(let message):
                AIStatusIndicatorView(message: message)
                
            case .suggestion(let result):
                AIDetailResultView(
                    result: result,
                    onApply: { content in
                        viewModel.taskDescription = content
                        Task {
                            do {
                                try await viewModel.save()
                                await MainActor.run {
                                    aiStateManager.applyResult(content)
                                }
                            } catch {
                                print("⚠️ AI提案の説明適用時の保存に失敗: \(error.localizedDescription)")
                                await MainActor.run {
                                    aiStateManager.applyResult(content)
                                }
                            }
                        }
                    },
                    onEdit: { content in
                        Task {
                            // 楽観更新: 即座にUI更新
                            let tempIds = await MainActor.run {
                                isCreatingSubtasks = true
                                subtaskCreationResult = nil
                                return onOptimisticSubtasksUpdate(content)
                            }
                            
                            do {
                                // 裏でFirestore永続化
                                let tempService = PhaseTaskDetailService()
                                let createdSubtasks = await tempService.createSubtasksFromAIContent(
                                    content: content,
                                    task: task,
                                    project: project,
                                    phase: phase
                                )
                                
                                await MainActor.run {
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
                                    
                                    aiStateManager.applyResult(content)
                                }
                            } catch {
                                await MainActor.run {
                                    isCreatingSubtasks = false
                                    
                                    // 失敗: 楽観的なサブタスクを削除
                                    onRevertOptimisticUpdate(tempIds)
                                    
                                    subtaskCreationResult = "❌ サブタスク作成エラー: \(error.localizedDescription)"
                                    print("❌ サブタスク作成エラー: \(error.localizedDescription)")
                                    
                                    // 5秒後にエラーメッセージを自動クリア
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                                        subtaskCreationResult = nil
                                    }
                                    
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