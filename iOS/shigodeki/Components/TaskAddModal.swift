//
//  TaskAddModal.swift
//  shigodeki
//
//  Phase 1 task creation entry selector.
//

import SwiftUI

private extension TaskAddRoute {
    var accessibilityLabelText: String {
        title
    }

    var accessibilityHintText: String? {
        switch self {
        case .manual:
            return "タイトルや担当者を直接入力します"
        case .ai:
            return "AIがタスク候補を生成します"
        case .photo:
            return "写真からタスク候補を抽出します"
        case .template:
            return "テンプレートからまとめて追加します"
        case .chooser:
            return nil
        }
    }
}

enum TaskAddRoute: String, Identifiable, CaseIterable {
    case chooser
    case manual
    case ai
    case photo
    case template

    var id: String { rawValue }

    static var selectableRoutes: [TaskAddRoute] { [.manual, .ai, .photo, .template] }

    var title: String {
        switch self {
        case .chooser: return ""
        case .manual: return "手動で入力"
        case .ai: return "AI アシスタント"
        case .photo: return "写真から提案"
        case .template: return "テンプレートを使う"
        }
    }

    var subtitle: String {
        switch self {
        case .chooser: return ""
        case .manual: return "タイトル・担当者・期日を直接入力"
        case .ai: return "既存タスクを解析して追加案を生成"
        case .photo: return "写真を解析してタスク候補を作成"
        case .template: return "定型テンプレートから選択"
        }
    }

    var icon: String {
        switch self {
        case .chooser: return "square.stack"
        case .manual: return "square.and.pencil"
        case .ai: return "brain"
        case .photo: return "camera.fill"
        case .template: return "doc.text"
        }
    }

    /// Routes implemented in Phase 1. Others display a placeholder message until Phase 2+ work lands.
    var isAvailable: Bool {
        switch self {
        case .manual:
            return true
        case .ai:
            return FeatureFlags.unifiedPreviewEnabled && FeatureFlags.previewAIEnabled
        case .photo:
            return FeatureFlags.unifiedPreviewEnabled && FeatureFlags.previewPhotoEnabled
        case .template:
            return FeatureFlags.unifiedPreviewEnabled && FeatureFlags.previewTemplateEnabled
        case .chooser:
            return false
        }
    }
}

struct TaskAddModal: View {
    let onSelect: (TaskAddRoute) -> Void
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("追加方法")) {
                    ForEach(TaskAddRoute.selectableRoutes) { route in
                        let payload = TelemetryPayload(screen: "TaskAddModal", option: route.rawValue)
                        let hintText = route.accessibilityHintText
                        Button {
                            Telemetry.fire(.onTaskAddOptionChosen, payload)
                            guard route.isAvailable else { return }
                            onSelect(route)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: route.icon)
                                    .foregroundColor(.accentColor)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(route.title)
                                        .font(.headline)
                                    Text(route.subtitle)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if !route.isAvailable {
                                    Text("近日公開")
                                        .font(.caption)
                                        .foregroundColor(Color(.tertiaryLabel))
                                }
                            }
                        }
                        .accessibilityLabel(route.accessibilityLabelText)
                        .accessibilityHint(hintText ?? "")
                        .accessibilityIdentifier("TaskAddModal.Option.\(route.rawValue)")
                        .disabled(!route.isAvailable)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("タスクを追加")
            .accessibilityIdentifier("TaskAddModal")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる", action: onClose)
                }
            }
        }
    }
}

struct TaskAddPlaceholderView: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 40))
                    .foregroundColor(.orange)
                Text(message)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                Button("閉じる", action: onDismiss)
                    .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
            .navigationTitle("準備中")
            .accessibilityIdentifier("TaskAddPlaceholderView")
        }
    }
}
