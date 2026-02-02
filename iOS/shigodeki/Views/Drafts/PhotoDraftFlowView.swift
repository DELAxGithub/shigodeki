
import SwiftUI
import UIKit

struct PhotoDraftFlowView: View {
    let taskList: TaskList
    let project: Project
    let phase: Phase
    let onPreviewDrafts: ([TaskDraft], TaskDraftSource) -> Void
    let onCancel: () -> Void

    @State private var isAnalyzing = false
    @State private var showCamera = false
    @State private var showLibrary = false
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var toastCenter: ToastCenter

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if isAnalyzing {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("写真を解析中...")
                            .font(.headline)
                        Text("少し時間がかかる場合があります")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 60))
                        .foregroundStyle(.secondary)
                    
                    Text("写真からタスクを追加")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("書類やメモ書き、ホワイトボードなどを撮影して\nAIがタスク候補を提案します")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)

                    VStack(spacing: 12) {
                        Button {
                            showCamera = true
                        } label: {
                            Label("カメラを起動", systemImage: "camera.fill")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        
                        Button {
                            showLibrary = true
                        } label: {
                            Label("ライブラリから選択", systemImage: "photo.on.rectangle")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                    .padding(.horizontal, 32)
                }
            }
            .navigationTitle("写真読み込み")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        onCancel()
                    }
                    .disabled(isAnalyzing)
                }
            }
            .sheet(isPresented: $showCamera) {
                CameraPicker(source: .camera) { image in
                    process(image: image)
                }
            }
            .sheet(isPresented: $showLibrary) {
                CameraPicker(source: .photoLibrary) { image in
                    process(image: image)
                }
            }
        }
    }

    private func process(image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.7) else {
            toastCenter.show("画像の処理に失敗しました")
            return
        }
        
        isAnalyzing = true
        
        Task {
            // Check API Keys
            let hasProvider = KeychainManager.APIProvider.allCases.contains { provider in
                KeychainManager.shared.getAPIKeyIfAvailable(for: provider)?.isEmpty == false
            }
            
            // Allow network if we have a provider
            let allowNetwork = hasProvider
            
            let planner = VisionPlanCoordinator()
            let regionCode = Locale.current.region?.identifier ?? "JP"
            let locale = UserLocale(
                country: regionCode,
                city: regionCode == "JP" ? "Tokyo" : "Toronto"
            )
            
            let context = VisionPlanContextBuilder.build(
                project: project,
                phase: phase,
                taskList: taskList,
                additionalNotes: ["入力画像: フェーズ用の新規タスク候補を抽出する"]
            )
            
            let plan = await planner.generatePlan(from: data, locale: locale, allowNetwork: allowNetwork, context: context)
            
            await MainActor.run {
                isAnalyzing = false
                
                if plan.project == "Fallback Moving Plan" {
                     toastCenter.show("AIが混雑中のため、テンプレート候補を表示しました")
                }
                
                if plan.tasks.isEmpty {
                     toastCenter.show("写真からタスクが見つかりませんでした")
                     return
                }
                
                let drafts = plan.tasks.map { t in
                    let rationale: String? = {
                        guard let checklist = t.checklist, !checklist.isEmpty else { return nil }
                        return checklist.map { "• \($0)" }.joined(separator: "\n")
                    }()
                
                    return TaskDraft(
                        title: t.title,
                        assignee: nil,
                        due: t.dueDate,
                        rationale: rationale,
                        priority: mapPriority(t.priority)
                    )
                }
                
                onPreviewDrafts(drafts, .photo)
            }
        }
    }
    
    private func mapPriority(_ p: Int?) -> TaskPriority {
        guard let p else { return .medium }
        if p >= 4 { return .high }
        if p <= 2 { return .low }
        return .medium
    }
}
