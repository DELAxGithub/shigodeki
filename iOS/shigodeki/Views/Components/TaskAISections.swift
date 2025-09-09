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
                            } catch {
                                DispatchQueue.main.async {
                                    isCreatingSubtasks = false
                                    
                                    // 失敗: 楽観的なサブタスクを削除
                                    onRevertOptimisticUpdate(tempIds)
                                    
                                    subtaskCreationResult = "❌ サブタスク作成エラー: \(error.localizedDescription)"
                                    print("❌ サブタスク作成エラー: \(error.localizedDescription)")
                                    
                                    // 5秒後にエラーメッセージを自動クリア
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                                        subtaskCreationResult = nil
                                    }
                                    
                                    // Defer aiStateManager update to next frame
                                    DispatchQueue.main.async {
                                        aiStateManager.applyResult(content)
                                    }
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
