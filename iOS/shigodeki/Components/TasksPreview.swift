//
//  TasksPreview.swift
//  shigodeki
//
//  Shared preview shell for Phase 2 task review.
//

import SwiftUI

struct TaskDraft: Identifiable, Equatable {
    let id = UUID()
    var title: String
    var assignee: String?
    var due: Date?
    var rationale: String?
    var priority: TaskPriority = .medium
}

struct TasksPreview: View {
    let drafts: [TaskDraft]
    var onAccept: ([TaskDraft]) -> Void
    var onCancel: () -> Void
    @State private var accepting = false

    var body: some View {
        NavigationStack {
            List(drafts) { draft in
                VStack(alignment: .leading, spacing: 4) {
                    Text(draft.title)
                        .font(.headline)
                    if let assignee = draft.assignee, !assignee.isEmpty {
                        Label(assignee, systemImage: "person")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    if let due = draft.due {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar")
                            Text(due, style: .date)
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    }
                    if let rationale = draft.rationale, !rationale.isEmpty {
                        Text(rationale)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
            .listStyle(.insetGrouped)
            .navigationTitle("プレビュー")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("戻る", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("この内容で作成") {
                        guard !accepting else { return }
                        accepting = true
                        onAccept(drafts)
                    }
                    .disabled(accepting)
                    .accessibilityIdentifier("TasksPreview.Accept")
                }
            }
            .accessibilityIdentifier("TasksPreview")
        }
    }
}
