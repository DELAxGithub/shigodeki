//
//  PhotoTaskSuggestionSection.swift
//  shigodeki
//
//  Optional section to capture/select a photo and generate task suggestions.
//  Uses TidyPlanKit when available; otherwise shows a gentle hint.
//

import SwiftUI
import UIKit

struct PhotoTaskSuggestionSection: View {
    // Bindings to write suggestions back into the create-task form
    @Binding var title: String
    @Binding var description: String
    @Binding var selectedPriority: TaskPriority
    @Binding var dueDate: Date
    @Binding var hasDueDate: Bool
    @Binding var selectedTags: [String]
    @Binding var keepAttachment: Bool
    @Binding var attachments: [String]
    let contextHint: String?
    private let previewEnabled: Bool
    private let onPreview: (([TaskDraft]) -> Void)?

    @EnvironmentObject private var toastCenter: ToastCenter
    @State private var showCamera = false
    @State private var showLibrary = false
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var suggestions: [PhotoDraftBuilder.Suggestion] = []

    init(
        title: Binding<String>,
        description: Binding<String>,
        selectedPriority: Binding<TaskPriority>,
        dueDate: Binding<Date>,
        hasDueDate: Binding<Bool>,
        selectedTags: Binding<[String]>,
        keepAttachment: Binding<Bool>,
        attachments: Binding<[String]>,
        contextHint: String?,
        previewEnabled: Bool = false,
        onPreview: (([TaskDraft]) -> Void)? = nil
    ) {
        self._title = title
        self._description = description
        self._selectedPriority = selectedPriority
        self._dueDate = dueDate
        self._hasDueDate = hasDueDate
        self._selectedTags = selectedTags
        self._keepAttachment = keepAttachment
        self._attachments = attachments
        self.contextHint = contextHint
        self.previewEnabled = previewEnabled && onPreview != nil
        self.onPreview = onPreview
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("写真から提案（任意）")
                .font(.headline)

            Text("部屋やモノの写真から、実行可能なタスク候補を生成します。")
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                Button {
                    showCamera = true
                } label: {
                    Label("カメラで撮影", systemImage: "camera")
                }
                .buttonStyle(.bordered)

                Button {
                    showLibrary = true
                } label: {
                    Label("写真を選択", systemImage: "photo.on.rectangle")
                }
                .buttonStyle(.bordered)
            }

            if isGenerating {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("写真を解析して提案を生成中…")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundColor(.red)
            }

            if !suggestions.isEmpty {
                Divider()
                Text("候補を選んでフォームに反映")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                ForEach(suggestions) { s in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "lightbulb")
                                .foregroundColor(.yellow)
                            Text(s.title)
                                .font(.body)
                                .fontWeight(.medium)
                            Spacer()
                            Button(previewEnabled ? "プレビュー" : "反映") {
                                applySuggestion(s)
                            }
                        }
                        if let details = s.details, !details.isEmpty {
                            Text(details)
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(10)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }

            // 内蔵のプランナーを使用します
        }
        .sheet(isPresented: $showCamera) {
            CameraPicker(source: .camera) { image in
                processImage(image)
            }
        }
        .sheet(isPresented: $showLibrary) {
            CameraPicker(source: .photoLibrary) { image in
                processImage(image)
            }
        }
    }

    private func processImage(_ image: UIImage) {
        errorMessage = nil
        suggestions.removeAll()
        guard let data = image.jpegData(compressionQuality: 0.7) else {
            errorMessage = "画像の処理に失敗しました"
            return
        }
        if keepAttachment {
            let base64 = data.base64EncodedString()
            let dataURL = "data:image/jpeg;base64,\(base64)"
            attachments.append(dataURL)
        }
        generateSuggestions(from: data)
    }

    private func applySuggestion(_ s: PhotoDraftBuilder.Suggestion) {
        if previewEnabled, let onPreview {
            let drafts = PhotoDraftBuilder.build(from: [s])
            guard drafts.isEmpty == false else { return }
            onPreview(drafts)
            return
        }

        title = s.title
        description = s.details ?? ""
        selectedTags = s.labels
        selectedPriority = s.priority
        if let due = s.dueDate {
            dueDate = due
            hasDueDate = true
        }
    }

    private func generateSuggestions(from imageData: Data) {
        isGenerating = true
        Task {
            defer { isGenerating = false }

            let hasProvider = KeychainManager.APIProvider.allCases.contains { provider in
                KeychainManager.shared.getAPIKeyIfAvailable(for: provider)?.isEmpty == false
            }
            let allowNetwork = hasProvider
            let coordinator = VisionPlanCoordinator()

            let locale = currentUserLocale()
            let plan = await coordinator.generatePlan(from: imageData, locale: locale, allowNetwork: allowNetwork, context: contextHint)
            if plan.project == "Fallback Moving Plan" {
                await MainActor.run {
                    errorMessage = nil
                    toastCenter.show("AIが混雑中のため、テンプレート候補を表示しました")
                }
            }

            // Map to lightweight suggestions for UI consumption
            let mapped: [PhotoDraftBuilder.Suggestion] = plan.tasks.map { t in
                let exitLabels: [String] = {
                    guard let tag = t.exit_tag, tag != .keep else { return [] }
                    return [tag.rawValue]
                }()
                let details: String? = {
                    let checklist = (t.checklist ?? []).map { "• \($0)" }.joined(separator: "\n")
                    return checklist.isEmpty ? nil : checklist
                }()
                let due: Date? = t.dueDate
                let priority: TaskPriority = {
                    let score = t.priority ?? 3
                    if score <= 2 { return .low }
                    if score >= 4 { return .high }
                    return .medium
                }()
                return PhotoDraftBuilder.Suggestion(
                    title: t.title,
                    details: details,
                    labels: (t.labels ?? []) + exitLabels,
                    dueDate: due,
                    priority: priority
                )
            }
            await MainActor.run { self.suggestions = mapped }
        }
    }

    private func currentUserLocale() -> UserLocale {
        let country = Locale.current.region?.identifier ?? "JP"
        // City detection would require CoreLocation; choose a sensible default
        let city = (country == "JP") ? "Tokyo" : "Toronto"
        return UserLocale(country: country, city: city)
    }
}
