//
//  CreateTaskView.swift
//  shigodeki
//
//  Refactored for CLAUDE.md compliance - UI components extracted
//  Core view structure for task creation form
//

import SwiftUI

struct CreateTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var toastCenter: ToastCenter
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var selectedPriority: TaskPriority = .medium
    @State private var selectedAssignee: String?
    @State private var dueDate: Date = Date()
    @State private var hasDueDate: Bool = false
    @State private var selectedTags: [String] = []
    @State private var keepAttachment: Bool = false
    @State private var attachments: [String] = [] // base64 data URLs or remote URLs
    @State private var showingPreview: Bool = false
    @State private var isCreating: Bool = false
    @State private var errorMessage: String?

    // Services
    @StateObject private var tagManager = TagManager()
    private let enhancedTaskManager = EnhancedTaskManager()

    let taskList: TaskList
    let family: Family
    let creatorUserId: String
    let familyMembers: [User]

    init(
        taskList: TaskList,
        family: Family,
        taskManager: TaskManager,
        creatorUserId: String,
        familyMembers: [User]
    ) {
        self.taskList = taskList
        self.family = family
        self.creatorUserId = creatorUserId
        self.familyMembers = familyMembers
    }
    
    var body: some View {
        NavigationView {
            CreateTaskFormContent(
                title: $title,
                description: $description,
                selectedPriority: $selectedPriority,
                selectedAssignee: $selectedAssignee,
                dueDate: $dueDate,
                hasDueDate: $hasDueDate,
                selectedTags: $selectedTags,
                keepAttachment: $keepAttachment,
                attachments: $attachments,
                taskList: taskList,
                familyMembers: familyMembers,
                creatorUserId: creatorUserId,
                tagManager: tagManager,
                isCreating: isCreating,
                onPreview: showPreview,
                onCancel: { dismiss() }
            )
            .navigationTitle("タスク作成")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingPreview) {
            TasksPreview(
                drafts: [buildDraft()],
                onAccept: { acceptedDrafts in
                    createTaskWithUndo(drafts: acceptedDrafts)
                },
                onCancel: {
                    showingPreview = false
                }
            )
        }
        .alert("エラー", isPresented: Binding<Bool>(
            get: { errorMessage != nil },
            set: { _ in errorMessage = nil }
        )) {
            Button("OK") {}
        } message: {
            Text(errorMessage ?? "")
        }
        .task {
            await tagManager.loadTags(projectId: taskList.projectId)
            tagManager.startListening(projectId: taskList.projectId)
        }
        .onDisappear {
            tagManager.stopListening()
        }
    }
    
    private func showPreview() {
        Telemetry.fire(.onPreviewShown, TelemetryPayload(previewSource: "manual"))
        showingPreview = true
    }

    private func buildDraft() -> TaskDraft {
        let assigneeName: String? = {
            guard let assigneeId = selectedAssignee else { return nil }
            return familyMembers.first { $0.id == assigneeId }?.name
        }()

        return TaskDraft(
            title: title,
            assignee: assigneeName,
            due: hasDueDate ? dueDate : nil,
            rationale: description.isEmpty ? nil : description,
            priority: selectedPriority
        )
    }

    private func createTaskWithUndo(drafts: [TaskDraft]) {
        guard let listId = taskList.id else {
            errorMessage = "タスクリストIDが見つかりません"
            return
        }

        isCreating = true
        showingPreview = false

        Task {
            do {
                let context = DraftSaveContext(
                    listId: listId,
                    phaseId: taskList.phaseId,
                    projectId: taskList.projectId,
                    createdBy: creatorUserId,
                    taskManager: enhancedTaskManager,
                    toastCenter: toastCenter
                )

                try await DraftSaveFacade.executeSaveWithUndo(
                    drafts: drafts,
                    source: .manual,
                    context: context
                )

                // Update tag usage
                for tagName in selectedTags {
                    await tagManager.incrementUsage(for: tagName, projectId: taskList.projectId)
                }

                isCreating = false
                dismiss()
            } catch {
                isCreating = false
                errorMessage = "タスクの作成に失敗しました: \(error.localizedDescription)"
            }
        }
    }
}

#Preview {
    CreateTaskView(
        taskList: TaskList(name: "サンプルタスクリスト", familyId: "family1", createdBy: "user1"),
        family: Family(name: "サンプルチーム", members: ["user1", "user2"]),
        taskManager: TaskManager(),
        creatorUserId: "user1",
        familyMembers: [
            User(name: "太郎", email: "taro@example.com"),
            User(name: "花子", email: "hanako@example.com")
        ]
    )
}
