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

    @State private var showCamera = false
    @State private var showLibrary = false
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var suggestions: [Suggestion] = []

    struct Suggestion: Identifiable, Hashable {
        let id = UUID()
        let title: String
        let details: String?
        let labels: [String]
        let priority: Int // 1-4
        let dueDate: Date?
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
                            Button("反映") {
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

    private func applySuggestion(_ s: Suggestion) {
        title = s.title
        description = s.details ?? ""
        selectedTags = s.labels
        // Map 1-4 to low/medium/high
        switch s.priority {
        case ..<3: selectedPriority = .low
        case 3: selectedPriority = .medium
        default: selectedPriority = .high
        }
        if let due = s.dueDate {
            dueDate = due
            hasDueDate = true
        }
    }

    private func generateSuggestions(from imageData: Data) {
        isGenerating = true
        Task {
            defer { isGenerating = false }

            // Try to use OpenAI key if present; fall back to local
            let apiKey = try? KeychainManager.shared.retrieveAPIKey(for: .openAI)
            let allowNetwork = (apiKey?.isEmpty == false)
            let planner = TidyPlanner(apiKey: apiKey)

            let locale = currentUserLocale()
            let plan = await planner.generate(from: imageData, locale: locale, allowNetwork: allowNetwork, context: contextHint)

            // Map to lightweight suggestions for UI consumption
            let mapped: [Suggestion] = plan.tasks.map { t in
                let labels = (t.labels ?? []) + (t.exit_tag != nil ? [t.exit_tag!.rawValue] : [])
                let details: String? = {
                    let checklist = (t.checklist ?? []).map { "• \($0)" }.joined(separator: "\n")
                    return checklist.isEmpty ? nil : checklist
                }()
                let due: Date? = {
                    if let d = t.due_at, let parsed = ISO8601DateFormatter().date(from: d) { return parsed }
                    return nil
                }()
                return Suggestion(
                    title: t.title,
                    details: details,
                    labels: labels,
                    priority: t.priority ?? 3,
                    dueDate: due
                )
            }
            await MainActor.run { self.suggestions = mapped }
        }
    }

    private func currentUserLocale() -> UserLocale {
        let country = Locale.current.regionCode ?? "JP"
        // City detection would require CoreLocation; choose a sensible default
        let city = (country == "JP") ? "Tokyo" : "Toronto"
        return UserLocale(country: country, city: city)
    }
}
